"""Group: plate elements Q4 Q9 Q16 T3 T6 with TE / LE / HLE thickness."""
import json
import os

import vlib as V
from vcheck import Group, RES_DIR
from g_beams import L, B, H, E, NU, RHO, G, D0

P = 1.0e6                       # total tip load on the strip width b
Ep = E / (1.0 - NU ** 2)        # plane-strain modulus
Ih = H ** 3 / 12.0              # inertia per unit width
KP = 5.0 / 6.0                  # Reissner-Mindlin shear coefficient
q = P / B                       # load per unit width
W_EB = V.eb_tip(q, L, Ep, Ih)
W_TIM = V.timoshenko_tip(q, L, Ep, Ih, G, H, KP)
F_EB = V.eb_freqs(L, Ep, Ih, RHO, H, 4)
F_TIM = V.timoshenko_freqs(L, Ep, Ih, RHO, H, G, KP, 4)

NY = {'Q4': 16, 'Q9': 8, 'Q16': 5, 'T3': 16, 'T6': 8}
THICK = [('TE1', ('TE', 1)), ('TE2', ('TE', 2)), ('TE3', ('TE', 3)),
         ('TE4', ('TE', 4)), ('B2x4', ('LE', 'B2', 4)),
         ('B3x2', ('LE', 'B3', 2)), ('B4x1', ('LE', 'B4', 1)),
         ('HB p1', ('HB', 1, 1)), ('HB p2', ('HB', 1, 2)),
         ('HB p3', ('HB', 1, 3)), ('HB p4', ('HB', 1, 4))]


def ps_reference():
    """plane-strain 3D reference: H27 solid strip (1 x 10 x 3 elements)."""
    path = os.path.join(RES_DIR, 'refs_ps.json')
    if os.path.exists(path):
        return json.load(open(path))
    g = Group('refs_ps', 'plane strain reference')
    out = {}
    c = V.solid_case('ref_ps_h27', 'H27', 10, 3, load=('shear', P))
    r = g.run(c)
    out['w'] = r.u(0)[2]
    out['dof'] = r.ndof
    cm = V.solid_case('ref_ps_h27_m', 'H27', 10, 3, sol=103, nmodes=6)
    out['f'] = g.run(cm).freq
    os.makedirs(RES_DIR, exist_ok=True)
    json.dump(out, open(path, 'w'), indent=1)
    return out


def group_plates():
    g = Group('plates', 'Plate elements Q4, Q9, Q16, T3, T6',
              'Plane-strain cantilever strip (L=10, h=1, b=1): the plate '
              'lies in the (x,y) plane, u_x = 0 on both lateral edges, '
              'tip shear load P = 1e6 N.  Thickness expansions: Taylor '
              'TE1-4, Lagrange B2/B3/B4 and hierarchical HB of order 1-4.')
    ref = ps_reference()
    g.table('References of the plane-strain strip',
            ['reference', 'tip w [m]', 'f1 [Hz]', 'f2 [Hz]', 'DOF'],
            [['Euler-Bernoulli (E/(1-nu^2))', '%.6e' % W_EB,
              '%.4f' % F_EB[0], '%.4f' % F_EB[1], '-'],
             ['Timoshenko (k=5/6)', '%.6e' % W_TIM, '%.4f' % F_TIM[0],
              '%.4f' % F_TIM[1], '-'],
             ['3D solid H27 1x10x3, plane strain', '%.6e' % ref['w'],
              '%.4f' % ref['f'][0], '%.4f' % ref['f'][1], str(ref['dof'])]])
    stat, modl, cond = {}, {}, {}
    for topo in NY:
        for tname, th in THICK:
            c = V.plate_case('pl_%s_%s' % (topo, tname.replace(' ', '')),
                             topo, NY[topo], th, load=('shear', P))
            r = g.run(c)
            cm = V.plate_case('pl_%s_%s_m' % (topo, tname.replace(' ', '')),
                              topo, NY[topo], th, sol=103, nmodes=4)
            rm = g.run(cm)
            if r.ok and rm.ok and r.points and rm.freq:
                stat[(topo, tname)] = (r.u(0)[2], r.ndof, r.wall)
                modl[(topo, tname)] = rm.freq[0]
            else:
                stat[(topo, tname)] = None
                modl[(topo, tname)] = None
    names = [t[0] for t in THICK]
    rows, rowsf = [], []
    for topo in NY:
        row, rowf = [topo + ' (%d el.)' % NY[topo]], [topo]
        for tn in names:
            s = stat[(topo, tn)]
            f = modl[(topo, tn)]
            row.append('fail' if s is None else
                       '%+.2f' % (100 * (s[0] / ref['w'] - 1)))
            rowf.append('fail' if f is None else
                        '%+.2f' % (100 * (f / ref['f'][0] - 1)))
        rows.append(row)
        rowsf.append(rowf)
    g.table('Tip deflection: error [%] with respect to the 3D plane-strain '
            'solid, by in-plane topology (rows) and thickness expansion '
            '(columns)', ['topology'] + names, rows,
            'Q4, Q9, Q16, T3, T6 use 16, 8, 5, 16, 8 elements along the '
            'strip, so that the number of nodes along the edge is '
            'comparable.')
    g.table('First frequency: error [%] with respect to the 3D '
            'plane-strain solid', ['topology'] + names, rowsf)
    # checks
    for topo in NY:
        tol = {'Q9': 0.01, 'Q16': 0.01, 'T6': 0.01, 'Q4': 0.04,
               'T3': None}[topo]
        for tn in ('TE4', 'B4x1', 'B3x2', 'HB p4'):
            s = stat[(topo, tn)]
            f = modl[(topo, tn)]
            if s is None:
                g.flag('%s / %s runs' % (topo, tn), False, 'run failed')
                continue
            g.check('%s / %s: tip deflection vs 3D solid' % (topo, tn),
                    s[0], ref['w'], tol, '3D plane-strain solid H27',
                    note='constant-strain triangle, 1-point rule'
                    if topo == 'T3' else '')
            g.check('%s / %s: f1 vs 3D solid' % (topo, tn), f, ref['f'][0],
                    tol, '3D plane-strain solid H27')
    for tn in ('B4x1', 'TE4'):
        s = stat[('Q9', tn)]
        g.check('Q9 / %s vs Timoshenko plane-strain strip' % tn, s[0],
                W_TIM, 0.03, 'Timoshenko (clamp restraint ~1.5%)')
    g.plot('Plates: tip deflection error, Q9 in plane',
           'thickness expansion (index)', 'w / w(3D solid)',
           {topo: (list(range(1, len(names) + 1)),
                   [stat[(topo, tn)][0] / ref['w']
                    if stat[(topo, tn)] else float('nan') for tn in names])
            for topo in NY},
           note='x axis: ' + ', '.join('%d=%s' % (i + 1, n)
                                       for i, n in enumerate(names)))
    # ------------------------------------------------ exactness tests
    rows = []
    Ib = H ** 3 / 12.0
    for topo in ('Q9', 'Q16', 'T6', 'Q4', 'T3'):
        for tn, th in (('TE1', ('TE', 1)), ('B2x4', ('LE', 'B2', 4)),
                       ('B4x1', ('LE', 'B4', 1)), ('HB p1', ('HB', 1, 1))):
            cp = V.plate_case('plp_%s_%s' % (topo, tn.replace(' ', '')),
                              topo, NY[topo], th, nu=0.0,
                              load=('axial_disp', D0),
                              points=[(0.0, 5.0, 0.0), (0.2, 3.7, 0.3)])
            rp = g.run(cp)
            pe = max(abs(p[11] - D0 * p[2] / L) / D0 for p in rp.points) \
                if rp.ok else float('nan')
            out = [topo, tn, '%.2e' % pe]
            g.check('%s / %s: uniform-extension patch test' % (topo, tn),
                    pe, 0.0, 1e-6, 'exact field', mode='abs')
            for shear in ('MITC', 'NONE'):
                cb = V.plate_case('plb_%s_%s_%s' % (topo, tn.replace(' ', ''),
                                                    shear),
                                  topo, NY[topo], th, nu=0.0, shear=shear,
                                  load=('moment', 1.0e6, Ib),
                                  points=[(0.0, L - 1e-6, 0.0)])
                rb = g.run(cb)
                exact = (1.0e6 / B) * (L - 1e-6) ** 2 / (2 * E * Ib)
                if rb.ok:
                    e = abs(rb.u(0)[2] - exact) / exact
                else:
                    e = float('nan')
                out.append('%.2e' % e)
                if topo in ('Q9', 'Q16', 'T6'):
                    g.check('%s / %s pure bending (%s)' % (topo, tn, shear),
                            rb.u(0)[2] if rb.ok else float('nan'), exact,
                            2e-5 if topo == 'T6' else 1e-6,
                            'exact m L^2/(2EI) (nu=0)')
            rows.append(out)
    g.table('Exactness tests of the plate topologies (nu = 0)',
            ['topology', 'thickness', 'patch error',
             'pure bending (MITC)', 'pure bending (full)'], rows,
            'Pure bending reproduces the exact quadratic deflection only '
            'for in-plane elements that contain u_z ~ y^2 '
            '(Q9, Q16, T6); Q4 and T3 are shown for comparison.')
    g.save()
    return g
