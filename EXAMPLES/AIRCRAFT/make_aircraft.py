"""Demonstrator: a transport aircraft (737-like proportions) with 1D, 2D and
3D elements, free vibration (analysis 103).

    python EXAMPLES/AIRCRAFT/make_aircraft.py [--mesh coarse|medium|fine]
                                              [--out DIR] [--modes N]

The model is a **dimensional demonstrator**: geometry, thicknesses and masses
are plausible, they are not data of a real aircraft.  Units: m, N, kg, Pa.
x aft, y to the right, z up.

 elements
   S9   fuselage skin, frames (web + flange), floor, wing / tail skins,
        spars, ribs, leading and trailing edge fairings, pylons  (2D)
   CB3  tie rods pylon / wing skin, one straight and one curved per
        engine (curved beams, order 0 at their two end nodes)    (1D)
   H8   engines (sheared blocks, order 0 at the pylon nodes)      (3D)

 the parts are joined by SHARED NODES (node-dependent kinematics, no

 multipliers): shell-shell nodes have the thickness expansion TE 2 (the
 edges between shells carry the rotation of the node), the nodes shared by a
 shell and a beam or a solid have the order 0 and are ISOLATED nodes: a row
 of order-0 nodes would lock the bending of the skin.  Stiffeners are in the
 thickness of the skins and the fuel / payload masses in the densities.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'TESTS', 'VALIDATION'))
import vlib as V  # noqa: E402

IXS = [1, 2, 3, 3, 3, 2, 1, 1, 2]
IYS = [1, 1, 1, 2, 3, 3, 3, 2, 2]
TOL = 1.0e-6

MESHES = {
    #            ntheta, axial el. nose/cyl/tail, chord el., span el.
    'coarse': dict(nth=16, nose=2, cyl=8, tail=4, nch=1, ny=4, frame=2),
    'medium': dict(nth=24, nose=3, cyl=12, tail=6, nch=2, ny=8, frame=2),
    'fine': dict(nth=32, nose=4, cyl=16, tail=8, nch=3, ny=12, frame=2),
}

# ------------------------------------------------------------ geometry
R_FUS, L_NOSE, L_CYL, L_TAIL = 1.9, 5.0, 23.0, 10.0
X_CYL0, X_CYL1 = L_NOSE, L_NOSE + L_CYL
X_END = X_CYL1 + L_TAIL
R_NOSE_TIP, R_TAIL_TIP, TAIL_UP = 0.25, 0.45, 0.9
FLOOR_THETA = math.radians(112.5)
FRAME_H = 0.12
DELTA = math.radians(15.0)           # half angle of a wing / tail root


def radius(x):
    if x < X_CYL0:
        s = (X_CYL0 - x) / L_NOSE
        return R_NOSE_TIP + (R_FUS - R_NOSE_TIP) * math.sqrt(max(0.0, 1 - s * s))
    if x <= X_CYL1:
        return R_FUS
    s = (x - X_CYL1) / L_TAIL
    return R_FUS - (R_FUS - R_TAIL_TIP) * s ** 1.5


def axis_z(x):
    if x <= X_CYL1:
        return 0.0
    s = (x - X_CYL1) / L_TAIL
    return TAIL_UP * s * s


def fus_point(x, th):
    r = radius(x)
    return (x, r * math.sin(th), axis_z(x) + r * math.cos(th))


def lerp(a, b, t):
    return tuple(a[k] + t * (b[k] - a[k]) for k in range(3))


def sub(a, b):
    return tuple(a[k] - b[k] for k in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(a[k] * b[k] for k in range(3))


# ------------------------------------------------------------ the model
class Model:
    def __init__(self):
        self.coord = []              # node coordinates
        self.kin = []                # node kinematic token
        self.index = {}
        self.shells = []             # (ids, expansion id, versor id)
        self.rods = []               # (ids, expansion id, versor id, name)
        self.solids = []             # (ids, expansion id)
        self.meshes = []             # expansion meshes
        self.mesh_key = {}
        self.versors = []
        self.materials = {}          # id -> (E, nu, rho, ortho)
        self.laminas = []            # (id, material, angle)

    def node(self, p, kin=None):
        key = tuple(int(round(c / TOL)) for c in p)
        i = self.index.get(key)
        if i is None:
            self.coord.append(tuple(p))
            self.kin.append('TE2')
            i = len(self.coord)
            self.index[key] = i
        if kin is not None:
            self.kin[i - 1] = kin
        return i

    def mesh(self, kind, size, lam):
        """expansion mesh: ('plate', t) 1D thickness, ('rod', a) square
        section of side a, ('point') for the solids."""
        key = (kind, round(size, 9), lam)
        if key not in self.mesh_key:
            self.meshes.append(key)
            self.mesh_key[key] = len(self.meshes)
        return self.mesh_key[key]

    def versor(self, v):
        n = math.sqrt(dot(v, v))
        v = tuple(c / n for c in v)
        if v not in self.versors:
            self.versors.append(v)
        return self.versors.index(v) + 1

    def patch(self, P, expansion, sor, hint=None, kin=None):
        """Q9 shells on a grid of points P[i][j] ((2a+1) x (2b+1)); the
        element orientation follows hint(centre) when it is given."""
        na, nb = (len(P) - 1) // 2, (len(P[0]) - 1) // 2
        ids = [[self.node(P[i][j], kin) for j in range(len(P[0]))]
               for i in range(len(P))]
        for ei in range(na):
            for ej in range(nb):
                i0, j0 = 2 * ei, 2 * ej
                a1 = sub(P[i0 + 2][j0 + 1], P[i0][j0 + 1])
                a2 = sub(P[i0 + 1][j0 + 2], P[i0 + 1][j0])
                n = cross(a1, a2)
                flip = False
                if hint is not None:
                    c = P[i0 + 1][j0 + 1]
                    flip = dot(n, hint(c)) < 0.0
                eid = expansion(ei, ej) if callable(expansion) else expansion
                if flip:
                    nodes = [ids[i0 + IYS[a] - 1][j0 + IXS[a] - 1]
                             for a in range(9)]
                else:
                    nodes = [ids[i0 + IXS[a] - 1][j0 + IYS[a] - 1]
                             for a in range(9)]
                self.shells.append((nodes, eid, sor))

    def rod(self, points, expansion, sor, name, kin='TE0'):
        """B3 elements along a chain of nodes (odd number of points)."""
        ids = [self.node(p, kin) for p in points]
        for e in range((len(ids) - 1) // 2):
            self.rods.append((ids[2 * e:2 * e + 3], expansion, sor, name))

    def hex_block(self, X, Y, Z, expansion, kin='TE0'):
        """H8 elements on a structured grid of coordinates."""
        pat = V.H_PATTERN['H8'][1]
        nid = {}
        for i, x in enumerate(X):
            for j, y in enumerate(Y):
                for k, z in enumerate(Z):
                    nid[(i, j, k)] = self.node((x, y, z), kin)
        for i in range(len(X) - 1):
            for j in range(len(Y) - 1):
                for k in range(len(Z) - 1):
                    self.solids.append(([nid[(i + a - 1, j + b - 1, k + c - 1)]
                                         for (a, b, c) in pat], expansion))


def frange(a, b, n):
    return [a + (b - a) * k / n for k in range(n + 1)]


# ------------------------------------------------------------ parts
def build(cfg):
    M = Model()
    # materials: 1 aluminium, 2 floor (+ payload), 3 lower wing skin
    # (+ fuel), 4 engine (mass), 5 carbon-epoxy ply
    M.materials[1] = ('ISO', 72.0e9, 0.33, 2800.0)
    M.materials[2] = ('ISO', 72.0e9, 0.33, 2800.0)
    M.materials[3] = ('ISO', 72.0e9, 0.33, 2800.0)
    M.materials[6] = ('ISO', 72.0e9, 0.33, 2800.0 + 30000.0)   # fuel (wing webs)
    M.materials[7] = ('ISO', 72.0e9, 0.33, 2800.0 + 53000.0)   # payload (floor beams)
    M.materials[4] = ('ISO', 40.0e9, 0.30, 400.0)
    M.materials[5] = ('ORT', None, None, 1600.0)
    M.laminas = [(1, 1, 0.0), (2, 2, 0.0), (3, 3, 0.0), (4, 4, 0.0),
                 (5, 5, 0.0), (6, 5, 90.0), (7, 6, 0.0), (8, 7, 0.0)]
    s_fus_x = M.versor((1, 0, 0))
    s_span = M.versor((0, 1, 0))
    s_vert = M.versor((0, 0, 1))
    s_rod = M.versor((0, 0, 1))

    wing_only = cfg.get('wing_only', False)
    nth = cfg['nth']
    nxs = dict(nose=cfg['nose'], cyl=cfg['cyl'], tail=cfg['tail'])
    # axial node positions of the fuselage (half steps inside elements)
    xs = []
    secs = [(0.0, X_CYL0, nxs['nose']), (X_CYL0, X_CYL1, nxs['cyl']),
            (X_CYL1, X_END, nxs['tail'])]
    elem_x = []                      # element boundaries
    for (a, b, n) in secs:
        for k in range(2 * n + (1 if (a, b, n) == secs[-1] else 0)):
            xs.append(a + (b - a) * k / (2 * n))
        elem_x += [a + (b - a) * k / n for k in range(n)]
    elem_x.append(X_END)
    thetas = [2 * math.pi * k / (2 * nth) for k in range(2 * nth + 1)]
    dth = thetas[1]

    nzel = max(1, int(round(DELTA / dth)))     # vertical elements of a root
    nzr = 2 * nzel + 1
    t_skin = [M.mesh('plate', t, 1) for t in (0.0020, 0.0016)]
    # fuselage skin: thicker in the cylinder, thinner in the cones
    def fus_exp_for(xa):
        return t_skin[0] if X_CYL0 <= xa < X_CYL1 else t_skin[1]
    nel_x = len(elem_x) - 1
    ex_of = lambda ei, ej: fus_exp_for(elem_x[ei])
    P = [[fus_point(x, th) for th in thetas] for x in xs]
    if not wing_only:
        M.patch(P, ex_of, s_fus_x,
                hint=lambda c: (0.0, c[1], c[2] - axis_z(c[0])))

    # frames: web (annulus) and inner flange (cylinder band)
    t_web, t_fl = M.mesh('plate', 0.0018, 1), M.mesh('plate', 0.0025, 1)
    for ib in range(1, nel_x, cfg['frame']):
        x = elem_x[ib]
        r0 = radius(x)
        zc = axis_z(x)
        rr = [r0 - FRAME_H * k / 2.0 for k in range(3)]
        W = [[(x, rho * math.sin(th), zc + rho * math.cos(th))
              for th in thetas] for rho in rr]
        M.patch(W, t_web, s_vert)
        rin = r0 - FRAME_H
        Fl = [[(x + dx, rin * math.sin(th), zc + rin * math.cos(th))
               for th in thetas] for dx in (-0.04, 0.0, 0.04)]
        M.patch(Fl, t_fl, s_fus_x, hint=lambda c: (0.0, c[1], c[2] - axis_z(c[0])))

    # floor in the cylindrical part
    t_floor = M.mesh('plate', 0.004, 2)
    ycyl = [x for x in xs if X_CYL0 - 1e-9 <= x <= X_CYL1 + 1e-9]
    ye = R_FUS * math.sin(FLOOR_THETA)
    zf = R_FUS * math.cos(FLOOR_THETA)
    nyf = nth // 2
    Fp = [[(x, -ye + 2 * ye * k / (2 * nyf), zf) for k in range(2 * nyf + 1)]
          for x in ycyl]
    M.patch(Fp, t_floor, s_fus_x, hint=lambda c: (0, 0, 1))
    # floor beams (T sections of shells, web and flange): transverse ones at
    # the frames, three longitudinal ones (seat tracks)
    t_fw, t_ff = M.mesh('plate', 0.0030, 8), M.mesh('plate', 0.0030, 1)
    hb = 0.18
    ylat = [-ye + 2 * ye * k / (2 * nyf) for k in range(2 * nyf + 1)]
    for ib in range(1, nel_x):
        x = elem_x[ib]
        if not (X_CYL0 < x < X_CYL1):
            continue
        M.patch([[(x, y, zf - hb * m / 2.0) for m in range(3)]
                 for y in ylat], t_fw, s_vert)
        M.patch([[(x + dx, y, zf - hb) for y in ylat]
                 for dx in (-0.04, 0.0, 0.04)], t_ff, s_fus_x)
    for k in (nyf // 2, nyf, nyf + nyf // 2):
        y = ylat[k]
        M.patch([[(x, y, zf - hb * m / 2.0) for m in range(3)]
                 for x in ycyl], t_fw, s_vert)
        M.patch([[(x, y + dy, zf - hb) for dy in (-0.04, 0.0, 0.04)]
                 for x in ycyl], t_ff, s_fus_x)

    a_rod = M.mesh('rod', 0.06, 1)

    # ---------------------------------------------------- lifting surfaces
    def lifting_surface(root, tip, ny, sor_skin, sor_web, hint_up, hint_lo,
                        zones, mat_up=1, mat_lo=1, rib_every=2,
                        fairings=None, rod_rows=(), sor_rib=None,
                        lam_web=1):
        """root[i][j], tip[i][j]: grids (chord node, thickness node); the
        station k of the 2*ny+1 span nodes is the blend of both."""
        ni, nj = len(root), len(root[0])
        Pk = [[[lerp(root[i][j], tip[i][j], k / (2.0 * ny))
                for k in range(2 * ny + 1)] for j in range(nj)]
              for i in range(ni)]
        def zone_exp(mat, scale=1.0):
            ids = [M.mesh('plate', t * scale, mat) for t in zones]
            nz = len(zones)
            return lambda ei, ej: ids[min(nz - 1, ej * nz // ny)]
        up = [[Pk[i][nj - 1][k] for k in range(2 * ny + 1)] for i in range(ni)]
        lo = [[Pk[i][0][k] for k in range(2 * ny + 1)] for i in range(ni)]
        M.patch(up, zone_exp(mat_up), sor_skin, hint=hint_up)
        M.patch([row for row in lo][::1], zone_exp(mat_lo),
                sor_skin, hint=hint_lo)
        tsp = M.mesh('plate', 0.005, lam_web)
        trb = M.mesh('plate', 0.004, lam_web)
        for i in (0, ni - 1):
            web = [[Pk[i][j][k] for k in range(2 * ny + 1)] for j in range(nj)]
            M.patch(web, tsp, sor_web)
        sor_rib = sor_rib or sor_web
        stations = sorted(set(range(2 * rib_every, 2 * ny, 2 * rib_every))
                          | {2 * ny})
        for k in stations:
            rib = [[Pk[i][j][k] for j in range(nj)] for i in range(ni)]
            M.patch(rib, trb, sor_rib)
        if fairings and cfg.get('fairings', True):
            fairings(Pk, ny)
        return Pk

    def wing(side):
        nch = cfg['nch']
        ncx = 2 * nch + 1
        nz = nzr
        cyl_x = [x for x in xs if X_CYL0 - 1e-9 <= x <= X_CYL1 + 1e-9]
        i0 = len(cyl_x) // 2 - nch
        root = []
        for i in range(ncx):
            col = []
            for j in range(nz):
                th = math.pi / 2 + nzel * dth - j * dth if side > 0 else \
                    3 * math.pi / 2 - nzel * dth + j * dth
                p = fus_point(cyl_x[i0 + i], th)
                if wing_only:               # planar root for the diagnostic
                    p = (p[0], side * R_FUS, p[2])
                col.append(p)
            root.append(col)
        # tip box (right wing; mirrored for the left one)
        y_tip, sweep_f, c_tip, h_tip, dih = 18.3, 0.52, 1.35, 0.26, math.radians(5)
        xf0 = root[0][0][0]
        xr0 = root[-1][0][0]
        dy = y_tip - R_FUS
        xf_t = xf0 + sweep_f * dy
        zc_t = dih and math.tan(dih) * dy
        tip = []
        for i in range(ncx):
            col = []
            for j in range(nz):
                x = xf_t + c_tip * i / (ncx - 1)
                z = zc_t + h_tip * (j / (nz - 1) - 0.5)
                col.append((x, side * y_tip, z))
            tip.append(col)

        if cfg.get('uniform'):
            tip = [[(root[i][j][0], side * y_tip, root[i][j][2])
                    for j in range(nz)] for i in range(ncx)]

        def fairings(Pk, ny):
            ni, nj = len(Pk), len(Pk[0])
            tfa = M.mesh('plate', 0.0025, 1)
            # leading edge: half ellipse from the top to the bottom of the
            # front spar
            arc = []
            for k in range(2 * ny + 1):
                top, bot = Pk[0][nj - 1][k], Pk[0][0][k]
                mid = lerp(top, bot, 0.5)
                chord = Pk[ni - 1][0][k][0] - Pk[0][0][k][0]
                a = 0.28 * chord
                h = (top[2] - bot[2]) / 2
                row = []
                for m in range(9):
                    t = math.pi * m / 8.0
                    row.append((top[0] - a * math.sin(t),
                                top[1],
                                mid[2] + h * math.cos(t)))
                arc.append(row)
            M.patch(arc, tfa, s_span)
            # trailing edge: wedge closed by a small vertical strip
            gap = 0.015
            ups, los, cls = [], [], []
            for k in range(2 * ny + 1):
                rt, rb = Pk[ni - 1][nj - 1][k], Pk[ni - 1][0][k]
                chord = rt[0] - Pk[0][0][k][0]
                e = 0.34 * chord
                zm = 0.5 * (rt[2] + rb[2])
                te_u = (rt[0] + e, rt[1], zm + gap)
                te_l = (rb[0] + e, rb[1], zm - gap)
                ups.append([lerp(rt, te_u, m / 2.0) for m in range(3)])
                los.append([lerp(rb, te_l, m / 2.0) for m in range(3)])
                cls.append([lerp(te_l, te_u, m / 2.0) for m in range(3)])
            M.patch([[ups[k][m] for k in range(2 * ny + 1)] for m in range(3)],
                    tfa, s_span, hint=lambda c: (0, 0, 1))
            M.patch([[los[k][m] for k in range(2 * ny + 1)] for m in range(3)],
                    tfa, s_span, hint=lambda c: (0, 0, -1))
            M.patch([[cls[k][m] for k in range(2 * ny + 1)] for m in range(3)],
                    tfa, s_span, hint=lambda c: (1, 0, 0))

        Pk = lifting_surface(
            root, tip, cfg['ny'], s_span, s_vert, lambda c: (0, 0, 1),
            lambda c: (0, 0, -1),
            (0.0080, 0.0080, 0.0080) if cfg.get('uniform') else
            (0.0080, 0.0060, 0.0045), mat_up=1,
            mat_lo=1, fairings=fairings, rib_every=1, lam_web=7)
        return Pk, nz, ncx

    for side in ((1,) if wing_only else (1, -1)):
        Pk, nzw, ncxw = wing(side)
        if cfg.get('engines', True):
            # engine under the wing at the second rib: pylon + solid block
            k = 4 if cfg['ny'] >= 4 else 2
            dz = 0.30
            tpy = M.mesh('plate', 0.008, 1)
            ks = (k - 1, k, k + 1)
            low = lambda i, kk: Pk[i][0][kk]
            down = lambda p, m: (p[0], p[1], p[2] - m * dz)
            # pylon: a box of four plates hung from the lower skin
            for kk in (ks[0], ks[2]):                  # sides (x-z planes)
                M.patch([[down(low(i, kk), m) for m in range(5)]
                         for i in range(ncxw)], tpy, s_vert)
            for i in (0, ncxw - 1):                    # front and rear
                M.patch([[down(low(i, kk), m) for m in range(5)]
                         for kk in ks], tpy, s_rod)
            # the engine: a sheared grid of hexahedra whose upper face
            # is the lowest row of the pylon (nodes shared, order 0)
            pat = V.H_PATTERN['H8'][1]
            gid = {}
            # increasing y (right-handed hexahedra) on both sides
            for jj, kk in enumerate(ks if side > 0 else ks[::-1]):
                for i in range(ncxw):
                    p = low(i, kk)
                    ztop = p[2] - 4 * dz
                    for q in range(3):
                        z = ztop - 1.4 + 0.7 * q
                        gid[(i, jj, q)] = M.node((p[0], p[1], z), 'TE0')
            emesh = M.mesh('point', 0.0, 4)
            for i in range(ncxw - 1):
                for jj in range(2):
                    for q in range(2):
                        M.solids.append((
                            [gid[(i + a - 1, jj + b - 1, q + c - 1)]
                             for (a, b, c) in pat], emesh))
            # 1D elements: tie rods from the lower skin (an isolated node of
            # the middle station) to the top of the engine, inside the pylon:
            # a straight one and a curved one (nodes shared, order 0)
            for i, bulge in ((1, 0.0), (max(1, ncxw - 2), 0.12)):
                ptop = low(i, ks[1])
                pbot = (ptop[0], ptop[1], ptop[2] - 4 * dz)
                pmid = (ptop[0] + bulge, ptop[1], 0.5 * (ptop[2] + pbot[2]))
                M.rod([ptop, pmid, pbot], a_rod, s_fus_x, 'B3')

    if wing_only:
        prune(M, M.shells[-1][0][0] if not M.solids else M.solids[0][0][0])
        return M
    # horizontal and vertical tail
    def tail_root_from_fuselage(nch, center, nz, vertical):
        tail_x = [x for x in xs if X_CYL1 + 1e-9 <= x]
        i0 = len(tail_x) // 2 - nch
        root = []
        for i in range(2 * nch + 1):
            col = []
            for j in range(nz):
                off = nzel * dth - j * dth
                col.append(fus_point(tail_x[i0 + i], center + off))
            root.append(col)
        return root

    nz = nzr
    nch = cfg['nch']
    # horizontal tail: one on each side (theta ~ 90, 270)
    for side in (1, -1):
        root = tail_root_from_fuselage(nch, math.pi / 2 if side > 0 else
                                       3 * math.pi / 2, nz, False)
        if side < 0:
            root = [[root[i][nz - 1 - j] for j in range(nz)]
                    for i in range(len(root))]
            root = [[(p[0], p[1], p[2]) for p in col] for col in root]
        ncx = len(root)
        xf0, xr0 = root[0][0][0], root[-1][0][0]
        y_t = 7.2
        dy = y_t - 1.0
        xf_t = xf0 + 0.62 * dy
        tip = []
        for i in range(ncx):
            col = []
            for j in range(nz):
                col.append((xf_t + 1.3 * i / (ncx - 1), side * y_t,
                            axis_z(xf0) + 0.3 + 0.18 * (j / (nz - 1) - 0.5)))
            tip.append(col)
        lifting_surface(root, tip, max(2, cfg['ny'] // 2), s_span, s_vert,
                        lambda c: (0, 0, 1), lambda c: (0, 0, -1),
                        (0.0045, 0.0032), mat_up=5, mat_lo=5,
                        rib_every=1)
    # vertical tail on the top of the fuselage (theta ~ 0), thickness in y
    root = []
    tail_x = [x for x in xs if X_CYL1 + 1e-9 <= x]
    i0 = max(0, len(tail_x) // 2 - nch - 1)
    for i in range(2 * nch + 1):
        col = []
        for j in range(nz):
            th = -nzel * dth + j * dth
            col.append(fus_point(tail_x[i0 + i], th))
        root.append(col)
    xf0 = root[0][0][0]
    z0 = root[0][nz // 2][2]
    tip = []
    for i in range(len(root)):
        col = []
        for j in range(nz):
            col.append((xf0 + 0.55 * 5.4 + 1.5 * i / (len(root) - 1),
                        0.16 * (j / (nz - 1) - 0.5), z0 + 5.4))
        tip.append(col)
    lifting_surface(root, tip, max(2, cfg['ny'] // 2), s_vert, s_vert,
                    lambda c: (0, 1, 0), lambda c: (0, -1, 0),
                    (0.0045, 0.0032), mat_up=5, mat_lo=5, rib_every=1,
                    sor_rib=s_fus_x)
    return M


def prune(M, seed):
    """keeps the elements connected (by shared nodes) to the node `seed`."""
    parent = {}

    def find(a):
        r = a
        while parent.setdefault(r, r) != r:
            r = parent[r]
        while parent[a] != r:
            parent[a], a = r, parent[a]
        return r
    groups = [e[0] for e in M.shells] + [e[0] for e in M.rods] + \
        [e[0] for e in M.solids]
    for g in groups:
        for n in g[1:]:
            parent[find(n)] = find(g[0])
    keep = find(seed)
    used = sorted({n for g in groups if find(g[0]) == keep for n in g})
    new = {old: k + 1 for k, old in enumerate(used)}
    M.coord = [M.coord[o - 1] for o in used]
    M.kin = [M.kin[o - 1] for o in used]
    M.shells = [([new[n] for n in g], e, s) for (g, e, s) in M.shells
                if find(g[0]) == keep]
    M.rods = [([new[n] for n in g], e, s, nm) for (g, e, s, nm) in M.rods
              if find(g[0]) == keep]
    M.solids = [([new[n] for n in g], e) for (g, e) in M.solids
                if find(g[0]) == keep]


# ------------------------------------------------------------ writers
def write(model, out, nmodes, static=0.0):
    M = model
    os.makedirs(os.path.join(out, 'INPUT'), exist_ok=True)
    for sub_dir in ('REPORT', 'STATIC', 'DYNAMIC', 'WORK'):
        os.makedirs(os.path.join(out, sub_dir), exist_ok=True)

    def put(name, text):
        with open(os.path.join(out, 'INPUT', name), 'w', newline='\n') as f:
            f.write(text)

    kin, ktxt = V.kin_nodes_text(M.coord, M.kin)
    put('NODES.dat', kin)
    put('KINEMATICS.dat', ktxt)
    el = []
    for ids, eid, sor in M.shells:
        el.append('S9 %d  %s  %d  %d' % (len(el) + 1,
                                         ' '.join(map(str, ids)), sor, eid))
    for ids, eid, sor, name in M.rods:
        el.append('CB3 %d  %s  %d  %d' % (len(el) + 1,
                                          ' '.join(map(str, ids)), sor, eid))
    for ids, eid in M.solids:
        el.append('H8 %d  %s  %d  %d' % (len(el) + 1,
                                         ' '.join(map(str, ids)), 1, eid))
    put('CONNECTIVITY.dat', '%d\n\n' % len(el) + '\n'.join(el) + '\n')
    put('VERSORS.dat', '%d\n\n' % len(M.versors) + '\n'.join(
        'VERSOR %d  %s %s %s' % (k + 1, V.fmt(v[0]), V.fmt(v[1]), V.fmt(v[2]))
        for k, v in enumerate(M.versors)) + '\n')
    # materials
    mat = []
    for k in sorted(M.materials):
        kind, E, nu, rho = M.materials[k]
        if kind == 'ISO':
            mat.append('ISO-M %d  %s %s %s' % (k, V.fmt(E), V.fmt(nu), V.fmt(rho)))
        else:   # carbon-epoxy ply (E1 E2 E3 nu12 nu13 nu23 G12 G13 G23 rho)
            mat.append('ORT-M %d  140.0D9 10.0D9 10.0D9  0.3 0.3 0.4  '
                       '5.0D9 5.0D9 3.5D9  %s' % (k, V.fmt(rho)))
    put('MATERIAL.dat', '%d %d\n\n' % (len(M.materials), len(mat))
        + '\n'.join(mat) + '\n')
    put('LAMINATION.dat', '%d\n\n' % len(M.laminas) + '\n'.join(
        'LAM2 %d %d 0.0 %s' % (i, m, V.fmt(a)) for (i, m, a) in M.laminas)
        + '\n')
    for n, (kind, size, lam) in enumerate(M.meshes, 1):
        if kind == 'plate':
            tm = V.line_mesh('B3', 1, size, lam=lam)
            put('EXP_MESH_%02d.dat' % n, tm.mesh_text(False))
            put('EXP_CONN_%02d.dat' % n, tm.conn_text())
        elif kind == 'rod':
            sec = V.rect_mesh('Q4', 1, 1, -size / 2, size / 2, -size / 2,
                              size / 2, lam=lam)
            put('EXP_MESH_%02d.dat' % n, sec.mesh_text(True))
            put('EXP_CONN_%02d.dat' % n, sec.conn_text())
        else:
            put('EXP_MESH_%02d.dat' % n, '1\n\n1  0.0D0 0.0D0 0.0D0\n')
            put('EXP_CONN_%02d.dat' % n, '1\n\nS1 1 %d 1\n' % lam)
    p = M.coord[0]
    if static:
        # analysis 101: fuselage clamped at the nose ring (x = L_NOSE),
        # upward force at the tip of each wing
        put('ANALYSIS.dat', V.analysis_text(101, 6, beam='MITC',
                                            plate='MITC', solid='NONE'))
        recs = [V.dplane(1, 1.0, 0.0, 0.0, -L_NOSE, 0.0, 0.0, 0.0)]
        ymax = max(abs(r[1]) for r in M.coord)
        tips = []
        for sgn in (1.0, -1.0):
            c = [q for q in M.coord if abs(q[1] - sgn * ymax) < 1e-6]
            c.sort(key=lambda q: q[0])
            tips.append(c[len(c) // 2])
        for q in tips:
            recs.append(V.fpoint(len(recs) + 1, q[0], q[1], q[2], 0.0, 0.0,
                                 static))
        put('BC.dat', V.bc_text(recs))
        put('POSTPROCESSING.dat', V.post_text(
            [(q[0], q[1], q[2]) for q in tips], para=True))
        return
    put('ANALYSIS.dat', V.analysis_text(103, nmodes, beam='MITC',
                                        plate='MITC', solid='NONE'))
    if getattr(M, 'clamp_plane', None):
        put('BC.dat', '1\n\nD-PLANE 1  %s 0.0 0.0 0.0\n' % M.clamp_plane)
    else:
        put('BC.dat', '1\n\nF-POINT 1  %s %s %s  0.0 0.0 0.0\n' % (
            V.fmt(p[0]), V.fmt(p[1]), V.fmt(p[2])))
    put('POSTPROCESSING.dat', '1\n\nPARA 20 GLB 1 1 1 1 1 1 1 1 1\n')


def summary(M):
    mass_note = 'masses are smeared in the densities of the parts'
    n_sh, n_rod, n_sol = len(M.shells), len(M.rods), len(M.solids)
    return ('%d nodes, %d shells (S9), %d rods/curved beams (CB3), '
            '%d solids (H8); %s' % (len(M.coord), n_sh, n_rod, n_sol,
                                    mass_note))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--mesh', default='coarse', choices=list(MESHES))
    ap.add_argument('--out', default=os.path.join(HERE, 'CASE'))
    ap.add_argument('--modes', type=int, default=16)
    ap.add_argument('--wing-only', action='store_true',
                    help='diagnostic: one clamped wing')
    ap.add_argument('--no-fairings', action='store_true')
    ap.add_argument('--no-engines', action='store_true')
    ap.add_argument('--uniform', action='store_true')
    ap.add_argument('--static', type=float, default=0.0,
                    help='analysis 101 with this force [N] at each wing tip')
    a = ap.parse_args()
    cfg = dict(MESHES[a.mesh])
    cfg['wing_only'] = a.wing_only
    cfg['fairings'] = not a.no_fairings
    cfg['engines'] = not a.no_engines
    cfg['uniform'] = a.uniform
    model = build(cfg)
    if a.wing_only:
        model.clamp_plane = '0 1 0 %s' % V.fmt(-R_FUS)
    write(model, a.out, a.modes, a.static)
    print(summary(model))
    print('written to', a.out)
