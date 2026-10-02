"""Curved beams and shells (general geometry).

    python TESTS/CURVED/curved_tests.py [path_to_MUL2_V3.exe]

 1. a straight beam named CB4 gives the same result as B4 (algebra of the
    general kernel, with and without MITC);
 2. a flat plate named S9 gives the same result as Q9 (TE, LE, MITC9,
    rotated orthotropic ply);
 3. quarter ring cantilever (curved beam): tip deflection against the
    energy (Castigliano) solution, bending stress, rigid-body modes and
    the first frequency of the free ring;
 4. pinched cylinder with rigid diaphragms (MacNeal-Harder): shell with
    TE and LE thickness expansions, with and without exact directors.
"""
import math
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    os.environ['MUL2_EXE'] = os.path.abspath(sys.argv[1])
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_curved_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


# ------------------------------------------------------------------ 1
sec_b = V.rect_mesh('Q9', 2, 2, -V.BB / 2, V.BB / 2, -V.HB_ / 2, V.HB_ / 2)
for shear in ('NONE', 'MITC'):
    tip = {}
    for kind in ('B4', 'CB4'):
        c = V.beam_case('str_%s_%s' % (kind, shear), sec_b, 'LE 1', nel=3,
                        btype='B4', load=('shear', 1.0e3), shear=shear)
        if kind == 'CB4':
            c.files['CONNECTIVITY.dat'] = \
                c.files['CONNECTIVITY.dat'].replace('B4 ', 'CB4 ')
        r = c.run()
        check('straight %s %s runs' % (kind, shear), r.ok,
              r.log[-300:] if not r.ok else '')
        tip[kind] = r.u()[2]
    close('straight beam, general kernel = ordinary kernel (%s)' % shear,
          tip['CB4'], tip['B4'], 1e-9)

# ------------------------------------------------------------------ 2
ORT = ('1 1\n\nORT-M 1  140.0D9 10.0D9 10.0D9  0.3 0.3 0.4  '
       '5.0D9 5.0D9 3.5D9  1600.0\n')
for shear in ('NONE', 'MITC'):
    for thick in (('LE', 'B3', 2), ('TE', 2)):
        res = {}
        for kind in ('Q9', 'S9'):
            c = V.plate_case('pl_%s_%s_%s' % (kind, shear, thick[0]), 'Q9',
                             3, thick, nx=1, load=('shear', 1.0e3),
                             shear=shear)
            if kind == 'S9':
                c.files['CONNECTIVITY.dat'] = re.sub(
                    r'(?m)^Q9 ', 'S9 ', c.files['CONNECTIVITY.dat'])
            r = c.run()
            check('flat plate %s %s %s runs' % (kind, shear, thick[0]),
                  r.ok, r.log[-300:] if not r.ok else '')
            res[kind] = r.u()[2]
        close('flat plate, shell = plate (%s, %s)' % (shear, thick[0]),
              res['S9'], res['Q9'], 1e-9)
res = {}
for kind in ('Q9', 'S9'):
    c = V.plate_case('plply_%s' % kind, 'Q9', 3, ('TE', 2), nx=1,
                     load=('shear', 1.0e3), shear='MITC', material=ORT,
                     lamination='1\n\nLAM2 1 1 0.0 30.0\n')
    if kind == 'S9':
        c.files['CONNECTIVITY.dat'] = re.sub(
            r'(?m)^Q9 ', 'S9 ', c.files['CONNECTIVITY.dat'])
    r = c.run()
    check('rotated ply %s runs' % kind, r.ok, r.log[-300:]
          if not r.ok else '')
    res[kind] = r.u()[2]
close('flat plate with a 30 degree ply, shell = plate', res['S9'],
      res['Q9'], 1e-9)

# every topology of the family, with and without tying
for topo, alias in (('Q4', 'S4'), ('Q16', 'S16')):
    for shear in ('NONE', 'MITC'):
        res = {}
        for kind in (topo, alias):
            c = V.plate_case('tp_%s_%s' % (kind, shear), topo, 3, ('TE', 2),
                             nx=2 if topo == 'Q4' else 1,
                             load=('shear', 1.0e3), shear=shear)
            if kind == alias:
                c.files['CONNECTIVITY.dat'] = re.sub(
                    r'(?m)^%s ' % topo, alias + ' ',
                    c.files['CONNECTIVITY.dat'])
            r = c.run()
            check('flat plate %s %s runs' % (kind, shear), r.ok,
                  r.log[-300:] if not r.ok else '')
            res[kind] = r.u()[2]
        close('flat plate, shell = plate (%s, %s)' % (alias, shear),
              res[alias], res[topo], 1e-9)
for bt, al in (('B2', 'CB2'), ('B3', 'CB3')):
    for shear in ('NONE', 'MITC'):
        res = {}
        for kind in (bt, al):
            c = V.beam_case('bt_%s_%s' % (kind, shear), sec_b, 'LE 1',
                            nel=4, btype=bt, load=('shear', 1.0e3),
                            shear=shear)
            if kind == al:
                c.files['CONNECTIVITY.dat'] = \
                    c.files['CONNECTIVITY.dat'].replace(bt + ' ', al + ' ')
            r = c.run()
            check('straight %s %s runs' % (kind, shear), r.ok,
                  r.log[-300:] if not r.ok else '')
            res[kind] = r.u()[2]
        close('straight beam, %s = %s (%s)' % (al, bt, shear), res[al],
              res[bt], 1e-9)

# ------------------------------------------------------------------ 3
E, NU = V.E0, V.NU0
R_RING, H_RING = 10.0, 0.25
SEC = V.rect_mesh('Q9', 2, 2, -H_RING / 2, H_RING / 2, -H_RING / 2,
                  H_RING / 2)
A_RING = H_RING * H_RING
I_RING = H_RING ** 4 / 12.0


def lagr_deriv(order, i, x):
    nodes = [-1 + 2.0 * k / order for k in range(order + 1)]
    s = 0.0
    for j in range(order + 1):
        if j == i:
            continue
        pr = 1.0 / (nodes[i] - nodes[j])
        for m in range(order + 1):
            if m in (i, j):
                continue
            pr *= (x - nodes[m]) / (nodes[i] - nodes[m])
        s += pr
    return s


def tangent(coords, p, end):
    """polynomial tangent of the axis at the first (-1) or last (+1) node."""
    pts = coords[:p + 1] if end < 0 else coords[-(p + 1):]
    t = [0.0, 0.0, 0.0]
    for i in range(p + 1):
        d = lagr_deriv(p, i, float(end))
        for k in range(3):
            t[k] += d * pts[i][k]
    n = math.sqrt(sum(a * a for a in t))
    return [a / n for a in t]


def ring_case(name, nel, btype, shear, nu=NU, sol=101, couple=False,
              points=None):
    """quarter ring (radius R, in the y-z plane) clamped at the origin; the
    tip carries a unit force along y (or a unit couple about x)."""
    p = int(btype[1]) - 1
    nn = p * nel + 1
    coords = []
    for i in range(nn):
        phi = (math.pi / 2) * i / (nn - 1)
        coords.append((0.0, R_RING * math.sin(phi),
                       R_RING * (1 - math.cos(phi))))
    c = V.Case(name)
    nt, _ = V.kin_nodes_text(coords, 'LE 1')
    c.put('NODES.dat', nt)
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [p * e + a + 1 for a in range(p + 1)]
        el.append('C%s %d  %s  1  1' % (btype, e + 1,
                                         ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(sol, 12, beam=shear))
    c.put('MATERIAL.dat', V.material_text(E, nu))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', SEC.mesh_text(True))
    c.put('EXP_CONN_01.dat', SEC.conn_text())
    t0 = tangent(coords, p, -1)
    t1 = tangent(coords, p, +1)
    a3 = (1.0, 0.0, 0.0)
    a1 = (t1[1] * a3[2] - t1[2] * a3[1], t1[2] * a3[0] - t1[0] * a3[2],
          t1[0] * a3[1] - t1[1] * a3[0])
    tip = coords[-1]
    recs = [V.dplane(1, t0[0], t0[1], t0[2],
                     -sum(t0[k] * coords[0][k] for k in range(3)),
                     0.0, 0.0, 0.0)]
    if couple:
        w = SEC.consistent(lambda u, v: -u / I_RING)
    else:
        w = SEC.consistent(lambda u, v: 1.0 / A_RING)
    for i in sorted(w):
        if abs(w[i]) < 1e-14:
            continue
        x, z = SEC.nodes[i]
        pos = [tip[k] + x * a1[k] + z * a3[k] for k in range(3)]
        f = [t1[k] * w[i] for k in range(3)] if couple else \
            [0.0, w[i], 0.0]
        recs.append(V.fpoint(len(recs) + 1, pos[0], pos[1], pos[2], *f))
    if sol == 103:
        recs = recs[1:2]            # free ring: no clamp
    c.put('BC.dat', V.bc_text(recs))
    pts = points or [(0.0, R_RING, R_RING)]
    c.put('POSTPROCESSING.dat', V.post_text(pts))
    return c, t1, a1, tip


def castigliano(nu):
    g = E / (2 * (1 + nu))
    kappa = V.kappa_rect(nu)
    return (math.pi / 4) * (R_RING ** 3 / (E * I_RING) + R_RING /
                            (E * A_RING) + R_RING / (kappa * g * A_RING))


for nel, btype, tol in ((4, 'B4', 5e-3), (8, 'B3', 1e-2)):
    c, _, _, _ = ring_case('ring_nu0_%s_%d' % (btype, nel), nel, btype,
                           'MITC', nu=0.0)
    r = c.run()
    check('ring %s x %d runs' % (btype, nel), r.ok, r.log[-300:]
          if not r.ok else '')
    close('quarter ring tip deflection (nu = 0, %s x %d)' % (btype, nel),
          r.u()[1], castigliano(0.0), tol)
c, _, _, _ = ring_case('ring_nu3', 8, 'B4', 'MITC')
r = c.run()
close('quarter ring tip deflection (nu = 0.3, 8 elements)', r.u()[1],
      castigliano(NU), 3e-2)

# bending stress at the tip section (couple): sigma = M x / I
c, t1, a1, tip = ring_case('ring_couple', 8, 'B4', 'MITC', couple=True)
d = 0.1
pts = [tuple(tip[k] + d * a1[k] for k in range(3)),
       tuple(tip[k] - d * a1[k] for k in range(3))]
c.put('POSTPROCESSING.dat', V.post_text(pts))
r = c.run()
check('ring couple runs', r.ok, r.log[-300:] if not r.ok else '')
s1, s2 = r.points[0][26], r.points[1][26]
close('ring bending stress M x / I (mean of the two faces)',
      0.5 * (abs(s1) + abs(s2)), d / I_RING, 1e-2)
check('ring bending stress changes sign', s1 * s2 < 0.0,
      'sigma = %.2f, %.2f' % (s1, s2))

# free ring: six rigid-body modes, converged first frequency
freq = {}
for nel in (4, 8):
    c, _, _, _ = ring_case('ring_free_%d' % nel, nel, 'B4', 'MITC',
                           sol=103)
    r = c.run()
    check('free ring %d runs' % nel, r.ok, r.log[-300:]
          if not r.ok else '')
    freq[nel] = r.freq
check('free ring: six rigid-body modes',
      all(abs(f) < 1e-2 for f in freq[8][:6]) and freq[8][6] > 1.0,
      'first frequencies %s' % ['%.2e' % f for f in freq[8][:7]])
close('free ring: first elastic frequency converged (4 vs 8 elements)',
      freq[4][6], freq[8][6], 5e-3)

# ------------------------------------------------------------------ 4
RC, LC, TC = 300.0, 600.0, 3.0
IXS = [1, 2, 3, 3, 3, 2, 1, 1, 2]
IYS = [1, 1, 1, 2, 3, 3, 3, 2, 2]


def pinched(name, n, thick, shear='MITC', exact=False):
    """one eighth of a cylinder (axis y) pinched at the middle, rigid
    diaphragm at the end (MacNeal-Harder); P = 1 (a quarter on the model)."""
    m = 2 * n + 1
    nid = lambda i, j: i * m + j + 1
    tag = 'TE %d' % thick[1] if thick[0] == 'TE' else 'LE 1'
    lines = ['%d' % (m * m), '']
    for i in range(m):
        th = (math.pi / 2) * i / (m - 1)
        for j in range(m):
            y = (LC / 2) * j / (m - 1)
            lines.append('%d %s %s %s %s' % (
                nid(i, j), V.fmt(RC * math.sin(th)), V.fmt(y),
                V.fmt(RC * math.cos(th)), tag))
    c = V.Case(name)
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % (n * n), '']
    k = 0
    for ei in range(n):
        for ej in range(n):
            k += 1
            ids = [nid(2 * ei + IXS[a] - 1, 2 * ej + IYS[a] - 1)
                   for a in range(9)]
            el.append('S9 %d  %s  1  1' % (k, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    if exact:
        dl = ['%d' % (m * m), '']
        for i in range(m):
            th = (math.pi / 2) * i / (m - 1)
            for j in range(m):
                dl.append('%d %s 0 %s' % (nid(i, j), V.fmt(math.sin(th)),
                                          V.fmt(math.cos(th))))
        c.put('DIRECTORS.dat', '\n'.join(dl) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 1 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(101, 6, plate=shear))
    c.put('MATERIAL.dat', V.material_text(3.0e6, 0.3, 1.0))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    if thick[0] == 'TE':
        tm = V.line_mesh('B3', 1, TC)
    else:
        tm = V.line_mesh(thick[1], thick[2], TC)
    c.put('EXP_MESH_01.dat', tm.mesh_text(False))
    c.put('EXP_CONN_01.dat', tm.conn_text())
    recs = [V.dplane(1, 1, 0, 0, 0.0, 0.0, None, None),
            V.dplane(2, 0, 0, 1, 0.0, None, None, 0.0),
            V.dplane(3, 0, 1, 0, 0.0, None, 0.0, None),
            V.dplane(4, 0, 1, 0, -LC / 2, 0.0, None, 0.0)]
    if thick[0] == 'TE':
        recs.append(V.fpoint(5, 0.0, 0.0, RC, 0.0, 0.0, -0.25))
    else:
        w = tm.consistent(lambda u, v: 1.0 / TC)
        for j in sorted(w):
            if abs(w[j]) > 1e-14:
                recs.append(V.fpoint(len(recs) + 1, 0.0, 0.0,
                                     RC + tm.nodes[j][1], 0.0, 0.0,
                                     -0.25 * w[j]))
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text([(0.0, 0.0, RC)]))
    return c


REF_CYL = 1.8248e-5
res = {}
for label, thick, exact in (('TE2', ('TE', 2), False),
                            ('TE2 exact directors', ('TE', 2), True),
                            ('LE B3 x1', ('LE', 'B3', 1), True),
                            ('LE B3 x2', ('LE', 'B3', 2), True)):
    r = pinched('pcyl_' + label.replace(' ', '_'), 8, thick,
                exact=exact).run()
    check('pinched cylinder %s runs' % label, r.ok, r.log[-300:]
          if not r.ok else '')
    res[label] = abs(r.u()[2])
    check('pinched cylinder %s: radial deflection vs reference' % label,
          0.96 < res[label] / REF_CYL < 1.02,
          'ratio %.4f' % (res[label] / REF_CYL))
close('pinched cylinder: exact and averaged directors', res['TE2'],
      res['TE2 exact directors'], 1e-3)
close('pinched cylinder: layerwise (1 element) and Taylor thickness',
      res['LE B3 x1'], res['TE2'], 1e-2)
close('pinched cylinder: layerwise (2 elements) and Taylor thickness',
      res['LE B3 x2'], res['TE2'], 1e-2)

# locking: the compatible strains lock, the MITC ones do not
r = pinched('pcyl_none', 6, ('TE', 2), shear='NONE').run()
check('pinched cylinder without tying locks (MITC9 cures it)',
      abs(r.u()[2]) < 0.5 * res['TE2'], 'u = %.3e' % abs(r.u()[2]))

# ------------------------------------------------------------------ 5
# thin-walled tubes: shells meeting at (kinked) corners share the nodes
BOX_A, BOX_T, BOX_L, BOX_E, BOX_NU = 1.0, 0.02, 10.0, 1.0e9, 0.3


def box_tube(name, nw, ny, circular=False):
    """cantilever tube (axis y), square (corners shared by the walls) or
    circular, vertical tip force spread over the tip nodes."""
    nper = 8 * nw if not circular else 4 * nw
    m = 2 * ny + 1
    nid = lambda k, j: (k % nper) * m + j + 1
    pts = []
    if circular:
        for k in range(nper):
            th = 2 * math.pi * k / nper
            pts.append((0.5 * math.sin(th), 0.5 * math.cos(th)))
    else:
        sides = [((-0.5, 0.5), (0.5, 0.5)), ((0.5, 0.5), (0.5, -0.5)),
                 ((0.5, -0.5), (-0.5, -0.5)), ((-0.5, -0.5), (-0.5, 0.5))]
        for (p0, p1) in sides:
            for k in range(2 * nw):
                s = k / (2.0 * nw)
                pts.append((p0[0] + s * (p1[0] - p0[0]),
                            p0[1] + s * (p1[1] - p0[1])))
    coords = []
    for k in range(nper):
        for j in range(m):
            coords.append((pts[k][0], BOX_L * j / (m - 1), pts[k][1]))
    c = V.Case(name)
    nt, _ = V.kin_nodes_text(coords, 'TE 2')
    c.put('NODES.dat', nt)
    el = []
    for ei in range(nper // 2):
        for ej in range(ny):
            ids = [nid(2 * ei + IXS[a] - 1, 2 * ej + IYS[a] - 1)
                   for a in range(9)]
            el.append('S9 %d  %s  1  1' % (len(el) + 1,
                                           ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '%d\n\n' % len(el) + '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 1 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(101, 6, plate='MITC'))
    c.put('MATERIAL.dat', V.material_text(BOX_E, BOX_NU, 1.0))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    tm = V.line_mesh('B3', 1, BOX_T)
    c.put('EXP_MESH_01.dat', tm.mesh_text(False))
    c.put('EXP_CONN_01.dat', tm.conn_text())
    recs = [V.dplane(1, 0, 1, 0, 0.0, 0.0, 0.0, 0.0)]
    # the shear is carried by the walls: the load acts on their tip nodes
    # (circular tube: on all of them)
    sel = [k for k in range(nper)
           if circular or abs(abs(pts[k][0]) - 0.5) < 1e-9]
    for k in sel:
        x, y, z = coords[nid(k, m - 1) - 1]
        recs.append(V.fpoint(len(recs) + 1, x, y, z, 0.0, 0.0, 1.0 / len(sel)))
    c.put('BC.dat', V.bc_text(recs))
    zc = 0.5
    xs = 0.0 if circular else 0.5
    c.put('POSTPROCESSING.dat', V.post_text([(xs, BOX_L, zc),
                                             (-xs, BOX_L, zc)]))
    return c


G_BOX = BOX_E / (2 * (1 + BOX_NU))
I_BOX = (2.0 / 3.0) * BOX_A ** 3 * BOX_T
I_CYL = math.pi * 0.5 ** 3 * BOX_T
REF_BOX = BOX_L ** 3 / (3 * BOX_E * I_BOX) + BOX_L / (
    (5.0 / 12.0) * 2 * BOX_A * BOX_T * G_BOX * 2)
REF_CYL_TUBE = BOX_L ** 3 / (3 * BOX_E * I_CYL) + BOX_L / (
    0.5 * G_BOX * math.pi * 0.5 * BOX_T * 2)
for label, circ, nw, ny, ref, lo, hi in (
        ('circular tube', True, 6, 10, REF_CYL_TUBE, 0.98, 1.02),
        ('square tube', False, 4, 12, REF_BOX, 0.97, 1.05)):
    r = box_tube('tube_' + label.split()[0], nw, ny, circ).run()
    check('%s runs' % label, r.ok, r.log[-300:] if not r.ok else '')
    u = 0.5 * (r.points[0][12] + r.points[1][12])
    check('%s: tip deflection against beam theory' % label,
          lo < u / ref < hi, 'ratio %.4f' % (u / ref))

# beam and shell joined at shared nodes with node-dependent kinematics:
# the stringer (a beam) has the Taylor order 0 at the nodes it shares
# with the skin (the thickness expansion of the skin is order 0 there)
ST_E, ST_T, ST_B, ST_L, ST_A = 1.0e9, 0.02, 1.0, 10.0, 0.05 * 0.05


def stiffened(name, ny=3):
    mx, my = 3, 2 * ny + 1
    nid = lambda i, j: i * my + j + 1
    coords, kin = [], []
    for i in range(mx):
        for j in range(my):
            coords.append((-ST_B / 2 + ST_B * i / (mx - 1),
                           ST_L * j / (my - 1), 0.0))
            kin.append('TE0' if i == mx - 1 else 'TE2')
    c = V.Case(name)
    nt, kt = V.kin_nodes_text(coords, kin)
    c.put('NODES.dat', nt)
    c.put('KINEMATICS.dat', kt)
    el = []
    for ej in range(ny):
        ids = [nid(IXS[a] - 1, 2 * ej + IYS[a] - 1) for a in range(9)]
        el.append('S9 %d  %s  1  1' % (len(el) + 1, ' '.join(map(str, ids))))
    for ej in range(ny):
        ids = [nid(2, 2 * ej + a) for a in range(3)]
        el.append('B3 %d  %s  1  2' % (len(el) + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '%d\n\n' % len(el) + '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(101, 6, beam='MITC',
                                          plate='MITC'))
    c.put('MATERIAL.dat', V.material_text(ST_E, 0.0, 1.0))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    tm = V.line_mesh('B3', 1, ST_T)
    c.put('EXP_MESH_01.dat', tm.mesh_text(False))
    c.put('EXP_CONN_01.dat', tm.conn_text())
    a = math.sqrt(ST_A)
    sec = V.rect_mesh('Q4', 1, 1, -a / 2, a / 2, -a / 2, a / 2)
    c.put('EXP_MESH_02.dat', sec.mesh_text(True))
    c.put('EXP_CONN_02.dat', sec.conn_text())
    ftot = 1.0e3
    area_p = ST_T * ST_B
    fp = ftot * area_p / (area_p + ST_A)
    recs = [V.dplane(1, 0, 1, 0, 0.0, 0.0, 0.0, 0.0)]
    for i, w in enumerate((1 / 6., 4 / 6., 1 / 6.)):
        recs.append(V.fpoint(len(recs) + 1, -ST_B / 2 + ST_B * i / 2.0,
                             ST_L, 0.0, 0.0, fp * w, 0.0))
    recs.append(V.fpoint(len(recs) + 1, ST_B / 2, ST_L, 0.0, 0.0,
                         ftot - fp, 0.0))
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text([(0.0, ST_L, 0.0)]))
    return c, ftot * ST_L / (ST_E * (area_p + ST_A))


c, ref = stiffened('stiffened_plate')
r = c.run()
check('skin with a stringer (shared nodes) runs', r.ok, r.log[-300:]
      if not r.ok else '')
close('skin + stringer: axial stiffness E (t b + A)', r.u()[1], ref, 1e-3)

if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL CURVED TESTS PASSED')
