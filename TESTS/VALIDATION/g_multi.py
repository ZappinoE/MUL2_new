"""Group: multi-dimensional models (1D/2D, 2D/3D, 1D/3D, independent
regions)."""
import math

import vlib as V
from vcheck import Group
from g_beams import L, B, H, E, NU

E1 = 70.0e9
SIG = 4.0e6                    # uniform axial stress of the junction tests
W_EXACT = 3.0 * SIG / E1       # u_y at the tip: strain sigma/E over L = 3
KIND_NONE = dict(beam='NONE', plate='NONE', solid='NONE')


def _quad_text(side):
    s = side / 2.0
    return ('4\n\n1 %s 0.0D0 %s\n2 %s 0.0D0 %s\n3 %s 0.0D0 %s\n'
            '4 %s 0.0D0 %s\n' % tuple(V.fmt(v) for v in (
                -s, -s, s, -s, s, s, -s, s)),
            '1\n\nQ4 1 1  1 2 3 4\n')


def _line_text(z0, z1):
    zm = 0.5 * (z0 + z1)
    return ('3\n\n1 0.0D0 0.0D0 %s\n2 0.0D0 0.0D0 %s\n3 0.0D0 0.0D0 %s\n'
            % (V.fmt(z0), V.fmt(zm), V.fmt(z1)),
            '1\n\nB3 1 1  1 2 3\n')


def _common(c, kin_nodes, kin_txt, elems, sections, nu=0.0):
    nn = len(kin_nodes)
    lines = ['%d' % nn, '']
    for i, (x, y, z, k) in enumerate(kin_nodes):
        lines.append('%d %s %s %s %d' % (i + 1, V.fmt(x), V.fmt(y),
                                         V.fmt(z), k))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', kin_txt)
    c.put('CONNECTIVITY.dat', '%d\n\n%s\n' % (len(elems), '\n'.join(elems)))
    c.put('VERSORS.dat', '2\n\nVERSOR 1  0 0 1\nVERSOR 2  1 0 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(101, 4, **KIND_NONE))
    c.put('MATERIAL.dat', V.material_text(E1, nu, 2700.0))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    for k, (m, cn) in enumerate(sections):
        c.put('EXP_MESH_%02d.dat' % (k + 1), m)
        c.put('EXP_CONN_%02d.dat' % (k + 1), cn)


def _kin(*toks):
    out = ['%d' % len(toks), '']
    for i, t in enumerate(toks):
        out.append('KINEMATIC %d  %s %s %s NONE NONE NONE NONE NONE NONE'
                   % (i + 1, t, t, t))
    return '\n'.join(out) + '\n'


H8_LAT = [(a, b, c) for (a, b, c) in V.H_PATTERN['H8'][1]]


def solid_block(first_node=1):
    """unit H8 block x,z in [-.5,.5], y in [0,1]; returns node list
    (x, y, z, is_top) in element order."""
    return [(-0.5 + (a - 1), float(b - 1), -0.5 + (c - 1), b == 2)
            for (a, b, c) in H8_LAT]


def junction_1d3d(tag, junction='TE0'):
    c = V.Case(tag)
    blk = solid_block()
    nodes = [(x, y, z, 2 if top else 1) for (x, y, z, top) in blk]
    tops = [i + 1 for i, n in enumerate(blk) if n[3]]
    elems = ['H8 1  %s  1  1' % ' '.join(str(i + 1) for i in range(8))]
    tip_ids = []
    for k, tid in enumerate(tops):
        x, y, z = nodes[tid - 1][:3]
        nodes.append((x, 3.0, z, 2))
        tip_ids.append(len(nodes))
        elems.append('B2 %d  %d %d  1  2' % (2 + k, tid, tip_ids[-1]))
    kin = _kin('LE', junction)
    secs = [('1\n\n1 0.0D0 0.0D0 0.0D0\n', '1\n\nS1 1 1 1\n'),
            _quad_text(0.5)]
    # the solid element uses section 1 (S1); the bars use section 2 (Q4)
    elems2 = []
    for e in elems:
        elems2.append(e)
    _common(c, nodes, kin, elems2, secs)
    recs = [V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0)]
    for tid in tip_ids:
        x, y, z = nodes[tid - 1][:3]
        recs.append(V.fpoint(len(recs) + 1, x + 0.25, 3.0, z + 0.25,
                             0.0, SIG * 0.25, 0.0))
    c.put('BC.dat', V.bc_text(recs))
    pts = [(0.0, 3.0 - 1e-6, 0.0), (0.5, 3.0 - 1e-6, 0.5),
           (0.4, 1.0 - 1e-6, 0.4), (0.0, 0.5, 0.0)]
    # the point (0, 3, 0) is not on a bar: use the axes of the bars
    pts = [(0.5, 3.0 - 1e-6, 0.5), (-0.5, 3.0 - 1e-6, -0.5),
           (0.4, 1.0 - 1e-6, 0.4), (0.0, 0.5, 0.0)]
    c.put('POSTPROCESSING.dat', V.post_text(pts))
    return c


def junction_1d2d(tag):
    c = V.Case(tag)
    pm = V.rect_mesh('Q9', 1, 1, -0.5, 0.5, 0.0, 1.0)
    nodes = [(pm.nodes[i][0], pm.nodes[i][1], 0.0, 1)
             for i in sorted(pm.nodes)]
    ring = pm.elems[0][1]
    elems = ['Q9 1  %s  2  1' % ' '.join(map(str, ring))]
    tops = [7, 8, 9]                      # y = 1 row (x = -.5, 0, .5)
    areas = [1 / 6, 4 / 6, 1 / 6]
    tip_ids = []
    for k, tid in enumerate(tops):
        x = nodes[tid - 1][0]
        nodes.append((x, 3.0, 0.0, 1))
        tip_ids.append(len(nodes))
        sec = 2 if k != 1 else 3
        elems.append('B2 %d  %d %d  1  %d' % (2 + k, tid, tip_ids[-1], sec))
    kin = _kin('TE0')
    secs = [_line_text(-0.5, 0.5), _quad_text(math.sqrt(areas[0])),
            _quad_text(math.sqrt(areas[1]))]
    _common(c, nodes, kin, elems, secs)
    recs = [V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0)]
    for k, tid in enumerate(tip_ids):
        x = nodes[tid - 1][0]
        s = math.sqrt(areas[k]) / 2.0
        recs.append(V.fpoint(len(recs) + 1, x + s, 3.0, s, 0.0,
                             SIG * areas[k], 0.0))
    c.put('BC.dat', V.bc_text(recs))
    pts = [(0.0, 3.0 - 1e-6, 0.0), (-0.5, 3.0 - 1e-6, 0.0),
           (0.2, 0.5, 0.1), (0.0, 1.0 + 1e-6 + 0.5, 0.0)]
    c.put('POSTPROCESSING.dat', V.post_text(pts[:3]))
    return c


def junction_2d3d(tag):
    c = V.Case(tag)
    blk = solid_block()
    nodes = [(x, y, z, 2 if top else 1) for (x, y, z, top) in blk]
    elems = ['H8 1  %s  1  1' % ' '.join(str(i + 1) for i in range(8))]
    top = {(round(n[0], 6), round(n[2], 6)): i + 1
           for i, n in enumerate(blk) if n[3]}
    eid = 2
    tips = []
    for zs, sec in ((0.5, 2), (-0.5, 3)):
        a = top[(-0.5, zs)]
        b = top[(0.5, zs)]
        nodes.append((-0.5, 3.0, zs, 2))
        d = len(nodes)
        nodes.append((0.5, 3.0, zs, 2))
        cc = len(nodes)
        elems.append('Q4 %d  %d %d %d %d  2  %d' % (eid, a, b, cc, d, sec))
        eid += 1
        tips += [(-0.5, zs, d), (0.5, zs, cc)]
    kin = _kin('LE', 'TE0')
    secs = [('1\n\n1 0.0D0 0.0D0 0.0D0\n', '1\n\nS1 1 1 1\n'),
            _line_text(-0.5, 0.0), _line_text(0.0, 0.5)]
    # plate at z=+0.5 covers z in [0, .5]  -> local z in [-.5, 0]
    _common(c, nodes, kin, elems, secs)
    recs = [V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0)]
    for (x, z, nid) in tips:
        recs.append(V.fpoint(len(recs) + 1, x, 3.0, z, 0.0, SIG * 0.25, 0.0))
    c.put('BC.dat', V.bc_text(recs))
    pts = [(0.4, 3.0 - 1e-6, 0.4), (-0.4, 3.0 - 1e-6, -0.4),
           (0.4, 1.0 - 1e-6, 0.4)]
    c.put('POSTPROCESSING.dat', V.post_text(pts))
    return c


# ---------------------------------------------------------- merging
def merge_cases(name, cases):
    """put several independent models in one input (separate regions)."""
    out = V.Case(name)
    node_off = elem_off = vers_off = sec_off = 0
    nodes, conns, vers, bc_recs, posts = [], [], [], [], []
    clamp_done = False
    expfiles = {}
    for c in cases:
        f = c.files
        nl = [l for l in f['NODES.dat'].splitlines()[2:] if l.strip()]
        for l in nl:
            t = l.split()
            nodes.append(' '.join([str(int(t[0]) + node_off)] + t[1:]))
        cl = [l for l in f['CONNECTIVITY.dat'].splitlines()[2:] if l.strip()]
        for l in cl:
            t = l.split()
            nn = {'B2': 2, 'B3': 3, 'B4': 4, 'Q4': 4, 'Q9': 9, 'Q16': 16,
                  'T3': 3, 'T6': 6, 'H8': 8, 'H27': 27}[t[0]]
            ids = [str(int(x) + node_off) for x in t[2:2 + nn]]
            tail = t[2 + nn:]
            tail[-2] = str(int(tail[-2]) + vers_off)
            tail[-1] = str(int(tail[-1]) + sec_off)
            conns.append(' '.join([t[0], str(int(t[1]) + elem_off)] + ids +
                                  tail))
        for l in f['VERSORS.dat'].splitlines()[2:]:
            if l.strip():
                t = l.split()
                vers.append(' '.join([t[0], str(int(t[1]) + vers_off)] +
                                     t[2:]))
        k = 1
        while 'EXP_MESH_%02d.dat' % k in f:
            expfiles[sec_off + k] = (f['EXP_MESH_%02d.dat' % k],
                                     f['EXP_CONN_%02d.dat' % k])
            k += 1
        for l in f['BC.dat'].splitlines()[2:]:
            if not l.strip():
                continue
            t = l.split()
            if t[0] == 'D-PLANE' and t[2:6] == ['0.00000000000000D+00',
                                                 '1.00000000000000D+00',
                                                 '0.00000000000000D+00',
                                                 '0.00000000000000D+00']:
                if clamp_done:
                    continue
                clamp_done = True
            bc_recs.append(l)
        for l in f['POSTPROCESSING.dat'].splitlines()[2:]:
            if l.strip():
                posts.append(l)
        node_off += len(nl)
        elem_off += len(cl)
        vers_off += len([1 for l in f['VERSORS.dat'].splitlines()[2:]
                         if l.strip()])
        sec_off += k - 1
    out.put('NODES.dat', '%d\n\n%s\n' % (len(nodes), '\n'.join(nodes)))
    out.put('CONNECTIVITY.dat', '%d\n\n%s\n' % (len(conns), '\n'.join(conns)))
    out.put('VERSORS.dat', '%d\n\n%s\n' % (len(vers), '\n'.join(vers)))
    for s, (m, cn) in sorted(expfiles.items()):
        out.put('EXP_MESH_%02d.dat' % s, m)
        out.put('EXP_CONN_%02d.dat' % s, cn)
    first = cases[0].files
    for fn in ('ANALYSIS.dat', 'MATERIAL.dat', 'LAMINATION.dat'):
        out.put(fn, first[fn])
    # renumber the BC ids and the points
    recs = []
    for i, l in enumerate(bc_recs):
        t = l.split()
        t[1] = str(i + 1)
        recs.append(' '.join(t))
    out.put('BC.dat', V.bc_text(recs))
    pts = []
    for i, l in enumerate(posts):
        t = l.split()
        t[1] = str(i + 1)
        pts.append(' '.join(t))
    out.put('POSTPROCESSING.dat', '%d\n\n%s\n' % (len(pts), '\n'.join(pts)))
    return out


def group_multi():
    g = Group('multi', 'Multi-dimensional models',
              'Beams (1D), plates (2D) and solids (3D) in the same model. '
              'The families are joined at shared structural nodes whose '
              'expansion is Taylor of order 0 (the only expansion with the '
              'same number of terms on sections of any dimension); the '
              'tests have a closed-form solution (nu = 0, uniform axial '
              'stress %.1e Pa, tip displacement 3 sigma / E).' % SIG)
    rows = []
    for tag, fn, label in (('m13', junction_1d3d, '1D/3D: four TE0 bars on an H8 block'),
                           ('m12', junction_1d2d, '1D/2D: three TE0 bars on a Q9 membrane'),
                           ('m23', junction_2d3d, '2D/3D: two Q4 membranes on an H8 block')):
        r = g.run(fn('mdim_' + tag))
        if not (r.ok and r.points):
            g.flag(label + ': runs', False, r.log[-300:])
            rows.append([label, '-', '-', '-', 'fails'])
            continue
        tip = [p[11] for p in r.points[:2]] if tag != 'm12' else \
            [r.points[0][11], r.points[1][11]]
        err_tip = max(abs(t - W_EXACT) / W_EXACT for t in tip)
        g.check(label + ': tip displacement', tip[0],
                W_EXACT * (3.0 - 1e-6) / 3.0, 1e-9,
                'closed form sigma y / E (evaluated at y = 3 - 1e-6)')
        extra = []
        if tag == 'm13' or tag == 'm23':
            ysolid = r.points[2][11]
            g.check(label + ': displacement at the solid top face',
                    ysolid, SIG * (1.0 - 1e-6) / E1, 1e-9,
                    'closed form sigma y / E')
            extra = []
        rows.append([label, r.ndof, '%.6e' % tip[0], '%.6e' % W_EXACT,
                     '%.1e' % err_tip])
    g.table('Junctions through order-0 Taylor nodes',
            ['model', 'DOF', 'tip u_y [m]', 'exact [m]', 'max rel. error'],
            rows,
            'Every model has a uniform stress state: a node shared '
            'between families transmits the translations and the other '
            'family is attached to it, so that the exact solution is '
            'reproduced to the solver precision.')
    # expected refusal when the junction node has a richer expansion
    cneg = junction_1d3d('mdim_neg', junction='TE2')
    rn = g.run(cneg)
    g.flag('a TE2 node shared by a solid and a beam is refused with an '
           'explicit message',
           (not rn.ok) and 'INCOMPATIBLE' in rn.log.upper(),
           [l for l in rn.log.splitlines() if 'ERROR' in l][:1] or
           ['no error'], 'documented limitation')
    # independent regions in one model
    bm = V.beam_case('mr_beam', V.rect_mesh('Q9', 2, 2, -.5, .5, -.5, .5),
                     'LE 1', nel=4, load=('shear', 1.0e6),
                     points=[(0.0, L - 1e-6, 0.0), (0.0, 5.0, 0.4)], ox=0.0)
    pl = V.plate_case('mr_plate', 'Q9', 6, ('LE', 'B3', 2),
                      load=('shear', 1.0e6), ox=3.0,
                      points=[(0.0, L - 1e-6, 0.0), (0.0, 5.0, 0.4)])
    so = V.solid_case('mr_solid', 'H27', 6, 2, load=('shear', 1.0e6),
                      ox=6.0, points=[(0.0, L - 1e-6, 0.0),
                                      (0.0, 5.0, 0.4)])
    singles = [g.run(x) for x in (bm, pl, so)]
    both = g.run(merge_cases('mr_all', [bm, pl, so]))
    worst = 0.0
    if both.ok and all(s.ok for s in singles):
        k = 0
        for s in singles:
            for p in s.points:
                q = both.points[k]
                k += 1
                sc = max(abs(v) for v in p[10:13])
                worst = max(worst, max(abs(a - b) for a, b in
                                       zip(p[10:13], q[10:13])) / sc)
    else:
        worst = float('nan')
    g.check('beam + plate + solid in one model == the three models alone '
            '(independent regions)', worst, 0.0, 1e-9, 'separate runs',
            mode='abs')
    g.table('Independent regions of different dimension in one model',
            ['model', 'DOF', 'tip u_z [m]'],
            [['LE beam (Q9 2x2 section, B4 x 4)', singles[0].ndof,
              '%.6e' % singles[0].points[0][12]],
             ['Q9 plate strip, LE B3 x 2', singles[1].ndof,
              '%.6e' % singles[1].points[0][12]],
             ['H27 block', singles[2].ndof,
              '%.6e' % singles[2].points[0][12]],
             ['all three in one input', both.ndof,
              '(max relative difference %.1e)' % worst]])
    g.save()
    return g

