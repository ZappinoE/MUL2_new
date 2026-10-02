"""Group: hierarchical Legendre expansions (HQ4 sections, HB2 lines)."""
import math

import vlib as V
from vcheck import Group
from g_beams import (L, B, H, I, A, E, NU, RHO, G, P, KAP, W_EB, W_TIM,
                     F_EB, F_TIM, references, ref_table, static_run,
                     modal_run, patch_run, patch_error, section, D0)


def hle_section(n, order):
    return V.rect_mesh('HQ4', n, n, -B / 2, B / 2, -H / 2, H / 2,
                       order=order)


def rotate_element(sec, k, shift):
    """renumber the ring of element k (shift positions): changes the
    direction of its sides with respect to the neighbours."""
    topo, ids, extra, lam = sec.elems[k]
    sec.elems[k] = (topo, ids[shift:] + ids[:shift], extra, lam)


def tube_section(order, Ro=0.5, Ri=0.4, curved=True):
    m = V.Mesh2D()
    m.kind = 'HLE'
    th = lambda k: k * math.pi / 2
    for k in range(4):
        m.nodes[1 + 2 * k] = (Ri * math.cos(th(k)), Ri * math.sin(th(k)))
        m.nodes[2 + 2 * k] = (Ro * math.cos(th(k)), Ro * math.sin(th(k)))
    Rm = 0.5 * (Ri + Ro)
    for k in range(4):
        m.aux[100 + k] = (Rm * math.cos(th(k)), Rm * math.sin(th(k)))
        a = th(k) + math.pi / 4
        m.aux[200 + k] = (Ro * math.cos(a), Ro * math.sin(a))
        m.aux[300 + k] = (Ri * math.cos(a), Ri * math.sin(a))
    for k in range(4):
        k1 = (k + 1) % 4
        v = [1 + 2 * k, 2 + 2 * k, 2 + 2 * k1, 1 + 2 * k1]
        mids = [100 + k, 200 + k, 100 + k1, 300 + k]
        extra = [order] + (mids if curved else [])
        if not curved:
            # straight sides: no mid nodes are read, the aux nodes are
            # not needed either
            pass
        m.elems.append(('HQ4', v, extra, 1))
    if not curved:
        m.aux = {}
    return m


def tube_case(name, order, curved=True, sol=101, nmodes=8, **kw):
    Ro, Ri = 0.5, 0.4
    sec = tube_section(order, Ro, Ri, curved)
    pts = [(0.45, L - 1e-6, 0.0)]
    c = V.beam_case(name, sec, 'HLE', sol=sol, nmodes=nmodes, points=pts,
                    **kw)
    if sol == 101:
        recs = ['D-PLANE 1  0D0 1D0 0D0 0D0   0.0D0 0.0D0 0.0D0']
        for i, (x, z) in sorted(sec.nodes.items()):
            recs.append(V.fpoint(len(recs) + 1, x, L, z, 0.0, 0.0, P / 8.0))
        c.put('BC.dat', V.bc_text(recs))
    return c, sec


def group_hle():
    g = Group('hle', 'Hierarchical Legendre expansions (HLE)',
              'Section sub-elements HQ4 of order p (trunk space of '
              'Szabo and Babuska, as in Pagani, de Miguel and Carrera '
              '2017) on the square cantilever of the previous groups.  '
              'Vertices are nodes of the section mesh, side and internal '
              'modes carry no node.')
    ref = references()
    ref_table(g, ref)
    # ------------------------------------------------ p-convergence
    rows, curves1, curves4, fcurves = [], {}, {}, {}
    for n, label in ((1, '1 element'), (2, '2x2 elements')):
        xs, ys, fs = [], [], []
        for p in range(1, 9 if n == 1 else 7):
            sec = hle_section(n, p)
            r, w, s = static_run(g, 'hle_%d_p%d' % (n, p), sec, 'HLE')
            rm = modal_run(g, 'hle_%d_p%d_m' % (n, p), sec, 'HLE')
            if not (r.ok and rm.ok):
                g.flag('HLE %s p=%d runs' % (label, p), False, 'run failed')
                continue
            nm = {1: 4, 2: 8, 3: 12, 4: 17, 5: 23, 6: 30, 7: 38, 8: 47}[p]
            terms = (n + 1) ** 2 + 0  # vertices of the section
            xs.append(p)
            ys.append(w / ref['le_w'])
            fs.append(rm.freq[0])
            rows.append([label, p, r.ndof, '%.6e' % w,
                         '%+.3f' % (100 * (w / ref['le_w'] - 1)),
                         '%.4f' % rm.freq[0],
                         '%+.3f' % (100 * (rm.freq[0] / ref['le_f'][0] - 1)),
                         '%.1f' % r.wall])
            if p >= 3:
                g.check('HLE %s p=%d tip deflection vs LE reference'
                        % (label, p), w, ref['le_w'], 0.01, 'LE Q16 4x4')
                g.check('HLE %s p=%d f1 vs LE reference' % (label, p),
                        rm.freq[0], ref['le_f'][0], 0.01, 'LE Q16 4x4')
        curves1[label] = (xs, ys)
        fcurves[label] = (xs, fs)
    g.table('p-convergence of the section expansion (B4 x 5 axial)',
            ['section mesh', 'p', 'DOF', 'tip w [m]', 'vs LE ref [%]',
             'f1 [Hz]', 'f1 vs ref [%]', 'time [s]'], rows,
            'With the loads restricted to vertex nodes the side modes '
            'carry no load; the convergence is that of the stiffness.')
    g.plot('HLE: p-convergence of the tip deflection', 'section order p',
           'w / w(LE ref)', curves1,
           hlines={'3D solid H27': ref['h27_w'] / ref['le_w']})
    g.plot('HLE: p-convergence of the first frequency', 'section order p',
           'f1 [Hz]', fcurves, hlines={'3D solid H27': ref['h27_f'][0]})
    # --------------------------------------------- equivalences
    for n in (1, 2):
        ra, wa, _ = static_run(g, 'hleq_q4_%d' % n, section('Q4', n), 'LE 1')
        rb, wb, _ = static_run(g, 'hleq_h1_%d' % n, hle_section(n, 1), 'HLE')
        g.check('HQ4 p=1 == LE Q4, %dx%d: tip deflection' % (n, n), wb, wa,
                1e-9, 'LE Q4 (same mesh)')
        ma = modal_run(g, 'hleq_q4_%d_m' % n, section('Q4', n), 'LE 1')
        mb = modal_run(g, 'hleq_h1_%d_m' % n, hle_section(n, 1), 'HLE')
        g.check('HQ4 p=1 == LE Q4, %dx%d: f1' % (n, n), mb.freq[0],
                ma.freq[0], 1e-9, 'LE Q4 (same mesh)')
    # --------------------------------------------- patch tests
    rows = []
    for name, sec in (('p=1 2x2', hle_section(2, 1)),
                      ('p=4 2x2', hle_section(2, 4)),
                      ('p=6 1 element', hle_section(1, 6)),
                      ('mixed p=2|3|4|5',
                       hle_section(2, lambda i, j: 2 + i + 2 * j)),
                      ('curved tube p=4', tube_section(4))):
        pts = [(0.0, 5.0, 0.0), (0.3, 3.7, -0.2)]
        if 'tube' in name:
            pts = [(0.45, 5.0, 0.0), (0.0, 3.7, -0.43)]
        c = V.beam_case('hle_patch_' + name.replace(' ', '_').replace('|', '_'),
                        sec, 'HLE', nu=0.0, load=('axial_disp', D0),
                        points=pts)
        r = g.run(c)
        pe = patch_error(r) if r.ok else float('nan')
        g.check('HLE patch test (nu=0), ' + name, pe, 0.0, 1e-6,
                'exact uniform field', mode='abs')
        rows.append([name, '%.2e' % pe])
    g.table('Uniform-extension patch test of the HLE sections', ['section',
            'max error / d'], rows)
    # --------------------------------------- interface orders / signs
    rows = []
    corner = (B / 2, L, H / 2)

    def corner_run(name, sec):
        c = V.beam_case(name, sec, 'HLE', points=[(B / 2, L - 1e-6, H / 2)])
        recs = ['D-PLANE 1  0D0 1D0 0D0 0D0   0.0D0 0.0D0 0.0D0',
                V.fpoint(2, B / 2, L, H / 2, 0.0, 0.0, P)]
        c.put('BC.dat', V.bc_text(recs))
        r = g.run(c)
        return r.u(0)[2] if r.ok else float('nan')

    uni2 = corner_run('hli_u2', hle_section(2, 2))
    uni4 = corner_run('hli_u4', hle_section(2, 4))
    uni5 = corner_run('hli_u5', hle_section(2, 5))
    mix = corner_run('hli_m24', hle_section(2, lambda i, j: 2 + 2 * ((i + j) % 2)))
    mix2 = corner_run('hli_m35', hle_section(2, lambda i, j: 3 + 2 * (i % 2)))
    sec = hle_section(2, lambda i, j: 2 + 2 * ((i + j) % 2))
    rotate_element(sec, 1, 1)
    rotate_element(sec, 2, 2)
    rotate_element(sec, 3, 3)
    mixr = corner_run('hli_m24_rot', sec)
    g.check('mixed orders 2|4: displacement at the loaded corner >= p=2',
            1.0 if mix >= uni2 else 0.0, 1.0, 0.0,
            'Ritz bound (compliance grows with enrichment)', mode='abs')
    g.check('mixed orders 2|4: displacement at the loaded corner <= p=4',
            1.0 if mix <= uni4 else 0.0, 1.0, 0.0,
            'Ritz bound', mode='abs')
    g.check('mixed orders 3|5: between uniform p=3 and p=5',
            1.0 if corner_run('hli_u3', hle_section(2, 3)) <= mix2 <= uni5
            else 0.0, 1.0, 0.0, 'Ritz bound', mode='abs')
    g.check('rotated node numbering: same result (sign (-1)^k at the '
            'interfaces)', mixr, mix, 1e-8, 'same model, other numbering')
    g.table('Non-conforming orders on the section interfaces '
            '(point load at the loaded corner, displacement at the corner)',
            ['model', 'u_z at the loaded corner [m]'],
            [['uniform p=2', '%.6e' % uni2], ['mixed 2|4 (checkerboard)',
              '%.6e' % mix], ['mixed 2|4, rotated numbering of 3 elements',
              '%.6e' % mixr], ['uniform p=4', '%.6e' % uni4],
             ['uniform p=5', '%.6e' % uni5],
             ['mixed 3|5', '%.6e' % mix2]],
            'The deflection at the loaded point grows monotonically with '
            'the space (energy minimisation); the mixed models lie '
            'between their uniform bounds and are independent of the '
            'numbering of the sub-element nodes.')
    # ---------------------------------------------- curved tube
    Ro, Ri = 0.5, 0.4
    It = math.pi / 4 * (Ro ** 4 - Ri ** 4)
    At = math.pi * (Ro ** 2 - Ri ** 2)
    w_eb = V.eb_tip(P, L, E, It)
    f_eb = V.eb_freqs(L, E, It, RHO, At, 4)
    m2 = (Ri / Ro) ** 2                # Cowper shear coefficient of a tube
    kt = 6 * (1 + NU) * (1 + m2) ** 2 / (
        (7 + 6 * NU) * (1 + m2) ** 2 + (20 + 12 * NU) * m2)
    w_tim = V.timoshenko_tip(P, L, E, It, G, At, kt)
    f_tim = V.timoshenko_freqs(L, E, It, RHO, At, G, kt, 4)
    rows, xs, ws, f1s = [], [], [], []
    for p in range(2, 7):
        c, sec = tube_case('hle_tube_p%d' % p, p, load=('shear', P))
        r = g.run(c)
        cm, _ = tube_case('hle_tube_p%d_m' % p, p, sol=103)
        rm = g.run(cm)
        if not (r.ok and rm.ok):
            g.flag('tube p=%d runs' % p, False, 'run failed')
            continue
        w = r.u(0)[2]
        xs.append(p)
        ws.append(w / w_eb)
        f1s.append(rm.freq[0])
        rows.append([p, r.ndof, '%.6e' % w,
                     '%+.3f' % (100 * (w / w_tim - 1)),
                     '%.4f' % rm.freq[0],
                     '%+.3f' % (100 * (rm.freq[0] / f_tim[0] - 1)),
                     '%.4f' % rm.freq[2],
                     '%+.3f' % (100 * (rm.freq[2] / f_tim[1] - 1))])
        if p >= 4:
            g.check('tube (4 curved HQ4, p=%d): tip deflection vs '
                    'Timoshenko' % p, w, w_tim, 0.02, 'Timoshenko tube')
            g.check('tube p=%d: f1 vs Timoshenko' % p, rm.freq[0],
                    f_tim[0], 0.01, 'Timoshenko tube')
            g.check('tube p=%d: second bending frequency vs Timoshenko'
                    % p, rm.freq[2], f_tim[1], 0.02, 'Timoshenko tube')
    g.table('Thin tube (Ro=0.5, Ri=0.4, L=10) with four curved HQ4 '
            'sub-elements. Timoshenko (k=%.3f): w = %.5e m, f1 = %.4f Hz, '
            'f2 = %.4f Hz; Euler-Bernoulli: w = %.5e m, f1 = %.4f Hz, '
            'f2 = %.4f Hz' % (kt, w_tim, f_tim[0], f_tim[1], w_eb,
                              f_eb[0], f_eb[1]),
            ['p', 'DOF', 'tip w [m]', 'vs Timoshenko [%]', 'f1 [Hz]',
             'vs Timoshenko [%]', 'f2 [Hz]', 'vs Timoshenko [%]'], rows,
            'The remaining differences come from the 3D clamp and the '
            'ovalisation of the thin wall, neglected by beam theories.')
    g.plot('HLE tube: convergence with p', 'section order p',
           'w / w(Euler-Bernoulli)', {'4 curved HQ4': (xs, ws)},
           hlines={'Timoshenko': w_tim / w_eb})
    # curved versus straight sides (geometry representation)
    cc, _ = tube_case('hle_tube_stra', 4, curved=False, sol=103)
    rs = g.run(cc)
    cm, _ = tube_case('hle_tube_curv', 4, curved=True, sol=103)
    rc = g.run(cm)
    g.table('Effect of the geometry map (p=4)',
            ['sides', 'f1 [Hz]', 'f1 vs EB [%]'],
            [['circular arcs (mid nodes)', '%.4f' % rc.freq[0],
              '%+.3f' % (100 * (rc.freq[0] / f_eb[0] - 1))],
             ['straight sides (polygon)', '%.4f' % rs.freq[0],
              '%+.3f' % (100 * (rs.freq[0] / f_eb[0] - 1))]],
            'The straight-sided model has less material (the polygon '
            'cuts the arcs): the mid-node geometry removes this error.')
    g.check('curved map: f1 closer to EB than the polygon',
            1.0 if abs(rc.freq[0] - f_eb[0]) < abs(rs.freq[0] - f_eb[0])
            else 0.0, 1.0, 0.0, 'geometry', mode='abs')
    g.save()
    return g
