"""Group: multifield analyses (displacements with temperature and electric
potential): piezoelectric actuation, short/open circuit resonance, thermal
expansion and stress, conduction, thermal transient, field selection."""
import math
import os
import re
import sys

import vlib as V
from vcheck import Group

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'PIEZO'))
import pzlib as Z  # noqa: E402

E_T, NU_T, ALPHA, COND, RHO = 70.0e9, 0.3, 1.0e-5, 100.0, 2700.0
L, A, B = 1.0, 0.1, 0.1
H8_LAT = V.H_PATTERN['H8'][1]


def bar_case(name, bcs, n=10):
    """H8 bar along x with displacements and temperature."""
    c = V.Case(name)
    nid = lambda i, j, k: i + (n + 1) * (j + 2 * k) + 1
    lines = ['%d' % (4 * (n + 1)), '']
    for k in range(2):
        for j in range(2):
            for i in range(n + 1):
                lines.append('%d %s %s %s 1' % (
                    nid(i, j, k), V.fmt(L * i / n), V.fmt(A * j),
                    V.fmt(B * k)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE '
          'NONE NONE NONE\n')
    el = ['%d' % n, '']
    for e in range(n):
        ids = [nid(e + i - 1, j - 1, k - 1) for (i, j, k) in H8_LAT]
        el.append('H8 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', V.analysis_text(101, 4, solid='NONE'))
    c.put('MATERIAL.dat', '1 3\n\nISO-M 1  %s %s %s\nT-EXP 1  %s\n'
          'T-CON 1  %s\n' % (V.fmt(E_T), V.fmt(NU_T), V.fmt(RHO),
                             V.fmt(ALPHA), V.fmt(COND)))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    recs = [V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
            V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
            V.dplane(3, 0, 0, 1, 0, None, None, 0.0)] + bcs
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text(
        [(0.55 * L, 0.5 * A, 0.5 * B), (L - 1e-9, 0.5 * A, 0.5 * B)]))
    return c


def trow(res, k):
    r = res.points[k]
    return dict(u=r[10:13], sig=r[25:31], T=r[37], flux=r[46:49])


# ------------------------------------------------ transient heat (104)
KC, CP, LEN, TH1 = 100.0, 900.0, 1.0, 50.0
ALPHA_TH = KC / (RHO * CP)


def heat_series(x, t, terms=60):
    s = 0.0
    for n in range(terms):
        lam = (2 * n + 1) * math.pi / (2 * LEN)
        s += (4.0 / ((2 * n + 1) * math.pi)) * math.sin(lam * x) * \
            math.exp(-lam * lam * ALPHA_TH * t)
    return TH1 * (1.0 - s)


def heat_case(name, tf, nstep, theta, nel=20):
    c = V.Case(name)
    a = b = 0.05
    nid = lambda i, j, k: i + (nel + 1) * (j + 2 * k) + 1
    lines = ['%d' % (4 * (nel + 1)), '']
    for k in range(2):
        for j in range(2):
            for i in range(nel + 1):
                lines.append('%d %s %s %s 1' % (
                    nid(i, j, k), V.fmt(LEN * i / nel), V.fmt(a * j),
                    V.fmt(b * k)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE '
          'NONE NONE NONE\n')
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [nid(e + i - 1, j - 1, k - 1) for (i, j, k) in H8_LAT]
        el.append('H8 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', V.analysis_text(104, 4, solid='NONE'))
    c.put('MATERIAL.dat', '1 3\n\nISO-M 1  70.0D9 0.3 %s\nT-CON 1  %s\n'
          'T-SPC 1  %s\n' % (V.fmt(RHO), V.fmt(KC), V.fmt(CP)))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    c.put('BC.dat', V.bc_text([
        V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
        V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
        V.dplane(3, 0, 0, 1, 0, None, None, 0.0),
        'T-PLANE 4  1 0 0 0  %s' % V.fmt(TH1)]))
    c.put('POSTPROCESSING.dat', V.post_text([(LEN - 1e-9, 0.5 * a, 0.5 * b)]))
    c.put('TIME_RESP.dat', '0.0 %s\n%d\n%d\n0\n---\n1\nSTEP 0.0 1.0\n'
          'THETA %s\n' % (V.fmt(tf), nstep, max(1, nstep // 40),
                          V.fmt(theta)))
    return c


def history(res):
    path = os.path.join(res.case_dir, 'DYNAMIC', 'TIME_HISTORY.dat')
    rows = []
    for line in open(path).read().split('\n')[1:]:
        tok = line.split()
        if len(tok) < 14:
            continue
        rows.append([float(x.replace('D', 'E')) for x in tok])
    return [(r[0], r[1:]) for r in rows]


def stack_case(circuit):
    """thickness-mode piezoelectric column (shared with the piezo suite)."""
    src = open(os.path.join(HERE, '..', 'PIEZO', 'try2.py'),
               encoding='utf-8-sig').read().split('\nt = 0.01')[0]
    ns = {}
    exec(compile(src, 'try2_stack', 'exec'), ns)
    return ns['stack_case']('mf_stack_' + circuit, circuit=circuit)


def group_multifield():
    g = Group('multifield', 'Multifield analyses: electric and thermal '
              'fields', 'H8 block (PZT-5H like) with the potential field; '
              'H8 bars with the temperature field; transient heat '
              'conduction with thermal capacity (analysis 104); selection '
              'of the fields with the FIELDS record of ANALYSIS.dat.')

    # ---- 1. piezoelectric slab: voltage sweep
    d = Z.d_matrix()
    volts = [-200.0, -100.0, -50.0, 50.0, 100.0, 200.0]
    uz, ux, ez, vm = [], [], [], []
    for v in volts:
        r = g.run(Z.slab_case('mf_slab_%g' % v, 0.02, 0.02, 0.002, v))
        if not r.ok:
            g.flag('slab V=%g runs' % v, False, r.log[-200:])
            uz.append(float('nan'))
            ux.append(float('nan'))
            ez.append(float('nan'))
            continue
        p = Z.point_row(r, 0)
        uz.append(p['u'][2])
        ux.append(p['u'][0])
        ez.append(p['E'][2])
        vm.append(Z.point_row(r, 1)['volt'])
        g.check('slab V = %g: thickness expansion -d33 V' % v, uz[-1],
                -d[2][2] * v, 1e-6, 'closed form d33 V (free slab)')
        g.check('slab V = %g: lateral expansion d31 E a/2' % v, ux[-1],
                0.5 * 0.02 * d[2][0] * (-v / 0.002), 1e-6,
                'closed form d31 E x')
        g.check('slab V = %g: electric field -V/t' % v, ez[-1],
                -v / 0.002, 1e-6, 'uniform field')
    g.table('Piezoelectric slab (a = b = 20 mm, t = 2 mm): response to the '
            'voltage', ['V [V]', 'u_z at the top [m]', '-d33 V [m]',
                        'u_x [m]', 'E_z [V/m]'],
            [['%g' % v, '%.4e' % a, '%.4e' % (-d[2][2] * v), '%.4e' % b,
              '%.4g' % c] for v, a, b, c in zip(volts, uz, ux, ez)])
    g.plot('Piezoelectric actuation: top displacement against voltage',
           'voltage [V]', 'u_z [m]',
           {'FE (H8, u and potential)': (volts, uz),
            'closed form -d33 V': (volts, [-d[2][2] * v for v in volts])})

    # ---- 2. thickness-mode stack: short, open circuit, floating
    t = 0.01
    c_sc = Z.C33
    c_oc = Z.C33 + Z.E33 ** 2 / Z.EPS33
    f_oc = 0.25 / t * math.sqrt(c_oc / Z.RHO)
    res = {k: g.run(stack_case(k)) for k in ('SC', 'OC', 'FLT')}
    if all(x.ok for x in res.values()):
        g.check('stack: short-circuit fundamental frequency',
                res['SC'].freq[0], 101434.4, 1e-4,
                'regression value (0.18 % from the transcendental '
                'solution)')
        g.check('stack: open-circuit fundamental frequency',
                res['OC'].freq[0], f_oc, 5e-3,
                'quarter-wave with the piezoelectrically stiffened '
                'modulus')
        g.check('stack: floating electrode equals open circuit',
                res['FLT'].freq[0], res['OC'].freq[0], 1e-6,
                'ties of the floating electrode')
        g.flag('stack: short circuit is softer than open circuit',
               res['SC'].freq[0] < res['OC'].freq[0], '')
        g.table('Thickness resonance of the piezoelectric column',
                ['circuit', 'f1 [Hz]', 'reference [Hz]'],
                [['short circuit', '%.1f' % res['SC'].freq[0], '101434.4'],
                 ['open circuit', '%.1f' % res['OC'].freq[0],
                  '%.1f' % f_oc],
                 ['floating electrode', '%.1f' % res['FLT'].freq[0],
                  '= open circuit']])
    else:
        g.flag('stack runs', False, '')

    # ---- 3. thermal expansion and stress sweep
    dts = [5.0, 10.0, 20.0, 40.0]
    u_free, s_cl = [], []
    for dt in dts:
        r1 = g.run(bar_case('mf_free_%g' % dt, ['T-CONST 4  %s' % V.fmt(dt)]))
        r2 = g.run(bar_case('mf_clamp_%g' % dt, [
            'T-CONST 4  %s' % V.fmt(dt),
            V.dplane(5, 1, 0, 0, -L, 0.0, None, None)]))
        if not (r1.ok and r2.ok):
            g.flag('thermal bar dT=%g runs' % dt, False, '')
            u_free.append(float('nan'))
            s_cl.append(float('nan'))
            continue
        pf, pc = trow(r1, 1), trow(r2, 0)
        u_free.append(pf['u'][0])
        s_cl.append(pc['sig'][0])
        g.check('free bar dT = %g: end displacement alpha dT L' % dt,
                pf['u'][0], ALPHA * dt * L, 1e-6, 'closed form')
        g.check('clamped bar dT = %g: stress -E alpha dT' % dt,
                pc['sig'][0], -E_T * ALPHA * dt, 1e-6, 'closed form')
    g.table('Thermal expansion and thermal stress of the bar',
            ['dT [K]', 'u_x free [m]', 'alpha dT L [m]',
             'sigma_x clamped [Pa]', '-E alpha dT [Pa]'],
            [['%g' % dt, '%.4e' % u, '%.4e' % (ALPHA * dt * L),
              '%.4e' % s, '%.4e' % (-E_T * ALPHA * dt)]
             for dt, u, s in zip(dts, u_free, s_cl)])
    g.plot('Thermal stress of the clamped bar', 'temperature rise [K]',
           'axial stress [MPa]',
           {'FE': (dts, [s / 1e6 for s in s_cl]),
            '-E alpha dT': (dts, [-E_T * ALPHA * x / 1e6 for x in dts])})

    # ---- 4. steady conduction (beam, plate and solid models)
    t0, t1 = 10.0, 110.0
    r = g.run(bar_case('mf_cond', ['T-PLANE 4  1 0 0 0  %s' % V.fmt(t0),
                                   'T-PLANE 5  1 0 0 %s  %s' % (
                                       V.fmt(-L), V.fmt(t1))]))
    if r.ok:
        p = trow(r, 0)
        g.check('conduction: temperature at x = 0.55 L', p['T'],
                t0 + 0.55 * (t1 - t0), 1e-9, 'linear profile')
        g.check('conduction: heat flux -k dT/dx', p['flux'][0],
                -COND * (t1 - t0) / L, 1e-8, 'Fourier law')
        g.flag('conduction: a linear temperature gives (almost) no stress',
               max(abs(x) for x in p['sig']) < 5e-3 * E_T * ALPHA * (t1 - t0),
               'max |sigma| %.3e Pa' % max(abs(x) for x in p['sig']))
    r = g.run(bar_case('mf_power', ['T-PLANE 4  1 0 0 0  0.0'] + [
        'Q-POINT %d  %s %s %s  %s' % (5 + k, V.fmt(L), V.fmt(y), V.fmt(z),
                                      V.fmt(12.5)) for k, (y, z) in
        enumerate(((0.0, 0.0), (A, 0.0), (0.0, B), (A, B)))]))
    if r.ok:
        g.check('heat power 50 W: end temperature Q L/(k A B)',
                trow(r, 1)['T'], 50.0 * L / (COND * A * B), 1e-8,
                'closed form')

    # ---- 5. transient heat conduction (analysis 104)
    r = g.run(heat_case('mf_heat', 8000.0, 800, 1.0))
    if r.ok:
        h = history(r)
        ts = [t for t, _ in h]
        ys = [row[37] for _, row in h]
        for tc in (2000.0, 4000.0, 8000.0):
            t, row = min(h, key=lambda p: abs(p[0] - tc))
            g.check('heat: insulated end T(L, %g s)' % tc, row[37],
                    heat_series(LEN, t), 3e-2,
                    'Fourier series (Dirichlet / Neumann bar)')
        g.plot('Transient heat conduction: temperature of the insulated '
               'end', 'time [s]', 'temperature [K]',
               {'FE (104, backward Euler)': (ts, ys),
                'series solution': (ts, [heat_series(LEN, x) for x in ts])})
    r = g.run(heat_case('mf_heat_cn', 8000.0, 400, 0.5))
    if r.ok:
        t, row = min(history(r), key=lambda p: abs(p[0] - 4000.0))
        g.check('heat: Crank-Nicolson at 4000 s', row[37],
                heat_series(LEN, t), 2e-2, 'Fourier series')

    # ---- 6. selection of the fields in ANALYSIS.dat
    base = g.run(Z.slab_case('mf_fld_base', 0.02, 0.02, 0.002, 100.0))
    c = Z.slab_case('mf_fld_on', 0.02, 0.02, 0.002, 100.0)
    c.files['ANALYSIS.dat'] += 'FIELDS MECH PIEZO\n'
    on = g.run(c)
    c = Z.slab_case('mf_fld_off', 0.02, 0.02, 0.002, 100.0)
    c.files['ANALYSIS.dat'] += 'FIELDS MECH\n'
    off = g.run(c)
    if base.ok and on.ok and off.ok:
        g.check('FIELDS MECH PIEZO equals the file without the record',
                Z.point_row(on, 0)['u'][2], Z.point_row(base, 0)['u'][2],
                1e-12, 'same input without the record')
        g.flag('FIELDS MECH switches the potential off (no deformation)',
               abs(Z.point_row(off, 0)['u'][2]) < 1e-15,
               'u_z = %.2e m' % Z.point_row(off, 0)['u'][2])
    g.save()
    return g


if __name__ == '__main__':
    group_multifield()
