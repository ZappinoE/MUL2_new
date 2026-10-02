"""Group: solid elements H8 and H27."""
import vlib as V
from vcheck import Group
from g_beams import L, B, H, E, NU, D0
from g_plates import (P, W_EB, W_TIM, F_EB, F_TIM, Ih, ps_reference)


def group_solids():
    g = Group('solids', 'Solid elements H8 and H27',
              'Plane-strain block of the same strip as in the plate group '
              '(L=10, b=h=1, u_x = 0 on the lateral faces); the solid '
              'nodes carry one three-component term (section "S1").')
    ref = ps_reference()
    meshes = {'H8': [(10, 2), (20, 4), (40, 8)],
              'H27': [(5, 1), (10, 2), (10, 3)]}
    rows, curves, fcurves = [], {}, {}
    for topo, ml in meshes.items():
        for shear in ('NONE', 'MITC'):
            xs, ys, fs = [], [], []
            for ny, nz in ml:
                tag = '%s_%s_%dx%d' % (topo, shear, ny, nz)
                c = V.solid_case('so_' + tag, topo, ny, nz, shear=shear,
                                 load=('shear', P))
                r = g.run(c)
                cm = V.solid_case('so_%s_m' % tag, topo, ny, nz, shear=shear,
                                  sol=103, nmodes=4)
                rm = g.run(cm)
                if not (r.ok and rm.ok and r.points):
                    rows.append([topo, shear, '1x%dx%d' % (ny, nz), r.ndof,
                                 'singular / fails', '-', '-', '-', '-'])
                    continue
                w, f = r.u(0)[2], rm.freq[0]
                if abs(w / ref['w']) > 50:
                    rows.append([topo, shear, '1x%dx%d' % (ny, nz), r.ndof,
                                 'singular (%.1e)' % w, '-', '-', '-', '-'])
                    continue
                xs.append(r.ndof)
                ys.append(w / ref['w'])
                fs.append(f)
                rows.append([topo, shear, '1x%dx%d' % (ny, nz), r.ndof,
                             '%.6e' % w,
                             '%+.3f' % (100 * (w / W_TIM - 1)),
                             '%+.3f' % (100 * (w / ref['w'] - 1)),
                             '%.4f' % f,
                             '%+.3f' % (100 * (f / F_TIM[0] - 1))])
            if xs:
                curves['%s %s' % (topo, shear)] = (xs, ys)
                fcurves['%s %s' % (topo, shear)] = (xs, fs)
    g.table('Static and modal results, plane-strain strip '
            '(Timoshenko: w = %.5e m, f1 = %.4f Hz)' % (W_TIM, F_TIM[0]),
            ['element', 'shear', 'mesh', 'DOF', 'tip w [m]',
             'vs Timoshenko [%]', 'vs H27 fine [%]', 'f1 [Hz]',
             'f1 vs Timoshenko [%]'], rows,
            'The reference solution is the finest H27 mesh (1x10x3). '
            'For the trilinear H8 the MITC tying of the transverse shear '
            'removes most of the bending locking of the full integration.')
    g.plot('Solids: tip deflection', 'DOF', 'w / w(H27 fine)', curves,
           logx=True)
    g.plot('Solids: first frequency', 'DOF', 'f1 [Hz]', fcurves,
           logx=True, hlines={'Timoshenko': F_TIM[0]})
    # checks
    for (topo, shear, ny, nz), tol in (
            (('H27', 'NONE', 10, 3), 0.005), (('H27', 'MITC', 10, 3), 0.005),
            (('H27', 'NONE', 10, 2), 0.01), (('H8', 'NONE', 40, 8), 0.035),
            (('H8', 'MITC', 40, 8), 0.015)):
        c = V.solid_case('sc_%s_%s' % (topo, shear), topo, ny, nz,
                         shear=shear, load=('shear', P))
        w = g.run(c).u(0)[2]
        g.check('%s %s 1x%dx%d tip deflection vs fine H27' % (
            topo, shear, ny, nz), w, ref['w'], tol, '3D solid H27 1x10x3')
        g.check('%s %s 1x%dx%d tip deflection vs Timoshenko' % (
            topo, shear, ny, nz), w, W_TIM, 0.035, 'Timoshenko k=5/6')
    cn = V.solid_case('sc_h8_none10', 'H8', 10, 2, shear='NONE',
                      load=('shear', P))
    cm = V.solid_case('sc_h8_mitc10', 'H8', 10, 2, shear='MITC',
                      load=('shear', P))
    wn, wm = g.run(cn).u(0)[2], g.run(cm).u(0)[2]
    g.check('H8 1x10x2: MITC is closer to the reference than the full '
            'integration', 1.0 if abs(wm - ref['w']) < abs(wn - ref['w'])
            else 0.0, 1.0, 0.0, 'locking relief', mode='abs',
            note='w_NONE=%.4e  w_MITC=%.4e  ref=%.4e' % (wn, wm, ref['w']))
    # exactness
    rows = []
    Ib = H ** 3 / 12.0
    for topo, (ny, nz) in (('H8', (10, 2)), ('H8', (40, 8)),
                           ('H27', (5, 1)), ('H27', (10, 2))):
        cp = V.solid_case('sp_%s_%d' % (topo, ny), topo, ny, nz, nu=0.0,
                          load=('axial_disp', D0),
                          points=[(0.0, 5.0, 0.0), (0.2, 3.7, 0.3)])
        rp = g.run(cp)
        pe = max(abs(p[11] - D0 * p[2] / L) / D0 for p in rp.points)
        g.check('%s 1x%dx%d uniform-extension patch test' % (topo, ny, nz),
                pe, 0.0, 1e-6, 'exact field', mode='abs')
        cb = V.solid_case('sb_%s_%d' % (topo, ny), topo, ny, nz, nu=0.0,
                          load=('moment', 1.0e6, Ib),
                          points=[(0.0, L - 1e-6, 0.0)])
        rb = g.run(cb)
        exact = (1.0e6 / B) * (L - 1e-6) ** 2 / (2 * E * Ib)
        e = abs(rb.u(0)[2] - exact) / exact
        cbm = V.solid_case('sbm_%s_%d' % (topo, ny), topo, ny, nz, nu=0.0,
                           shear='MITC', load=('moment', 1.0e6, Ib),
                           points=[(0.0, L - 1e-6, 0.0)])
        rbm = g.run(cbm)
        em = abs(rbm.u(0)[2] - exact) / exact
        cpm = V.solid_case('spm_%s_%d' % (topo, ny), topo, ny, nz, nu=0.0,
                           shear='MITC', load=('axial_disp', D0),
                           points=[(0.0, 5.0, 0.0), (0.2, 3.7, 0.3)])
        pem = max(abs(p[11] - D0 * p[2] / L) / D0 for p in g.run(cpm).points)
        g.check('%s 1x%dx%d uniform-extension patch test, MITC' % (
            topo, ny, nz), pem, 0.0, 1e-6, 'exact field', mode='abs')
        rows.append([topo, '1x%dx%d' % (ny, nz), '%.2e' % pe,
                     '%.2e' % e, '%.2e' % em])
        if topo == 'H27':
            g.check('H27 1x%dx%d pure bending (nu=0)' % (ny, nz),
                    rb.u(0)[2], exact, 1e-6, 'exact m L^2/(2EI)')
        else:
            g.check('H8 1x%dx%d pure bending (nu=0)' % (ny, nz),
                    rb.u(0)[2], exact, None, 'exact m L^2/(2EI)',
                    note='trilinear element: bending locking, error '
                         'decreases with refinement')
    g.table('Exactness tests of the solid elements (nu = 0)',
            ['element', 'mesh', 'patch error', 'pure bending (full)',
             'pure bending (MITC)'], rows,
            'H27 contains the exact quadratic bending field; H8 does not '
            '(parasitic shear).')
    g.save()
    return g

