"""Library of the MUL2_NEW validation campaign.

Everything needed to *generate* a model (beam, plate strip, solid block,
non-uniform kinematics, multi-dimensional), *run* the solver and compare
with closed-form references lives here.  The cases are defined in vrun.py.

Conventions (all lengths in metres, forces in newtons)
  beam   : axis Y in [0, L], section (x, z) centred on the axis, versor +Z
  plate  : strip in the (x, y) plane, thickness along z, versor +X
  solid  : block x in [-b/2, b/2], y in [0, L], z in [-h/2, h/2]
"""
import math
import os
import re
import shutil
import subprocess
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
EXE = os.environ.get('MUL2_EXE', os.path.join(
    ROOT, 'BUILD', 'WINDOWS_IFX', 'Release', 'MUL2_V3.exe'))
WORK = os.environ.get('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_validation'))
ONEAPI = r'C:\Program Files (x86)\Intel\oneAPI'

# ---------------------------------------------------------------- data
E0, NU0, RHO0 = 70.0e9, 0.3, 2700.0
LB, BB, HB_ = 10.0, 1.0, 1.0          # beam / strip / block: L, width, height


def fmt(x):
    return ('%.14E' % x).replace('E', 'D')


# ------------------------------------------------------------- closed forms
def kappa_rect(nu):
    """Cowper shear coefficient of a rectangle."""
    return 10.0 * (1.0 + nu) / (12.0 + 11.0 * nu)


def eb_tip(P, L, E, I):
    return P * L ** 3 / (3.0 * E * I)


def timoshenko_tip(P, L, E, I, G, A, kappa):
    return P * L ** 3 / (3.0 * E * I) + P * L / (kappa * G * A)


BETA = [1.8751040687, 4.6940911330, 7.8547574382, 10.9955407349]


def eb_freqs(L, E, I, rho, A, n=4):
    """Euler-Bernoulli cantilever frequencies [Hz]."""
    c = math.sqrt(E * I / (rho * A))
    return [b * b / (2.0 * math.pi * L * L) * c for b in BETA[:n]]


def timoshenko_freqs(L, E, I, rho, A, G, kappa, n=4):
    """Timoshenko cantilever frequencies [Hz]: the clamped-free frequency
    equation is solved by integrating the first-order system
    (w, theta, M, Q) with RK4 and bisecting on the free-end determinant."""
    kGA = kappa * G * A
    EI = E * I

    def residual(om):
        w2 = om * om

        def f(s):
            w, th, M, Q = s
            return [th + Q / kGA, M / EI, -Q - rho * I * w2 * th,
                    -rho * A * w2 * w]
        res = []
        for s0 in ([0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]):
            s = list(s0)
            steps = 400
            h = L / steps
            for _ in range(steps):
                k1 = f(s)
                k2 = f([s[i] + 0.5 * h * k1[i] for i in range(4)])
                k3 = f([s[i] + 0.5 * h * k2[i] for i in range(4)])
                k4 = f([s[i] + h * k3[i] for i in range(4)])
                s = [s[i] + h / 6.0 * (k1[i] + 2 * k2[i] + 2 * k3[i]
                                       + k4[i]) for i in range(4)]
            res.append((s[2], s[3]))
        return res[0][0] * res[1][1] - res[0][1] * res[1][0]

    out = []
    for f0 in eb_freqs(L, E, I, rho, A, n):
        lo, hi = 0.6 * f0 * 2 * math.pi, 1.02 * f0 * 2 * math.pi
        flo = residual(lo)
        for _ in range(60):
            mid = 0.5 * (lo + hi)
            fm = residual(mid)
            if (fm > 0) == (flo > 0):
                lo, flo = mid, fm
            else:
                hi = mid
        out.append(0.5 * (lo + hi) / (2 * math.pi))
    return out


# ----------------------------------------------------------- 1D rules
def line_weights(p):
    """consistent nodal weights of a uniform load on a p-th order line
    element of unit length (nodes equally spaced)."""
    return {1: [0.5, 0.5], 2: [1 / 6, 4 / 6, 1 / 6],
            3: [1 / 8, 3 / 8, 3 / 8, 1 / 8]}[p]


def lagrange(nodes, k, x):
    v = 1.0
    for j, xj in enumerate(nodes):
        if j != k:
            v *= (x - xj) / (nodes[k] - xj)
    return v


GAUSS3 = [(-math.sqrt(0.6), 5 / 9), (0.0, 8 / 9), (math.sqrt(0.6), 5 / 9)]
TRI7 = [((1 / 3, 1 / 3), 0.225),
        ((0.059715871789770, 0.470142064105115), 0.132394152788506),
        ((0.470142064105115, 0.059715871789770), 0.132394152788506),
        ((0.470142064105115, 0.470142064105115), 0.132394152788506),
        ((0.797426985353087, 0.101286507323456), 0.125939180544827),
        ((0.101286507323456, 0.797426985353087), 0.125939180544827),
        ((0.101286507323456, 0.101286507323456), 0.125939180544827)]

Q_PATTERN = {
    'Q4': (1, [(1, 1), (2, 1), (2, 2), (1, 2)]),
    'Q9': (2, [(1, 1), (2, 1), (3, 1), (3, 2), (3, 3), (2, 3), (1, 3),
               (1, 2), (2, 2)]),
    'Q16': (3, list(zip([1, 2, 3, 4, 4, 4, 4, 3, 2, 1, 1, 1, 2, 3, 3, 2],
                        [1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 3, 2, 2, 2, 3, 3]))),
}
H_PATTERN = {
    'H8': (1, list(zip([1, 2, 2, 1, 1, 2, 2, 1], [1, 1, 2, 2, 1, 1, 2, 2],
                       [1, 1, 1, 1, 2, 2, 2, 2]))),
    'H27': (2, list(zip(
        [1, 3, 3, 1, 1, 3, 3, 1, 2, 1, 1, 3, 3, 2, 3, 1, 2, 1, 3, 2, 2, 2,
         1, 3, 2, 2, 2],
        [1, 1, 3, 3, 1, 1, 3, 3, 1, 2, 1, 2, 1, 3, 3, 3, 1, 2, 2, 3, 2, 1,
         2, 2, 3, 2, 2],
        [1, 1, 1, 1, 3, 3, 3, 3, 1, 1, 2, 1, 2, 1, 2, 2, 3, 3, 3, 3, 1, 2,
         2, 2, 2, 3, 2]))),
}


# ------------------------------------------------------------ 2D meshes
class Mesh2D:
    """A structured rectangular mesh with Q4/Q9/Q16/T3/T6/HQ4 cells.

    nodes: {id: (u, v)}; elems: [(topo, [ids], [extra tokens], lam)];
    aux: extra geometry nodes (mid nodes of curved HLE sides).
    """

    def __init__(self):
        self.nodes = {}
        self.elems = []
        self.aux = {}
        self.kind = 'LE'
        self.order = 0

    # -- loads --------------------------------------------------------
    def consistent(self, f):
        """nodal values of  integral N_i f(u,v) dA  for every node."""
        out = {i: 0.0 for i in self.nodes}
        for topo, ids, extra, lam in self.elems:
            xy = [self.nodes[i] for i in ids]
            if topo in ('B2', 'B3', 'B4', 'HB2'):         # line element
                p = len(ids) - 1
                z0, z1 = xy[0][1], xy[-1][1]
                grid = [-1.0 + 2.0 * k / p for k in range(p + 1)]
                for gx, wx in GAUSS3:
                    v = 0.5 * (z0 + z1) + 0.5 * gx * (z1 - z0)
                    fv = f(0.0, v) * wx * abs(z1 - z0) / 2.0
                    for n in range(p + 1):
                        out[ids[n]] += lagrange(grid, n, gx) * fv
                continue
            if topo in Q_PATTERN or topo == 'HQ4':
                key = 'Q4' if topo == 'HQ4' else topo
                p, pat = Q_PATTERN[key]
                xs = [xy[0][0], xy[1][0]]
                u0 = min(q[0] for q in xy)
                u1 = max(q[0] for q in xy)
                v0 = min(q[1] for q in xy)
                v1 = max(q[1] for q in xy)
                jac = (u1 - u0) / 2.0 * (v1 - v0) / 2.0
                grid = [-1.0 + 2.0 * k / p for k in range(p + 1)]
                for gx, wx in GAUSS3:
                    for gy, wy in GAUSS3:
                        u = u0 + (gx + 1.0) * (u1 - u0) / 2.0
                        v = v0 + (gy + 1.0) * (v1 - v0) / 2.0
                        fv = f(u, v) * wx * wy * jac
                        for n, (a, b) in enumerate(pat[:len(ids)]):
                            N = lagrange(grid, a - 1, gx) * \
                                lagrange(grid, b - 1, gy)
                            out[ids[n]] += N * fv
            else:                                   # T3 / T6
                (x1, y1), (x2, y2), (x3, y3) = xy[0], xy[1], xy[2]
                det = (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)
                for (xi, eta), w in TRI7:
                    l1 = 1.0 - xi - eta
                    u = x1 * l1 + x2 * xi + x3 * eta
                    v = y1 * l1 + y2 * xi + y3 * eta
                    fv = f(u, v) * w * det / 2.0
                    if topo == 'T3':
                        Ns = [l1, xi, eta]
                    else:
                        Ns = [l1 * (2 * l1 - 1), xi * (2 * xi - 1),
                              eta * (2 * eta - 1), 4 * l1 * xi,
                              4 * xi * eta, 4 * eta * l1]
                    for n, N in enumerate(Ns):
                        out[ids[n]] += N * fv
        return out

    def area(self):
        return sum(self.consistent(lambda u, v: 1.0).values())

    # -- file text ------------------------------------------------------
    def mesh_text(self, as_beam=True, with_aux=True):
        allnodes = dict(self.nodes)
        if with_aux:
            allnodes.update(self.aux)
        lines = ['%d' % len(allnodes), '']
        for i in sorted(allnodes):
            u, v = allnodes[i]
            if as_beam:
                lines.append('%d  %s  0.0D0  %s' % (i, fmt(u), fmt(v)))
            else:
                lines.append('%d  0.0D0  0.0D0  %s' % (i, fmt(v)))
        return '\n'.join(lines) + '\n'

    def conn_text(self):
        lines = ['%d' % len(self.elems), '']
        for k, (topo, ids, extra, lam) in enumerate(self.elems):
            tail = ''.join('  %s' % t for t in extra)
            lines.append('%s %d %d  %s%s' % (
                topo, k + 1, lam, ' '.join(map(str, ids)), tail))
        return '\n'.join(lines) + '\n'


def rect_mesh(topo, nx, ny, u0, u1, v0, v1, lam=1, order=None):
    """structured mesh of the rectangle [u0,u1] x [v0,v1] with nx x ny
    cells.  topo in Q4 Q9 Q16 T3 T6 HQ4; for HQ4 `order` is an int or a
    function (ix, iy) -> p."""
    m = Mesh2D()
    if topo in ('Q4', 'Q9', 'Q16', 'HQ4'):
        key = 'Q4' if topo == 'HQ4' else topo
        p, pat = Q_PATTERN[key]
        nxl, nyl = p * nx + 1, p * ny + 1
        for j in range(nyl):
            for i in range(nxl):
                m.nodes[i + nxl * j + 1] = (u0 + (u1 - u0) * i / (nxl - 1),
                                            v0 + (v1 - v0) * j / (nyl - 1))
        for cy in range(ny):
            for cx in range(nx):
                ids = [(p * cx + a - 1) + nxl * (p * cy + b - 1) + 1
                       for (a, b) in pat]
                extra = []
                if topo == 'HQ4':
                    pp = order(cx, cy) if callable(order) else order
                    extra = [pp]
                m.elems.append((topo, ids, extra, lam))
        if topo == 'HQ4':
            m.kind = 'HLE'
    else:
        p = 1 if topo == 'T3' else 2
        nxl, nyl = p * nx + 1, p * ny + 1
        for j in range(nyl):
            for i in range(nxl):
                m.nodes[i + nxl * j + 1] = (u0 + (u1 - u0) * i / (nxl - 1),
                                            v0 + (v1 - v0) * j / (nyl - 1))
        nid = lambda i, j: i + nxl * j + 1
        for cy in range(ny):
            for cx in range(nx):
                i, j = p * cx, p * cy
                for corners in (((0, 0), (p, 0), (p, p)),
                                ((0, 0), (p, p), (0, p))):
                    ids = [nid(i + a, j + b) for a, b in corners]
                    if topo == 'T6':
                        for k in range(3):
                            a = corners[k]
                            c = corners[(k + 1) % 3]
                            ids.append(nid(i + (a[0] + c[0]) // 2,
                                           j + (a[1] + c[1]) // 2))
                    m.elems.append((topo, ids, [], lam))
    return m


def line_mesh(kind, ne, h, order=None, lam=1):
    """thickness mesh (plates): B2/B3/B4 elements or HB, local z in
    [-h/2, h/2].  Returned as a Mesh2D with v = z."""
    m = Mesh2D()
    if kind in ('B2', 'B3', 'B4'):
        p = int(kind[1]) - 1
    elif kind == 'HB':
        p = 1
    else:
        raise ValueError(kind)
    nn = p * ne + 1
    for k in range(nn):
        m.nodes[k + 1] = (0.0, -h / 2.0 + h * k / (nn - 1))
    for e in range(ne):
        ids = [p * e + a + 1 for a in range(p + 1)]
        lm = lam[e] if isinstance(lam, (list, tuple)) else lam
        if kind == 'HB':
            m.elems.append(('HB2', ids, [order], lm))
        else:
            m.elems.append((kind, ids, [], lm))
    m.kind = 'HLE' if kind == 'HB' else 'LE'
    m.line_order = p
    m.ne = ne
    return m


def line_load_weights(m):
    """consistent weights of a uniform unit-length load on a thickness
    mesh (node -> weight), total = height."""
    w = {i: 0.0 for i in m.nodes}
    for topo, ids, extra, lam in m.elems:
        z = [m.nodes[i][1] for i in ids]
        ln = abs(z[-1] - z[0])
        p = len(ids) - 1
        for k, i in enumerate(ids):
            w[i] += line_weights(p)[k] * ln
    return w


# ------------------------------------------------------------- the case
class Result:
    def __init__(self):
        self.ok = False
        self.points = []
        self.freq = []
        self.log = ''
        self.ndof = 0
        self.wall = 0.0
        self.case_dir = ''

    def u(self, k=0):
        return self.points[k][10:13]

    def sigma(self, k=0, frame='LOC'):
        r = self.points[k]
        return r[25:31] if frame == 'LOC' else r[31:37]

    def eps(self, k=0, frame='LOC'):
        r = self.points[k]
        return r[13:19] if frame == 'LOC' else r[19:25]


class Case:
    def __init__(self, name):
        self.name = name
        self.files = {}

    def put(self, fname, text):
        self.files[fname] = text

    def dir(self):
        return os.path.join(WORK, self.name)

    def write(self):
        d = self.dir()
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(os.path.join(d, 'INPUT'), exist_ok=True)
        for s in ('REPORT', 'STATIC', 'DYNAMIC', 'WORK'):
            os.makedirs(os.path.join(d, s), exist_ok=True)
        for fn, tx in self.files.items():
            with open(os.path.join(d, 'INPUT', fn), 'w', newline='\n') as f:
                f.write(tx)

    def run(self, env=None, timeout=1800):
        self.write()
        e = dict(os.environ)
        if env:
            e.update(env)
        if os.path.isdir(ONEAPI):
            e['PATH'] = os.pathsep.join([ONEAPI + r'\mkl\2025.0\bin',
                                         ONEAPI + r'\compiler\2025.0\bin',
                                         e['PATH']])
        res = Result()
        res.case_dir = self.dir()
        t0 = time.time()
        try:
            proc = subprocess.run([EXE, 'INPUT'], cwd=self.dir(), env=e,
                                  capture_output=True, text=True,
                                  timeout=timeout)
        except subprocess.TimeoutExpired:
            res.log = 'TIMEOUT'
            return res
        res.wall = time.time() - t0
        res.log = proc.stdout + '\n' + proc.stderr
        with open(os.path.join(self.dir(), 'console.log'), 'w') as f:
            f.write(res.log)
        res.ok = proc.returncode == 0 and '[ERROR]' not in res.log
        m = re.search(r'PREPROCESSING:\s+(\d+)\s+DOF', res.log)
        if m:
            res.ndof = int(m.group(1))
        pp = os.path.join(self.dir(), 'STATIC', 'POST_POINT.dat')
        if os.path.exists(pp):
            for line in open(pp):
                tok = line.split()
                if len(tok) >= 13:
                    try:
                        res.points.append(
                            [float(t.replace('D', 'E')) for t in tok])
                    except ValueError:
                        pass
        fr = os.path.join(self.dir(), 'DYNAMIC', 'FREQUENCIES.dat')
        if os.path.exists(fr):
            for line in open(fr):
                if ':' in line:
                    try:
                        res.freq.append(float(line.split(':')[1]))
                    except ValueError:
                        pass
        return res


# ----------------------------------------------------- common input files
def analysis_text(sol=101, nmodes=8, beam='MITC', plate='MITC',
                  solid='NONE'):
    return '%d\n\n%d modes\n\n%s\n%s\n%s\n' % (
        sol, nmodes, beam, plate, solid)


def material_text(E=E0, nu=NU0, rho=RHO0):
    return '1 1\n\nISO-M 1  %s  %s  %s\n' % (fmt(E), fmt(nu), fmt(rho))


LAM_TEXT = '1\n\nLAM2 1 1 0.0 0.0\n'


def post_text(points, para=False):
    lines = ['%d' % (len(points) + (1 if para else 0)), '']
    if para:
        lines.append('PARA 20 GLB 1 1 1 1 1 1 1 1 1')
    for k, p in enumerate(points):
        lines.append('PNT %d  %s %s %s' % (k + 1, fmt(p[0]), fmt(p[1]),
                                           fmt(p[2])))
    return '\n'.join(lines) + '\n'


def bc_text(records):
    return '%d\n\n%s\n' % (len(records), '\n'.join(records))


def dplane(i, a, b, c, d, ux, uy, uz):
    f = lambda v: 'N' if v is None else fmt(v)
    return 'D-PLANE %d  %s %s %s %s   %s %s %s' % (
        i, fmt(a), fmt(b), fmt(c), fmt(d), f(ux), f(uy), f(uz))


def fpoint(i, x, y, z, fx, fy, fz):
    return 'F-POINT %d  %s %s %s  %s %s %s' % (
        i, fmt(x), fmt(y), fmt(z), fmt(fx), fmt(fy), fmt(fz))


# ---------------------------------------------------------- kinematics
def kin_nodes_text(coords, kin):
    """coords: list of (x, y, z); kin: a legacy token string applied to all
    nodes ('TE 2', 'LE 1', 'HLE') or a list of per-node tokens
    ('TE2', 'LE', 'HLE') written through KINEMATICS.dat.
    Returns (nodes_text, kinematics_text or None)."""
    n = len(coords)
    if isinstance(kin, str):
        lines = ['%d' % n, '']
        for i, (x, y, z) in enumerate(coords):
            lines.append('%d  %s  %s  %s  %s' % (i + 1, fmt(x), fmt(y),
                                                 fmt(z), kin))
        return '\n'.join(lines) + '\n', None
    uniq = []
    for k in kin:
        if k not in uniq:
            uniq.append(k)
    ktxt = ['%d' % len(uniq), '']
    for j, k in enumerate(uniq):
        ktxt.append('KINEMATIC %d  %s %s %s NONE NONE NONE NONE NONE NONE'
                    % (j + 1, k, k, k))
    lines = ['%d' % n, '']
    for i, (x, y, z) in enumerate(coords):
        lines.append('%d  %s  %s  %s  %d' % (
            i + 1, fmt(x), fmt(y), fmt(z), uniq.index(kin[i]) + 1))
    return '\n'.join(lines) + '\n', '\n'.join(ktxt) + '\n'


# --------------------------------------------------------------- BEAMS
def beam_case(name, sections, kin, *, L=LB, nel=5, btype='B4',
              sol=101, nmodes=8, shear='MITC', load=None, bc='clamp',
              nu=NU0, E=E0, rho=RHO0, points=None, para=False,
              elem_section=None, ox=0.0):
    """cantilever beam on the Y axis.

    sections: a Mesh2D (all elements) or list of Mesh2D; elem_section is
      a list (per element, 1-based index in the unique list) when
      different elements use different meshes.
    kin: token or per-node tokens (see kin_nodes_text).
    load: None | ('shear', P) | ('moment', M, I) | ('axial_disp', d)
    bc: 'clamp' | 'axial' (clamp plane with u_y = 0, symmetry), 'clamp'
    """
    secs = sections if isinstance(sections, list) else [sections]
    p = int(btype[1]) - 1
    nn = p * nel + 1
    coords = [(ox, L * i / (nn - 1), 0.0) for i in range(nn)]
    c = Case(name)
    nodes_txt, kin_txt = kin_nodes_text(coords, kin)
    c.put('NODES.dat', nodes_txt)
    if kin_txt:
        c.put('KINEMATICS.dat', kin_txt)
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [p * e + a + 1 for a in range(p + 1)]
        s = (elem_section[e] if elem_section else 1)
        el.append('%s %d  %s  1  %d' % (btype, e + 1,
                                        ' '.join(map(str, ids)), s))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', analysis_text(sol, nmodes, beam=shear))
    c.put('MATERIAL.dat', material_text(E, nu, rho))
    c.put('LAMINATION.dat', LAM_TEXT)
    for k, s in enumerate(secs):
        c.put('EXP_MESH_%02d.dat' % (k + 1), s.mesh_text(True))
        c.put('EXP_CONN_%02d.dat' % (k + 1), s.conn_text())
    recs = [dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0)]
    tip_sec = secs[(elem_section[-1] - 1) if elem_section else 0]
    if sol == 101 and load:
        kind = load[0]
        if kind == 'shear':
            P = load[1]
            A = tip_sec.area()
            w = tip_sec.consistent(lambda u, v: 1.0 / A)
            for i in sorted(w):
                if abs(w[i]) > 1e-14:
                    x, z = tip_sec.nodes[i]
                    recs.append(fpoint(len(recs) + 1, x + ox, L, z,
                                       0.0, 0.0, P * w[i]))
        elif kind == 'moment':
            M, I = load[1], load[2]
            w = tip_sec.consistent(lambda u, v: -v / I)
            for i in sorted(w):
                if abs(w[i]) > 1e-14:
                    x, z = tip_sec.nodes[i]
                    recs.append(fpoint(len(recs) + 1, x + ox, L, z,
                                       0.0, M * w[i], 0.0))
        elif kind == 'axial_disp':
            recs.append(dplane(2, 0, 1, 0, -L, 0.0, load[1], 0.0))
        elif kind == 'axial_force':
            F = load[1]
            A = tip_sec.area()
            w = tip_sec.consistent(lambda u, v: 1.0 / A)
            for i in sorted(w):
                x, z = tip_sec.nodes[i]
                recs.append(fpoint(len(recs) + 1, x + ox, L, z, 0.0,
                                   F * w[i], 0.0))
    c.put('BC.dat', bc_text(recs))
    pts = points or [(0.0, L - 1e-6, 0.0)]
    pts = [(q[0] + ox, q[1], q[2]) for q in pts]
    c.put('POSTPROCESSING.dat', post_text(pts, para))
    return c


# -------------------------------------------------------------- PLATES
def plate_case(name, topo, ny, thick, *, L=LB, b=BB, h=HB_, nu=NU0,
               E=E0, rho=RHO0, sol=101, nmodes=6, shear='MITC',
               load=None, nx=1, points=None, para=False, ox=0.0,
               material=None, lamination=None, ply=None):
    """plane-strain cantilever strip: plate in the (x, y) plane, thickness
    z.  thick = ('LE', kind, ne) | ('TE', n) | ('HB', ne, p).
    load = ('shear', P) | ('moment', M, I) | ('axial_disp', d)."""
    if thick[0] == 'LE':
        tm = line_mesh(thick[1], thick[2], h, lam=ply or 1)
        tag = 'LE 1'
    elif thick[0] == 'TE':
        tm = line_mesh('B3', 1, h)
        tag = 'TE %d' % thick[1]
    else:
        tm = line_mesh('HB', thick[1], h, order=thick[2])
        tag = 'HLE'
    pm = rect_mesh(topo, nx, ny, -b / 2.0, b / 2.0, 0.0, L)
    c = Case(name)
    lines = ['%d' % len(pm.nodes), '']
    for i in sorted(pm.nodes):
        u, v = pm.nodes[i]
        lines.append('%d  %s  %s  0.0D0  %s' % (i, fmt(u + ox), fmt(v), tag))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % len(pm.elems), '']
    for k, (tp, ids, extra, lam) in enumerate(pm.elems):
        el.append('%s %d  %s  1  1' % (tp, k + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    c.put('ANALYSIS.dat', analysis_text(sol, nmodes, plate=shear))
    c.put('MATERIAL.dat', material or material_text(E, nu, rho))
    c.put('LAMINATION.dat', lamination or LAM_TEXT)
    c.put('EXP_MESH_01.dat', tm.mesh_text(False))
    c.put('EXP_CONN_01.dat', tm.conn_text())
    recs = [dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
            dplane(2, 1, 0, 0, b / 2.0 - ox, 0.0, None, None),
            dplane(3, 1, 0, 0, -b / 2.0 - ox, 0.0, None, None)]
    if sol == 101 and load:
        # tip edge nodes (y = L) and their consistent 1D weights
        edge = sorted([(pm.nodes[i][0], i) for i in pm.nodes
                       if abs(pm.nodes[i][1] - L) < 1e-12])
        ex = {i: 0.0 for _, i in edge}
        p = {'Q4': 1, 'Q9': 2, 'Q16': 3, 'T3': 1, 'T6': 2,
             'HQ4': 1}[topo]
        xs = [x for x, _ in edge]
        for cx in range(nx):
            seg = edge[cx * p: cx * p + p + 1]
            ln = seg[-1][0] - seg[0][0]
            for k, (_, i) in enumerate(seg):
                ex[i] += line_weights(p)[k] * ln
        kind = load[0]
        if kind in ('shear', 'shear_v'):
            P = load[1]
            tw = line_load_weights(tm)
            if kind == 'shear_v':        # only the two faces, h/2 each
                tw = {j: (h / 2.0 if abs(abs(tm.nodes[j][1]) - h / 2.0)
                          < 1e-12 else 0.0) for j in tm.nodes}
            for _, i in edge:
                for j in sorted(tm.nodes):
                    wz = tw[j]
                    z = tm.nodes[j][1]
                    f = P * ex[i] * wz / (b * h)
                    if abs(f) > 1e-14 * abs(P):
                        recs.append(fpoint(len(recs) + 1,
                                           pm.nodes[i][0] + ox,
                                           L, z, 0.0, 0.0, f))
        elif kind == 'moment':
            M, I = load[1], load[2]          # I per unit width
            for _, i in edge:
                cz = tm.consistent(lambda u, v: v)
                for j in sorted(tm.nodes):
                    z = tm.nodes[j][1]
                    f = -M * ex[i] / b * cz[j] / I
                    if abs(f) > 1e-14 * abs(M):
                        recs.append(fpoint(len(recs) + 1,
                                           pm.nodes[i][0] + ox,
                                           L, z, 0.0, f, 0.0))
        elif kind == 'axial_disp':
            recs.append(dplane(4, 0, 1, 0, -L, 0.0, load[1], 0.0))
    c.put('BC.dat', bc_text(recs))
    pts = points or [(0.0, L - 1e-6, 0.0)]
    pts = [(q[0] + ox, q[1], q[2]) for q in pts]
    c.put('POSTPROCESSING.dat', post_text(pts, para))
    return c


# -------------------------------------------------------------- SOLIDS
def solid_case(name, topo, ny, nz, *, L=LB, b=BB, h=HB_, nx=1, nu=NU0,
               E=E0, rho=RHO0, sol=101, nmodes=6, shear='NONE',
               load=None, points=None, para=False, ox=0.0,
               plane_strain=True):
    """block of H8 / H27 elements (plane strain by default)."""
    p, pat = H_PATTERN[topo]
    nxl, nyl, nzl = p * nx + 1, p * ny + 1, p * nz + 1
    c = Case(name)
    nid = lambda i, j, k: i + nxl * (j + nyl * k) + 1
    lines = ['%d' % (nxl * nyl * nzl), '']
    pos = {}
    for k in range(nzl):
        for j in range(nyl):
            for i in range(nxl):
                x = ox - b / 2 + b * i / (nxl - 1)
                y = L * j / (nyl - 1)
                z = -h / 2 + h * k / (nzl - 1)
                pos[nid(i, j, k)] = (x, y, z)
                lines.append('%d  %s  %s  %s  LE 1' % (
                    nid(i, j, k), fmt(x), fmt(y), fmt(z)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % (nx * ny * nz), '']
    e = 0
    for cz in range(nz):
        for cy in range(ny):
            for cx in range(nx):
                ids = [nid(p * cx + a - 1, p * cy + b_ - 1, p * cz + c_ - 1)
                       for (a, b_, c_) in pat]
                e += 1
                el.append('%s %d  %s  1  1' % (topo, e,
                                               ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', analysis_text(sol, nmodes, solid=shear))
    c.put('MATERIAL.dat', material_text(E, nu, rho))
    c.put('LAMINATION.dat', LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    recs = [dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0)]
    if plane_strain:
        recs += [dplane(2, 1, 0, 0, b / 2.0 - ox, 0.0, None, None),
                 dplane(3, 1, 0, 0, -b / 2.0 - ox, 0.0, None, None)]
    if sol == 101 and load:
        wx = [0.0] * nxl
        for cx in range(nx):
            for k in range(p + 1):
                wx[p * cx + k] += line_weights(p)[k] * (b / nx)
        kind = load[0]
        if kind == 'shear':
            P = load[1]
            wz = [0.0] * nzl
            for cz in range(nz):
                for k in range(p + 1):
                    wz[p * cz + k] += line_weights(p)[k] * (h / nz)
            for k in range(nzl):
                for i in range(nxl):
                    f = P * wx[i] * wz[k] / (b * h)
                    recs.append(fpoint(len(recs) + 1, pos[nid(i, nyl - 1, k)][0],
                                       L, pos[nid(i, nyl - 1, k)][2],
                                       0.0, 0.0, f))
        elif kind == 'moment':
            M, I = load[1], load[2]
            zn = [-h / 2 + h * k / (nzl - 1) for k in range(nzl)]
            cz = [0.0] * nzl
            for cell in range(nz):
                z0 = -h / 2 + cell * h / nz
                for gx, gw in GAUSS3:
                    z = z0 + (gx + 1) * h / nz / 2
                    xi = gx
                    grid = [-1 + 2 * kk / p for kk in range(p + 1)]
                    for kk in range(p + 1):
                        cz[p * cell + kk] += (lagrange(grid, kk, xi) * z
                                              * gw * h / nz / 2)
            for k in range(nzl):
                for i in range(nxl):
                    f = -M * wx[i] / b * cz[k] / I
                    recs.append(fpoint(len(recs) + 1, pos[nid(i, nyl - 1, k)][0],
                                       L, pos[nid(i, nyl - 1, k)][2],
                                       0.0, f, 0.0))
        elif kind == 'axial_disp':
            recs.append(dplane(4, 0, 1, 0, -L, 0.0, load[1], 0.0))
    c.put('BC.dat', bc_text(recs))
    pts = points or [(0.0, L - 1e-6, 0.0)]
    pts = [(q[0] + ox, q[1], q[2]) for q in pts]
    c.put('POSTPROCESSING.dat', post_text(pts, para))
    return c


# ------------------------------------------------------------ reporting
def rel(a, b):
    return abs(a - b) / max(abs(b), 1e-300)
