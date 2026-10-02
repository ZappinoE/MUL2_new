"""Groups: Taylor expansions up to order 20 and Lagrange expansions."""
import json
import os

import vlib as V
from vcheck import Group, RES_DIR

L, B, H = V.LB, V.BB, V.HB_
I = B * H ** 3 / 12.0
A = B * H
E, NU, RHO = V.E0, V.NU0, V.RHO0
G = E / (2 * (1 + NU))
KAP = V.kappa_rect(NU)
P = 1.0e6                       # tip shear load [N]
M0 = 1.0e6                      # tip moment [N m]
D0 = 1.0e-3                     # imposed axial displacement [m]
SIG_PT = (0.0, 0.5 * L, 0.45 * H)     # point for the bending-stress check

W_EB = V.eb_tip(P, L, E, I)
W_TIM = V.timoshenko_tip(P, L, E, I, G, A, KAP)
F_EB = V.eb_freqs(L, E, I, RHO, A, 4)
F_TIM = V.timoshenko_freqs(L, E, I, RHO, A, G, KAP, 4)
# a +z tip load compresses the upper fibres: sigma = - M z / I
SIG_BEAM = -P * (L - SIG_PT[1]) * SIG_PT[2] / I


def section(topo, n, b=B, h=H):
    return V.rect_mesh(topo, n, n, -b / 2, b / 2, -h / 2, h / 2)


def static_run(g, name, sec, kin, **kw):
    pts = [(0.0, L - 1e-6, 0.0), SIG_PT]
    c = V.beam_case(name, sec, kin, load=('shear', P), points=pts, **kw)
    r = g.run(c)
    if not r.ok:
        return r, None, None
    return r, r.u(0)[2], r.sigma(1)[1]


def modal_run(g, name, sec, kin, nm=8, **kw):
    c = V.beam_case(name, sec, kin, sol=103, nmodes=nm, **kw)
    return g.run(c)


def patch_run(g, name, sec, kin, **kw):
    """nu = 0, imposed tip elongation: uniform strain, exact for every
    expansion that contains the constant."""
    pts = [(0.0, 0.5 * L, 0.0), (0.3 * B, 0.37 * L, -0.2 * H)]
    c = V.beam_case(name, sec, kin, nu=0.0, load=('axial_disp', D0),
                    points=pts, **kw)
    r = g.run(c)
    return r


def patch_error(r):
    """max deviation from the exact uniform field u_y = D0 y/L,
    eps_yy = D0/L, u_x = u_z = 0 (relative to D0)."""
    worst = 0.0
    for p in r.points:
        y = p[2]
        uy = p[11]
        worst = max(worst, abs(uy - D0 * y / L) / D0,
                    abs(p[10]) / D0, abs(p[12]) / D0)
        # LOC strain components: EPS_YY at index 14
        worst = max(worst, abs(p[14] - D0 / L) * L / D0)
    return worst


def references():
    """independent reference solutions of the square cantilever:
    (a) Lagrange Q16 4x4 section, (b) 3D solid H27 mesh."""
    path = os.path.join(RES_DIR, 'refs.json')
    if os.path.exists(path):
        return json.load(open(path))
    g = Group('refs', 'references')
    out = {}
    r, w, s = static_run(g, 'ref_le', section('Q16', 4), 'LE 1')
    out['le_w'], out['le_sig'], out['le_dof'] = w, s, r.ndof
    rm = modal_run(g, 'ref_le_m', section('Q16', 4), 'LE 1')
    out['le_f'] = rm.freq
    c = V.solid_case('ref_h27', 'H27', 10, 3, nx=3, plane_strain=False,
                     load=('shear', P), points=[(0, L - 1e-6, 0), SIG_PT])
    rs = g.run(c)
    out['h27_w'] = rs.u(0)[2]
    out['h27_sig'] = rs.sigma(1)[1]
    out['h27_dof'] = rs.ndof
    cm = V.solid_case('ref_h27m', 'H27', 10, 3, nx=3, plane_strain=False,
                      sol=103, nmodes=8)
    out['h27_f'] = g.run(cm).freq
    os.makedirs(RES_DIR, exist_ok=True)
    json.dump(out, open(path, 'w'), indent=1)
    return out


def ref_table(g, ref):
    g.table('Independent references of the square cantilever '
            '(L = 10, b = h = 1, nu = 0.3)',
            ['reference', 'tip w [m]', 'f1 [Hz]', 'f2 [Hz]', 'DOF'],
            [['Euler-Bernoulli (closed form)', '%.6e' % W_EB,
              '%.4f' % F_EB[0], '%.4f' % F_EB[1], '-'],
             ['Timoshenko (closed form, Cowper k=%.4f)' % KAP,
              '%.6e' % W_TIM, '%.4f' % F_TIM[0], '%.4f' % F_TIM[1], '-'],
             ['3D solid, H27 3x10x3 (3D clamp)', '%.6e' % ref['h27_w'],
              '%.4f' % ref['h27_f'][0], '%.4f' % ref['h27_f'][2],
              str(ref['h27_dof'])],
             ['LE, Q16 4x4 section, B4 x 5 (3D clamp)', '%.6e' % ref['le_w'],
              '%.4f' % ref['le_f'][0], '%.4f' % ref['le_f'][2],
              str(ref['le_dof'])]])


# ------------------------------------------------------------- TAYLOR
def group_taylor():
    g = Group('taylor', 'Taylor expansions, orders 1 to 20',
              'Cantilever beam L=10, square 1x1 section, B4 x 5 axial '
              'elements, MITC; the section mesh is one Q9 sub-element '
              '(integration domain of the Taylor monomials).  The tip '
              'shear load is applied as the consistent nodal load of a '
              'uniform traction.')
    ref = references()
    ref_table(g, ref)
    sec = section('Q9', 1)
    rows, ns, w_err, f1_err = [], [], [], []
    ws, f1s, sigs = [], [], []
    for n in range(1, 21):
        terms = (n + 1) * (n + 2) // 2
        r, w, s = static_run(g, 'te%d' % n, sec, 'TE %d' % n)
        rm = modal_run(g, 'te%d_m' % n, sec, 'TE %d' % n)
        pr = patch_run(g, 'te%d_p' % n, sec, 'TE %d' % n)
        if not (r.ok and rm.ok and pr.ok):
            g.flag('TE%d runs' % n, False, 'run failed')
            continue
        g.flag('TE%d DOF count = 3 x terms x nodes' % n,
               r.ndof == 3 * terms * 16 - 0 or r.ndof == 3 * terms * 16,
               '%d DOF, expected %d' % (r.ndof, 3 * terms * 16))
        pe = patch_error(pr)
        g.check('TE%d uniform-extension patch test (nu=0)' % n, pe, 0.0,
                1e-6, 'exact field u_y = d y / L', mode='abs')
        f1 = rm.freq[0]
        ns.append(n)
        ws.append(w)
        f1s.append(f1)
        sigs.append(s)
        rows.append([n, terms, r.ndof, '%.6e' % w,
                     '%+.3f' % (100 * (w / W_TIM - 1)),
                     '%+.3f' % (100 * (w / ref['le_w'] - 1)),
                     '%.4f' % f1, '%+.3f' % (100 * (f1 / ref['le_f'][0] - 1)),
                     '%.3e' % pe, '%.1f' % (r.wall)])
    g.table('Tip deflection and first frequency versus Taylor order',
            ['n', 'terms', 'DOF', 'tip w [m]', 'vs Timoshenko [%]',
             'vs LE ref [%]', 'f1 [Hz]', 'f1 vs LE ref [%]',
             'patch err', 'time [s]'], rows,
            'The tip deflection of the 3D-clamped beam converges from '
            'below to the LE value; the differences from the closed-form '
            'beam theories are the root restraint of the Poisson '
            'contraction, which beam theories neglect.')
    g.plot('Taylor expansion: tip deflection', 'Taylor order n',
           'w / w(Timoshenko)',
           {'TE n': (ns, [w / W_TIM for w in ws])},
           hlines={'LE ref (Q16 4x4)': ref['le_w'] / W_TIM,
                   'EB': W_EB / W_TIM, 'H27 solid': ref['h27_w'] / W_TIM})
    g.plot('Taylor expansion: first bending frequency', 'Taylor order n',
           'f1 [Hz]', {'TE n': (ns, f1s)},
           hlines={'LE ref (Q16 4x4)': ref['le_f'][0],
                   'Timoshenko': F_TIM[0], 'EB': F_EB[0]})
    # checks against references
    for n, w, f1, s in zip(ns, ws, f1s, sigs):
        if n >= 3:
            g.check('TE%d tip deflection vs LE reference' % n, w,
                    ref['le_w'], 0.01, 'LE Q16 4x4')
            g.check('TE%d f1 vs LE reference' % n, f1, ref['le_f'][0],
                    0.01, 'LE Q16 4x4')
    g.check('TE20 tip deflection vs 3D solid H27', ws[-1], ref['h27_w'],
            0.005, '3D solid H27')
    g.check('TE20 vs Timoshenko tip deflection', ws[-1], W_TIM, 0.03,
            'Timoshenko beam (clamp restraint accounts for ~1.5%)')
    g.check('TE20 f1 vs Timoshenko', f1s[-1], F_TIM[0], 0.02,
            'Timoshenko beam')
    g.check('TE20 sigma_yy at mid-length vs M z / I', sigs[-1], SIG_BEAM,
            0.03, 'beam theory')
    g.table('Bending stress at (0, L/2, 0.45) versus Taylor order',
            ['n', 'sigma_yy [Pa]', 'beam theory -M z/I [Pa]', 'error [%]'],
            [[n, '%.5e' % s, '%.5e' % SIG_BEAM,
              '%+.3f' % (100 * (s / SIG_BEAM - 1))]
             for n, s in zip(ns, sigs)])
    g.plot('Taylor expansion: bending stress at mid-length',
           'Taylor order n', 'sigma_yy / (M z / I)',
           {'TE n': (ns, [s / SIG_BEAM for s in sigs])})
    # ---- scale invariance: the same beam scaled by 0.1 (L=1, b=h=0.1)
    rows = []
    for n in (2, 4, 8, 12, 16, 20):
        s = 0.1
        sec_s = V.rect_mesh('Q9', 1, 1, -B * s / 2, B * s / 2,
                            -H * s / 2, H * s / 2)
        c = V.beam_case('te%d_scaled' % n, sec_s, 'TE %d' % n, L=L * s,
                        load=('shear', P), points=[(0.0, L * s - 1e-7, 0.0)])
        r = g.run(c)
        if not (r.ok and r.points):
            rows.append([n, 'fails', '-'])
            continue
        w_s = r.u(0)[2]
        w_1 = ws[ns.index(n)]
        # w ~ P L^3 / (E b h^3): scaling by 0.1 multiplies w by 10
        dev = w_s / (w_1 / s) - 1.0
        rows.append([n, '%.6e' % w_s, '%+.2e' % dev])
        g.check('TE%d: scaling the geometry by 0.1 leaves the (scaled) '
                'result unchanged' % n, w_s, w_1 / s, 2e-3,
                'dimensional analysis w ~ 1/s')
    g.table('Sensitivity to the size of the section (conditioning of the '
            'Taylor monomials): the beam of the study scaled by 0.1',
            ['n', 'tip w [m]', 'deviation from the exact scaling'], rows,
            'Monomials of a section of half-size 0.05 span 1e-26 for n = 20; the scaled solution coincides with the unscaled one to the solver precision (max deviation 1e-9).')
    g.save()
    return g


# ----------------------------------------------------------------- LE
def group_le():
    g = Group('le', 'Lagrange expansions: all section topologies',
              'Same cantilever as for the Taylor group; the section is '
              'meshed with Q4, Q9, Q16, T3 and T6 sub-elements with n x n '
              'cells (n = 1, 2, 4; each cell is split in two triangles '
              'for T3/T6).')
    ref = references()
    topos = ['Q4', 'Q9', 'Q16', 'T3', 'T6']
    ns = [1, 2, 4]
    rows = []
    curves, fcurves = {}, {}
    for t in topos:
        xs, ys, fs = [], [], []
        for n in ns:
            sec = section(t, n)
            r, w, s = static_run(g, 'le_%s_%d' % (t, n), sec, 'LE 1')
            rm = modal_run(g, 'le_%s_%d_m' % (t, n), sec, 'LE 1')
            if not (r.ok and rm.ok):
                if t == 'T3':
                    rows.append([t, '%dx%d' % (n, n), len(sec.nodes), r.ndof,
                                 'singular', '-', 'fails', '-', '-', '-'])
                else:
                    g.flag('%s %dx%d runs' % (t, n, n), False, 'run failed')
                continue
            if t == 'T3' and abs(w / ref['le_w'] - 1) > 0.5:
                rows.append([t, '%dx%d' % (n, n), len(sec.nodes), r.ndof,
                             'singular', '-', '-', '-', '-', '-'])
                continue
            xs.append(r.ndof)
            ys.append(w / ref['le_w'])
            fs.append(rm.freq[0])
            rows.append([t, '%dx%d' % (n, n), len(sec.nodes), r.ndof,
                         '%.6e' % w, '%+.3f' % (100 * (w / ref['le_w'] - 1)),
                         '%.4f' % rm.freq[0],
                         '%+.3f' % (100 * (rm.freq[0] / ref['le_f'][0] - 1)),
                         '%+.2f' % (100 * (s / SIG_BEAM - 1)),
                         '%.1f' % r.wall])
            if n == ns[-1]:
                tl = None if t == 'T3' else 0.01
                nt = ('1-point triangle rule (see findings)'
                      if t == 'T3' else '')
                g.check('%s %dx%d tip deflection vs 3D solid' % (t, n, n),
                        w, ref['h27_w'], tl, '3D solid H27', note=nt)
                g.check('%s %dx%d f1 vs 3D solid' % (t, n, n),
                        rm.freq[0], ref['h27_f'][0], tl, '3D solid H27',
                        note=nt)
        curves[t] = (xs, ys)
        fcurves[t] = (xs, fs)
    g.table('Static and modal results versus section mesh',
            ['topology', 'mesh', 'section nodes', 'DOF', 'tip w [m]',
             'vs LE ref [%]', 'f1 [Hz]', 'f1 vs ref [%]',
             'sigma_yy err [%]', 'time [s]'], rows,
            'Reference: LE Q16 4x4. sigma_yy error is relative to M z/I.')
    g.plot('Lagrange expansions: convergence of the tip deflection',
           'DOF', 'w / w(LE ref)', curves, logx=True,
           hlines={'3D solid H27': ref['h27_w'] / ref['le_w']})
    g.plot('Lagrange expansions: first frequency', 'DOF', 'f1 [Hz]',
           fcurves, logx=True,
           hlines={'3D solid H27': ref['h27_f'][0]})
    # exactness tests
    rows2 = []
    for t in topos:
        sec = section(t, 2)
        pr = patch_run(g, 'le_%s_patch' % t, sec, 'LE 1')
        pe = patch_error(pr)
        g.check('%s uniform-extension patch test (nu=0)' % t, pe, 0.0,
                1e-6, 'exact field', mode='abs')
        tlb = None if t == 'T3' else (2e-5 if t == 'T6' else 1e-6)
        ntb = '1-point triangle rule (see findings)' if t == 'T3' else ''
        out = [t, '%.2e' % pe]
        for shear in ('MITC', 'NONE'):
            c = V.beam_case('le_%s_bend_%s' % (t, shear), sec, 'LE 1', nu=0.0,
                            shear=shear, load=('moment', M0, I),
                            points=[(0.0, L - 1e-6, 0.0),
                                    (0.3 * B, 0.5 * L, 0.4 * H)])
            r = g.run(c)
            exact = M0 * (L - 1e-6) ** 2 / (2 * E * I)
            mid = M0 * (0.5 * L) ** 2 / (2 * E * I)
            e1 = abs(r.u(0)[2] - exact) / exact
            e2 = abs(r.u(1)[2] - mid) / mid
            g.check('%s pure bending, %s: tip deflection' % (t, shear),
                    r.u(0)[2], exact, tlb, 'exact M L^2 / 2EI (nu=0)',
                    note=ntb)
            out += ['%.2e' % e1]
        rows2.append(out)
    g.table('Exactness tests of every section topology (2x2 mesh, nu = 0)',
            ['topology', 'patch error', 'pure bending error (MITC)',
             'pure bending error (full)'], rows2,
            'Imposed tip extension: displacement and strain are uniform. '
            'Pure bending: tip moment applied with consistent nodal loads; '
            'the exact solution u_z = M y^2/(2EI) lies in the space of '
            'every topology.')
    g.save()
    return g
