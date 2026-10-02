"""Validation of the hierarchical Legendre expansion (HLE).

    python TESTS/HLE/hle_tests.py [path_to_MUL2_V3.exe] [work_dir]

Every check compares two runs of the program, so no external reference is
needed:

  1. HQ4 of order 1 on a 2x2 section mesh  ==  LE with Q4 elements
  2. HB2 of order 2 / 3 through the thickness  ==  LE with B3 / B4
  3. orientation of the shared side: the node numbering of one section
     element is rotated so that its local side direction is opposite to the
     one of its neighbour; the result must not change (sign (-1)**k)
  4. non-conforming orders: p = 2 | 4 keeps the displacement continuous on
     the interface and the compliance lies between the uniform p = 2 and
     p = 4 results (Ritz bounds)
  5. convergence: HQ4 p = 4 and p = 6 against the Taylor expansion TE4
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

E, NU, RHO = 70.0e9, 0.3, 2700.0
L, B, H = 1.0, 0.1, 0.1
P = 1000.0

ROOT = os.path.dirname(os.path.abspath(__file__))
EXE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    ROOT, '..', '..', 'BUILD', 'WINDOWS_IFX', 'Release', 'MUL2_V3.exe')
# runs go to the temp folder: synchronised folders (OneDrive) lock files
WORK = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    tempfile.gettempdir(), 'mul2_hle_runs')
ONEAPI = r'C:\Program Files (x86)\Intel\oneAPI'

FAILED = []


def fmt(x):
    return ('%.12E' % x).replace('E', 'D')


def write(path, name, text):
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, name), 'w', newline='\n') as f:
        f.write(text)


def common(path, sol, shear, lam_text=None, material=None):
    write(path, 'ANALYSIS.dat', '%d\n\n4 modes\n\n%s\n%s\n%s\n'
          % (sol, shear, shear, shear))
    write(path, 'MATERIAL.dat', material or
          '1 1\n\nISO-M 1  %s  %s  %s\n' % (fmt(E), NU, RHO))
    write(path, 'LAMINATION.dat', lam_text or '1\n\nLAM2 1 1 0.0 0.0\n')


# ---------------------------------------------------------------- beams
def grid_section(nx, nz):
    """nodes of an nx x nz grid of cells (ids i + (nx+1) j + 1)."""
    nodes = []
    for j in range(nz + 1):
        for i in range(nx + 1):
            nodes.append((i + (nx + 1) * j + 1, -B / 2 + B * i / nx,
                          -H / 2 + H * j / nz))
    return nodes


def cell(nx, i, j):
    n = lambda a, b: a + (nx + 1) * b + 1
    return [n(i, j), n(i + 1, j), n(i + 1, j + 1), n(i, j + 1)]


def beam_case(name, model, nodes, elements, load_node, modal=False,
              points=None, nel=5):
    """B4 beam along y. model = 'LE' or 'HLE' or ('TE', n).
    elements = list of (topology, node_ids, order)."""
    path = os.path.join(WORK, name, 'INPUT')
    nn = 3 * nel + 1
    lines = ['%d' % nn, '']
    for i in range(nn):
        y = L * i / (nn - 1)
        if model == 'LE':
            tag = 'LE 2'
        elif model == 'HLE':
            tag = 'HLE'
        else:
            tag = 'TE %d' % model[1]
        lines.append('%d  0.0D0  %s  0.0D0  %s' % (i + 1, fmt(y), tag))
    write(path, 'NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % nel, '']
    for e in range(nel):
        b = 3 * e + 1
        el.append('B4  %d  %d %d %d %d  1  1' % (e + 1, b, b + 1, b + 2, b + 3))
    write(path, 'CONNECTIVITY.dat', '\n'.join(el) + '\n')
    write(path, 'VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    common(path, 103 if modal else 101, 'MITC')
    mesh = ['%d' % len(nodes), '']
    for (i, x, z) in nodes:
        mesh.append('%d  %s  0.0D0  %s' % (i, fmt(x), fmt(z)))
    write(path, 'EXP_MESH_01.dat', '\n'.join(mesh) + '\n')
    conn = ['%d' % len(elements), '']
    for k, item in enumerate(elements):
        topo, ids, order = item[:3]
        tail = ('  %d' % order) if topo.startswith('H') else ''
        if len(item) > 3:       # optional mid-side nodes (curved sides)
            tail += '  ' + ' '.join(map(str, item[3]))
        conn.append('%s %d 1  %s%s' % (topo, k + 1, ' '.join(map(str, ids)),
                                       tail))
    write(path, 'EXP_CONN_01.dat', '\n'.join(conn) + '\n')
    xl, zl = load_node
    bc = 'D-PLANE 1  0 1 0 0   0.0 0.0 0.0\n'
    if modal:
        write(path, 'BC.dat', '1\n\n' + bc)
    else:
        write(path, 'BC.dat', '2\n\n' + bc +
              'F-POINT 2  %s %s %s  0.0 0.0 %s\n' % (
                  fmt(xl), fmt(L), fmt(zl), fmt(P)))
    # point 0: section centre of the tip, 1: top face at mid-length,
    # 2: the loaded corner (the compliance point of the Ritz checks)
    pts = points or [(0.0, L - 1e-6, 0.0), (0.0, 0.5, 0.05),
                     (B / 2, L - 1e-6, H / 2)]
    post = ['%d' % (1 + len(pts)), '', 'PARA 20 GLB 1 1 1 1 1 1 1 1 1']
    for k, p in enumerate(pts):
        post.append('PNT %d  %s %s %s' % (k + 1, fmt(p[0]), fmt(p[1]),
                                          fmt(p[2])))
    write(path, 'POSTPROCESSING.dat', '\n'.join(post) + '\n')
    return os.path.join(WORK, name)


# --------------------------------------------------------------- plates
def plate_case(name, kind, thick_nodes, thick_elements, load_z, modal=False,
               laminate=None):
    """cantilever Q9 plate strip (1 x 8), thickness expansion given by
    the (kind, nodes, elements) triple; kind = 'LE' or 'HLE'."""
    path = os.path.join(WORK, name, 'INPUT')
    nx, ny = 1, 8
    nxn, nyn = 2 * nx + 1, 2 * ny + 1
    tag = 'LE 2' if kind == 'LE' else 'HLE'
    lines = ['%d' % (nxn * nyn), '']
    k = 1
    for j in range(nyn):
        for i in range(nxn):
            lines.append('%d  %s  %s  0.0D0  %s' % (
                k, fmt(-B / 2 + B * i / (nxn - 1)), fmt(L * j / (nyn - 1)), tag))
            k += 1
    write(path, 'NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % (nx * ny), '']
    eid = 1
    for b in range(ny):
        nd = lambda ii, jj: 1 + ii + nxn * (2 * b + jj)
        ring = [nd(0, 0), nd(1, 0), nd(2, 0), nd(2, 1), nd(2, 2),
                nd(1, 2), nd(0, 2), nd(0, 1), nd(1, 1)]
        el.append('Q9 %d  %s  1  1' % (eid, ' '.join(map(str, ring))))
        eid += 1
    write(path, 'CONNECTIVITY.dat', '\n'.join(el) + '\n')
    write(path, 'VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    if laminate:
        common(path, 103 if modal else 101, 'MITC',
               lam_text='%d\n\n' % len(laminate) + '\n'.join(
                   'LAM2 %d 1 0.0 %s' % (i + 1, fmt(a))
                   for i, a in enumerate(laminate)) + '\n',
               material='1 1\n\nORT-M 1  140.0D9 10.0D9 10.0D9  0.3 0.3 0.4  '
                        '5.0D9 5.0D9 3.5D9  1600.0\n')
    else:
        common(path, 103 if modal else 101, 'MITC')
    mesh = ['%d' % len(thick_nodes), '']
    for (i, z) in thick_nodes:
        mesh.append('%d  0.0D0 0.0D0 %s' % (i, fmt(z)))
    write(path, 'EXP_MESH_01.dat', '\n'.join(mesh) + '\n')
    conn = ['%d' % len(thick_elements), '']
    for k, (topo, lam, ids, order) in enumerate(thick_elements):
        tail = ('  %d' % order) if topo.startswith('H') else ''
        conn.append('%s %d %d  %s%s' % (topo, k + 1, lam,
                                        ' '.join(map(str, ids)), tail))
    write(path, 'EXP_CONN_01.dat', '\n'.join(conn) + '\n')
    bc = 'D-PLANE 1  0 1 0 0   0.0 0.0 0.0\n'
    if modal:
        write(path, 'BC.dat', '1\n\n' + bc)
    else:
        loads = ['F-POINT %d  %s %s %s  0.0 0.0 %s' % (
            2 + i, fmt(-B / 2 + B * i / 2), fmt(L), fmt(load_z), fmt(P * w))
            for i, w in enumerate([1 / 6, 4 / 6, 1 / 6])]
        write(path, 'BC.dat', '4\n\n' + bc + '\n'.join(loads) + '\n')
    write(path, 'POSTPROCESSING.dat',
          '3\n\nPARA 20 GLB 1 1 1 1 1 1 1 1 1\nPNT 1  0.0 %s 0.02\n'
          'PNT 2  0.01 0.5 -0.03\n' % fmt(L - 1e-6))
    return os.path.join(WORK, name)


# --------------------------------------------------------------- running
def run(case_dir, extra_env=None):
    for s in ('REPORT', 'STATIC', 'DYNAMIC', 'WORK'):
        os.makedirs(os.path.join(case_dir, s), exist_ok=True)
    env = dict(os.environ)
    if extra_env:
        env.update(extra_env)
    if os.path.isdir(ONEAPI):
        env['PATH'] = os.pathsep.join([ONEAPI + r'\mkl\2025.0\bin',
                                       ONEAPI + r'\compiler\2025.0\bin',
                                       env['PATH']])
    proc = subprocess.run([os.path.abspath(EXE), 'INPUT'], cwd=case_dir,
                          env=env, capture_output=True, text=True)
    with open(os.path.join(case_dir, 'console.log'), 'w') as f:
        f.write(proc.stdout + '\n' + proc.stderr)
    if proc.returncode != 0:
        print('RUN FAILED:', case_dir)
        print((proc.stdout + proc.stderr)[-600:])
        FAILED.append('run ' + os.path.basename(case_dir))
        return None
    res = {}
    pp = os.path.join(case_dir, 'STATIC', 'POST_POINT.dat')
    if os.path.exists(pp):
        rows = []
        for line in open(pp):
            tok = line.split()
            if len(tok) >= 13:
                try:
                    rows.append([float(t.replace('D', 'E')) for t in tok])
                except ValueError:
                    pass
        res['points'] = rows
    fr = os.path.join(case_dir, 'DYNAMIC', 'FREQUENCIES.dat')
    if os.path.exists(fr):
        res['freq'] = [float(line.split(':')[1]) for line in open(fr)
                       if ':' in line]
    m = re.search(r'(\d+)\s+DOF', proc.stdout)
    res['log'] = proc.stdout
    return res


def tip(res, k=0):
    return res['points'][k][10:13]


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def rel(a, b):
    return abs(a - b) / max(abs(b), 1e-30)


def maxrel(u, v):
    scale = max(abs(x) for x in v)
    return max(abs(a - b) for a, b in zip(u, v)) / scale


def compare_points(name, ra, rb, tol):
    worst = 0.0
    for pa, pb in zip(ra['points'], rb['points']):
        worst = max(worst, maxrel(pa[10:13], pb[10:13]))
    check(name, worst < tol, 'max relative difference %.2e (tol %.0e)'
          % (worst, tol))


def compare_freq(name, ra, rb, tol):
    worst = max(rel(a, b) for a, b in zip(ra['freq'], rb['freq']))
    check(name, worst < tol, 'max relative difference %.2e (tol %.0e)'
          % (worst, tol))


def tube_section(ri, ro, n_arc=4):
    """annulus made of n_arc curved quadrilaterals (one per sector).
    Returns nodes, elements with the mid-side nodes of the two arcs."""
    import math
    nodes = []
    ids = {}

    def node(key, x, z):
        if key not in ids:
            ids[key] = len(ids) + 1
            nodes.append((ids[key], x, z))
        return ids[key]

    elems = []
    for k in range(n_arc):
        a0 = 2 * math.pi * k / n_arc
        a1 = 2 * math.pi * (k + 1) / n_arc
        am = 0.5 * (a0 + a1)
        kn = (k + 1) % n_arc
        v1 = node(('i', k), ri * math.cos(a0), ri * math.sin(a0))
        v2 = node(('o', k), ro * math.cos(a0), ro * math.sin(a0))
        v3 = node(('o', kn), ro * math.cos(a1), ro * math.sin(a1))
        v4 = node(('i', kn), ri * math.cos(a1), ri * math.sin(a1))
        mo = node(('om', k), ro * math.cos(am), ro * math.sin(am))
        mi = node(('im', k), ri * math.cos(am), ri * math.sin(am))
        elems.append((v1, v2, v3, v4, [0, mo, 0, mi]))
    return nodes, elems


def vtk_points(path):
    pts = []
    with open(path) as f:
        lines = f.read().split('\n')
    for i, line in enumerate(lines):
        if line.startswith('POINTS'):
            n = int(line.split()[1])
            for row in lines[i + 1:i + 1 + n]:
                tok = row.split()
                if len(tok) >= 3:
                    pts.append([float(t) for t in tok[:3]])
            break
    return pts


def main():
    if os.path.isdir(WORK):
        shutil.rmtree(WORK, ignore_errors=True)
    corner = (B / 2, H / 2)

    # 1. HQ4 p = 1 == LE Q4 ------------------------------------------------
    nodes = grid_section(2, 2)
    cells = [cell(2, i, j) for j in range(2) for i in range(2)]
    for modal in (False, True):
        tag = 'modal' if modal else 'static'
        le = run(beam_case('q4_%s' % tag, 'LE', nodes,
                           [('Q4', c, 0) for c in cells], corner, modal))
        hq = run(beam_case('hq1_%s' % tag, 'HLE', nodes,
                           [('HQ4', c, 1) for c in cells], corner, modal))
        if le and hq:
            if modal:
                compare_freq('HQ4 p=1 == Q4 (modal)', hq, le, 1e-8)
            else:
                compare_points('HQ4 p=1 == Q4 (static)', hq, le, 1e-8)

    # 2. HB through the thickness == LE B3 / B4 ---------------------------
    z2 = [(1, -H / 2), (2, 0.0), (3, H / 2)]
    zh = [(1, -H / 2), (2, H / 2)]
    for modal in (False, True):
        tag = 'modal' if modal else 'static'
        le3 = run(plate_case('plate_b3_%s' % tag, 'LE', z2,
                             [('B3', 1, [1, 2, 3], 0)], H / 2, modal))
        hb2 = run(plate_case('plate_hb2_%s' % tag, 'HLE', zh,
                             [('HB2', 1, [1, 2], 2)], H / 2, modal))
        z3 = [(1, -H / 2), (2, -H / 6), (3, H / 6), (4, H / 2)]
        le4 = run(plate_case('plate_b4_%s' % tag, 'LE', z3,
                             [('B4', 1, [1, 2, 3, 4], 0)], H / 2, modal))
        hb3 = run(plate_case('plate_hb3_%s' % tag, 'HLE', zh,
                             [('HB2', 1, [1, 2], 3)], H / 2, modal))
        for a, b, lab in ((hb2, le3, 'HB p=2 == B3'), (hb3, le4, 'HB p=3 == B4')):
            if a and b:
                if modal:
                    compare_freq(lab + ' (modal)', a, b, 1e-7)
                else:
                    compare_points(lab + ' (static)', a, b, 1e-7)
    # laminate: three plies, HB p=2 per ply == three B3 elements
    zl = [(1, -H / 2), (2, -H / 6), (3, H / 6), (4, H / 2)]
    zl3 = []
    for k in range(3):
        zl3.append((2 * k + 1, -H / 2 + H * k / 3))
        zl3.append((2 * k + 2, -H / 2 + H * (k + 0.5) / 3))
    zl3.append((7, H / 2))
    le_l = run(plate_case('lam_b3_static', 'LE', zl3,
                          [('B3', k + 1, [2 * k + 1, 2 * k + 2, 2 * k + 3], 0)
                           for k in range(3)], H / 2, False,
                          laminate=(0, 90, 0)))
    hb_l = run(plate_case('lam_hb2_static', 'HLE', zl,
                          [('HB2', k + 1, [k + 1, k + 2], 2)
                           for k in range(3)], H / 2, False,
                          laminate=(0, 90, 0)))
    if le_l and hb_l:
        compare_points('laminate HB p=2 per ply == B3 per ply', hb_l, le_l,
                       1e-7)

    # 3. orientation of the shared side -----------------------------------
    two = grid_section(2, 1)
    left = [1, 2, 5, 4]
    right = [2, 3, 6, 5]
    right_rot = right[2:] + right[:2]    # rotated by two: reversed side
    cont_points = [(-1e-9, 0.5, 0.013), (1e-9, 0.5, 0.013),
                   (-1e-9, 0.5, -0.031), (1e-9, 0.5, -0.031),
                   (0.0, L - 1e-6, 0.0), (B / 2, L - 1e-6, H / 2)]
    loadn = corner
    runs = {}
    for label, orders, rotated in (('a43', (4, 3), False), ('b43', (4, 3), True),
                                   ('a42', (4, 2), False), ('b42', (4, 2), True),
                                   ('u2', (2, 2), False), ('u4', (4, 4), False)):
        elems = [('HQ4', left, orders[0]),
                 ('HQ4', right_rot if rotated else right, orders[1])]
        runs[label] = run(beam_case('two_%s' % label, 'HLE', two, elems,
                                    loadn, False, cont_points))
    if runs['a43'] and runs['b43']:
        compare_points('reversed shared side, p=4|3', runs['b43'],
                       runs['a43'], 1e-9)
    if runs['a42'] and runs['b42']:
        compare_points('reversed shared side, p=4|2', runs['b42'],
                       runs['a42'], 1e-9)

    # separable fast kernel == point-by-point reference kernel
    for label in ('a43',):
        ref = run(beam_case('two_%s_general' % label, 'HLE', two,
                            [('HQ4', left, 4), ('HQ4', right, 3)], loadn,
                            False, cont_points),
                  {'MUL2_GENERAL_KERNEL': '1'})
        if ref and runs[label]:
            compare_points('fast kernel == reference kernel', runs[label],
                           ref, 1e-9)

    # 4. non-conforming orders ---------------------------------------------
    for label in ('a43', 'b43', 'a42', 'b42'):
        r = runs[label]
        if not r:
            continue
        pts = r['points']
        worst = max(maxrel(pts[0][10:13], pts[1][10:13]),
                    maxrel(pts[2][10:13], pts[3][10:13]))
        check('C0 continuity on the interface (%s)' % label, worst < 1e-6,
              'jump %.2e' % worst)
    if runs['u2'] and runs['u4'] and runs['a42'] and runs['a43']:
        w = {k: tip(runs[k], 5)[2] for k in ('u2', 'a42', 'a43', 'u4')}
        # the spaces are nested, so the compliance can only grow
        ok = w['u2'] <= w['a42'] <= w['a43'] <= w['u4']
        check('Ritz bounds: p2 <= (4|2) <= (4|3) <= p4 (compliance)', ok,
              'w = %s' % {k: '%.6e' % v for k, v in w.items()})

    # 5. convergence against Taylor -----------------------------------------
    one = grid_section(1, 1)
    te = run(beam_case('te4', ('TE', 4), one, [('Q4', [1, 2, 4, 3], 0)],
                       corner, False))
    te6 = run(beam_case('te6', ('TE', 6), one, [('Q4', [1, 2, 4, 3], 0)],
                        corner, False))
    res = {}
    for p in (1, 2, 3, 4, 6, 8):
        res[p] = run(beam_case('hq_p%d' % p, 'HLE', one,
                               [('HQ4', [1, 2, 4, 3], p)], corner, False))
    if te and te6 and all(res.values()):
        wte4 = tip(te)[2]
        wte6 = tip(te6)[2]
        line = '  '.join('p=%d: %.6e' % (p, tip(res[p])[2]) for p in res)
        print('      tip w:', line, ' TE4: %.6e TE6: %.6e' % (wte4, wte6))
        check('HQ4 p=4 near TE4', rel(tip(res[4])[2], wte4) < 5e-3,
              'rel %.2e' % rel(tip(res[4])[2], wte4))
        check('HQ4 p=6 near TE6', rel(tip(res[6])[2], wte6) < 5e-3,
              'rel %.2e' % rel(tip(res[6])[2], wte6))
        mono = all(tip(res[a], 2)[2] >= tip(res[b], 2)[2] * (1 - 1e-9)
                   for a, b in ((2, 1), (3, 2), (4, 3), (6, 4), (8, 6)))
        check('p-refinement is monotone (Ritz, loaded corner)', mono, '')

    # 6. curved sections: blending-function map ---------------------------
    import math
    ri, ro = 0.04, 0.05
    area = math.pi * (ro ** 2 - ri ** 2)
    inertia = math.pi / 4 * (ro ** 4 - ri ** 4)
    f_eb = (1.8751040687 ** 2 / (2 * math.pi)) * math.sqrt(
        E * inertia / (RHO * area * L ** 4))
    tnodes, telems = tube_section(ri, ro)
    freqs = {}
    for p in (2, 3, 4, 6):
        els = [('HQ4', [a, b, c, d], p, mids)
               for (a, b, c, d, mids) in telems]
        r = run(beam_case('tube_p%d_modal' % p, 'HLE', tnodes, els,
                          (ro, 0.0), True, nel=5))
        if r:
            freqs[p] = r['freq'][0]
    if freqs:
        print('      tube f1 [Hz]:', '  '.join(
            'p=%d: %.3f' % (p, f) for p, f in freqs.items()),
              ' Euler-Bernoulli: %.3f' % f_eb)
        best = freqs[max(freqs)]
        # Timoshenko/ovalisation lower the exact value by about 1 %
        check('tube f1 within 2 % of Euler-Bernoulli',
              abs(best - f_eb) / f_eb < 0.02,
              'rel %.2e' % ((best - f_eb) / f_eb))
        check('tube f1 converged in p (p=4 vs p=6)',
              abs(freqs[4] - freqs[6]) / freqs[6] < 2e-3,
              'rel %.2e' % (abs(freqs[4] - freqs[6]) / freqs[6]))
    els = [('HQ4', [a, b, c, d], 3, mids) for (a, b, c, d, mids) in telems]
    rs = run(beam_case('tube_p3_static', 'HLE', tnodes, els, (ro, 0.0),
                       False, [(ro, 0.5, 0.0), (0.0, L - 1e-6, ro)]))
    if rs:
        pts = vtk_points(os.path.join(WORK, 'tube_p3_static', 'STATIC',
                                      'RESULTS_PARA_01.vtk'))
        radii = [math.hypot(p[0], p[2]) for p in pts]
        if radii:
            # deformations are ~1e-4 m: undeformed shape within the ring
            print('      VTK radii: min %.6f max %.6f (Ri %.3f Ro %.3f)'
                  % (min(radii), max(radii), ri, ro))
            check('VTK points follow the circular boundary',
                  min(radii) > ri - 2e-4 and max(radii) < ro + 2e-4, '')
    # a collinear third point is a straight side: results do not change
    straight = run(beam_case('straight_plain', 'HLE', one,
                             [('HQ4', [1, 2, 4, 3], 3)], corner, False))
    if straight:
        n_one = one + [(5, 0.0, -H / 2)]
        mid = run(beam_case('straight_mid', 'HLE', n_one,
                            [('HQ4', [1, 2, 4, 3], 3, [5, 0, 0, 0])],
                            corner, False))
        if mid:
            compare_points('collinear mid node == straight side', mid,
                           straight, 1e-12)

    print('\n%d check(s) failed' % len(FAILED) if FAILED else '\nall HLE checks passed')
    sys.exit(1 if FAILED else 0)


if __name__ == '__main__':
    main()
