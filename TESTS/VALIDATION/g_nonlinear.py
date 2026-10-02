"""Group: geometrically nonlinear statics (analysis 108), linear buckling
(105), thermal Green strain: load sweeps against closed forms, arc length."""
import math
import os
import re

import vlib as V
from vcheck import Group

E, NU = V.E0, V.NU0
L, B, H = V.LB, V.BB, V.HB_
EI = E * B * H ** 3 / 12.0
PTS = [(0.0, L - 1e-6, 0.0)]
RISE, P_ARC = 2.5, 1.0e9


def elastica(alpha, n=4000):
    """tip (x, y)/L of a cantilever under a dead end load P normal to the
    undeformed axis, alpha = P L^2 / EI (shooting method and RK4)."""
    def integrate(k0):
        th, k, x, y = 0.0, k0, 0.0, 0.0
        h = 1.0 / n

        def f(th_, k_):
            return k_, -alpha * math.cos(th_), math.cos(th_), math.sin(th_)
        for _ in range(n):
            a1 = f(th, k)
            a2 = f(th + 0.5 * h * a1[0], k + 0.5 * h * a1[1])
            a3 = f(th + 0.5 * h * a2[0], k + 0.5 * h * a2[1])
            a4 = f(th + h * a3[0], k + h * a3[1])
            th += h * (a1[0] + 2 * a2[0] + 2 * a3[0] + a4[0]) / 6
            k += h * (a1[1] + 2 * a2[1] + 2 * a3[1] + a4[1]) / 6
            x += h * (a1[2] + 2 * a2[2] + 2 * a3[2] + a4[2]) / 6
            y += h * (a1[3] + 2 * a2[3] + 2 * a3[3] + a4[3]) / 6
        return k, x, y
    lo, hi = 0.0, 2.0 * alpha
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if integrate(mid)[0] > 0.0:
            hi = mid
        else:
            lo = mid
    _, x, y = integrate(0.5 * (lo + hi))
    return x, y


def nl_case(case, steps, itmax=30, tol=1e-8):
    case.put('ANALYSIS.dat', V.analysis_text(108, 4))
    case.put('NL_INFO.dat', '1\n%d\n%d\n%s\n1\n' % (steps, itmax,
                                                    V.fmt(tol)))
    return case


def arch_case(name, tech, steps, lmax, ds=0.0, dsmin=0.0, dsmax=0.0,
              nel=6):
    """faceted shallow arch in the y-z plane (parabola, span L, rise
    RISE), clamped at both ends, vertical dead load at the crown."""
    sec = V.rect_mesh('Q9', 1, 1, -B / 2, B / 2, -H / 2, H / 2)
    p = 3
    nn = p * nel + 1
    coords = []
    for i in range(nn):
        e = min(i // p, nel - 1)
        s = (i - p * e) / p
        pts = []
        for k in (e, e + 1):
            y = L * k / nel
            pts.append((y, 4.0 * RISE * y * (L - y) / L ** 2))
        coords.append((0.0, pts[0][0] + s * (pts[1][0] - pts[0][0]),
                       pts[0][1] + s * (pts[1][1] - pts[0][1])))
    c = V.Case(name)
    nt, _ = V.kin_nodes_text(coords, 'LE 1')
    c.put('NODES.dat', nt)
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [p * e + a + 1 for a in range(p + 1)]
        el.append('B4 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(108, 4))
    c.put('MATERIAL.dat', V.material_text())
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', sec.mesh_text(True))
    c.put('EXP_CONN_01.dat', sec.conn_text())
    c.put('BC.dat', V.bc_text([
        V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
        V.dplane(2, 0, 1, 0, -L, 0.0, 0.0, 0.0),
        V.fpoint(3, 0.0, L / 2, RISE, 0.0, 0.0, -P_ARC)]))
    c.put('POSTPROCESSING.dat', V.post_text([(0.0, L / 2, RISE)]))
    tail = '%s %s %s %s\n' % (V.fmt(ds), V.fmt(dsmin), V.fmt(dsmax),
                              V.fmt(lmax)) if tech == 2 else ''
    c.put('NL_INFO.dat', '%d\n%d\n30\n1.0D-8\n1\n%s' % (tech, steps, tail))
    return c


def crown_path(r):
    """[(lambda, u_z)] of the crown from TIME_HISTORY.dat."""
    rows = []
    with open(os.path.join(r.case_dir, 'DYNAMIC', 'TIME_HISTORY.dat')) as f:
        head = f.readline().split()
        iz = head.index('U_Z')
        for line in f:
            tok = line.split()
            if len(tok) > iz:
                rows.append((float(tok[0].replace('D', 'E')),
                             float(tok[iz].replace('D', 'E'))))
    return rows


def first_peak(path):
    lam = [a for a, _ in path]
    for k in range(1, len(lam) - 1):
        if lam[k] > lam[k - 1] and lam[k] > lam[k + 1]:
            return k, lam[k]
    return None, None


def group_nonlinear():
    g = Group('nonlinear', 'Geometrically nonlinear analyses',
              'Cantilever beam with Q9 section (LE), B4 elements, 10 load '
              'steps with Newton iterations; shallow arch with the arc '
              'length method; H27 solid; bars with large thermal strain.')
    sec = V.rect_mesh('Q9', 2, 2, -B / 2, B / 2, -H / 2, H / 2)

    # ---- 1. small load: nonlinear = linear
    r_lin = g.run(V.beam_case('nlv_lin', sec, 'LE 1', load=('shear', 1.0e3),
                              points=PTS))
    r = g.run(nl_case(V.beam_case('nlv_small', sec, 'LE 1',
                                  load=('shear', 1.0e3), points=PTS), 2))
    g.flag('small load runs', r.ok, r.log[-200:] if not r.ok else '')
    if r.ok and r_lin.ok:
        g.check('small load: nonlinear tip deflection = linear', r.u()[2],
                r_lin.u()[2], 1e-4, 'analysis 101')

    # ---- 2. elastica: load sweep alpha = P L^2 / EI
    alphas = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]
    fe_w, fe_u, ex_w, ex_u, lin_w, rows = [], [], [], [], [], []
    for a in alphas:
        r = g.run(nl_case(V.beam_case('nlv_el_%g' % a, sec, 'LE 1',
                                      load=('shear', a * EI / L ** 2),
                                      points=PTS), 10))
        xe, ye = elastica(a)
        ok = r.ok
        w = r.u()[2] / L if ok else float('nan')
        u = -r.u()[1] / L if ok else float('nan')
        fe_w.append(w)
        fe_u.append(u)
        ex_w.append(ye)
        ex_u.append(1.0 - xe)
        lin_w.append(a / 3.0)
        iters = re.findall(r'CONVERGED IN (\d+) ITERATIONS', r.log)
        itmax = max([int(i) for i in iters] or [0])
        rows.append(['%g' % a, '%.5f' % w, '%.5f' % ye,
                     '%.2f %%' % (100 * (w - ye) / ye),
                     '%.5f' % u, '%.5f' % (1.0 - xe), str(itmax)])
        g.check('elastica PL^2/EI = %g: tip deflection w/L' % a, w, ye,
                3e-2, 'shooting + RK4 solution of the elastica')
        g.check('elastica PL^2/EI = %g: tip shortening u/L' % a, u,
                1.0 - xe, 5e-2, 'shooting + RK4 solution of the elastica')
        g.flag('elastica %g: Newton iterations per step <= 8' % a,
               itmax <= 8, 'maximum %d' % itmax)
    g.table('Elastica of a cantilever with a dead end load: tip '
            'deflection w/L and shortening u/L',
            ['PL²/EI', 'w/L (FE)', 'w/L (exact)', 'error', 'u/L (FE)',
             'u/L (exact)', 'Newton it.'], rows,
            'The linear beam theory gives w/L = PL²/(3EI) (last curve of '
            'the figure).')
    g.plot('Large deflection of a cantilever (analysis 108)',
           'PL²/EI', 'tip displacement / L',
           {'w/L FE': (alphas, fe_w), 'u/L FE': (alphas, fe_u),
            'w/L exact': (alphas, ex_w), 'u/L exact': (alphas, ex_u),
            'w/L linear theory': (alphas, lin_w)})

    # ---- 3. beam-column with P-delta
    p_cr = math.pi ** 2 * EI / (4.0 * L ** 2)
    ratios = [0.2, 0.4, 0.6, 0.8]
    fe, ex = [], []
    hlat = 1.0e-3 * 0.5 * p_cr
    for q in ratios:
        pax = q * p_cr
        ca = V.beam_case('nlv_col_%g' % q, sec, 'LE 1',
                         load=('axial_force', -pax), points=PTS)
        cl = V.beam_case('nlv_col_l', sec, 'LE 1', load=('shear', hlat),
                         points=PTS)
        lines = [x for x in ca.files['BC.dat'].strip().split('\n')[2:]
                 if x.strip()]
        lines += [x for x in cl.files['BC.dat'].strip().split('\n')[2:]
                  if x.strip() and not x.startswith('D-PLANE')]
        ca.put('BC.dat', V.bc_text(lines))
        r = g.run(nl_case(ca, 5))
        up = L * math.sqrt(pax / EI)
        amp = 3.0 * (math.tan(up) - up) / up ** 3
        w_ref = hlat * L ** 3 / (3.0 * EI) * amp
        w = r.u()[2] if r.ok else float('nan')
        fe.append(w / (hlat * L ** 3 / (3.0 * EI)))
        ex.append(amp)
        g.check('beam-column P/Pcr = %g: lateral deflection (P-delta)' % q,
                w, w_ref, 3e-2, 'closed form 3(tan u - u)/u^3')
    g.plot('Beam-column: amplification of the lateral deflection',
           'P / P_cr', 'w / w_linear', {'FE (108)': (ratios, fe),
                                         'closed form': (ratios, ex)},
           note='Closed form: 3(tan u - u)/u^3 with u = L sqrt(P/EI).')

    # ---- 4. the same cantilever with solid elements
    p = EI / L ** 2
    c = V.solid_case('nlv_solid', 'H27', 5, 1, L=L, b=B, h=H, nx=1, sol=101,
                     plane_strain=False, load=('shear', p), points=PTS)
    r = g.run(nl_case(c, 10))
    xe, ye = elastica(1.0)
    if r.ok:
        g.check('solid H27 elastica PL^2/EI = 1: tip deflection w/L',
                r.u()[2] / L, ye, 5e-2, 'elastica')
    else:
        g.flag('solid H27 elastica runs', False, r.log[-200:])

    # ---- 5. thermal expansion in the Green measure
    n_el, a_bar = 10, 0.1
    h8 = V.H_PATTERN['H8'][1]
    alpha_big, dt_big = 1.0e-3, 10.0
    c = V.Case('nlv_thermal')
    nid = lambda i, j, k: i + (n_el + 1) * (j + 2 * k) + 1
    lines = ['%d' % (4 * (n_el + 1)), '']
    for k in range(2):
        for j in range(2):
            for i in range(n_el + 1):
                lines.append('%d %s %s %s 1' % (
                    nid(i, j, k), V.fmt(L * i / n_el), V.fmt(a_bar * j),
                    V.fmt(a_bar * k)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE NONE '
          'NONE NONE\n')
    el = ['%d' % n_el, '']
    for e in range(n_el):
        ids = [nid(e + i - 1, j - 1, k - 1) for (i, j, k) in h8]
        el.append('H8 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('MATERIAL.dat', '1 3\n\nISO-M 1  70.0D9 0.3 2700.0\nT-EXP 1  %s\n'
          'T-CON 1  100.0\n' % V.fmt(alpha_big))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    c.put('BC.dat', V.bc_text([V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
                               V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
                               V.dplane(3, 0, 0, 1, 0, None, None, 0.0),
                               'T-CONST 4  %s' % V.fmt(dt_big)]))
    c.put('POSTPROCESSING.dat', V.post_text([(L - 1e-9, 0.5 * a_bar,
                                              0.5 * a_bar)]))
    r = g.run(nl_case(c, 4))
    if r.ok:
        g.check('thermal strain in the Green measure: sqrt(1+2 a dT) - 1',
                r.points[0][10] / L,
                math.sqrt(1.0 + 2.0 * alpha_big * dt_big) - 1.0, 2e-3,
                'closed form (alpha dT = 1 %)')
    else:
        g.flag('thermal Green run', False, r.log[-200:])

    # ---- 6. arc length: shallow arch snap-through
    r_lc = g.run(nl_case(arch_case('nlv_arc_lc', 1, 10, 1.0), 10))
    r_al = g.run(arch_case('nlv_arc_low', 2, 40, 1.0))
    if r_lc.ok and r_al.ok:
        g.check('arc length = load control below the limit load (crown w)',
                crown_path(r_al)[-1][1], crown_path(r_lc)[-1][1], 1e-4,
                'load control (SOLVTEC 1)')
    r_coarse = g.run(arch_case('nlv_arc_coarse', 2, 60, 3.0))
    r_fine = g.run(arch_case('nlv_arc_fine', 2, 400, 3.0, ds=0.6,
                             dsmin=0.01, dsmax=0.6))
    ok = r_coarse.ok and r_fine.ok
    g.flag('arc length through the limit point runs', ok,
           '' if ok else (r_coarse.log + r_fine.log)[-200:])
    if ok:
        pc, pf = crown_path(r_coarse), crown_path(r_fine)
        kc, lc = first_peak(pc)
        kf, lf = first_peak(pf)
        g.flag('snap-through: lambda reaches a maximum', kc is not None and
               kf is not None, 'limits %s / %s' % (lc, lf))
        if kf is not None and kc is not None:
            lam_f = [a for a, _ in pf]
            g.check('limit load: coarse against fine arc-length path', lc,
                    lf, 1.5e-2, 'fine path (400 steps)')
            g.flag('snap-through: the load drops below half the limit '
                   'load', min(lam_f[kf:]) < 0.5 * lf,
                   'limit %.4f, lowest %.4f' % (lf, min(lam_f[kf:])))
            g.flag('snap-through: the crown moves down at the limit',
                   pf[kf][1] < 0.0, 'u_z = %.4g m' % pf[kf][1])
            g.table('Snap-through of the shallow arch (arc length)',
                    ['path', 'steps', 'limit load factor',
                     'crown w at the limit [m]', 'lowest factor'],
                    [['coarse', '60', '%.4f' % lc, '%.3f' % pc[kc][1],
                      '%.3f' % min(a for a, _ in pc[kc:])],
                     ['fine', '400', '%.4f' % lf, '%.3f' % pf[kf][1],
                      '%.3f' % min(lam_f[kf:])]])
            g.plot('Snap-through of a shallow arch: load factor against '
                   'crown displacement', 'crown displacement u_z [m]',
                   'load factor',
                   {'arc length, 400 steps': ([w for _, w in pf],
                                              [a for a, _ in pf]),
                    'arc length, 60 steps': ([w for _, w in pc],
                                             [a for a, _ in pc]),
                    'load control to the limit': (
                        [w for _, w in crown_path(r_lc)],
                        [a for a, _ in crown_path(r_lc)])})
    g.save()
    return g


if __name__ == '__main__':
    group_nonlinear()
