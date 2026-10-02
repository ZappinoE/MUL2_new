"""Thermal field (analysis 101): conduction and one-way thermoelasticity.

    python TESTS/THERMAL/thermal_tests.py [path_to_MUL2_V3.exe]

A bar along x (H8 elements, section a x b, isotropic material) with the
temperature field T (field 4) and the three displacements.
"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    os.environ['MUL2_EXE'] = os.path.abspath(sys.argv[1])
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_thermal_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []
E, NU, ALPHA, COND, RHO = 70.0e9, 0.3, 1.0e-5, 100.0, 2700.0
L, A, B = 1.0, 0.1, 0.1


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


H8_LAT = V.H_PATTERN['H8'][1]


def bar_case(name, bcs, n=10, material_extra=''):
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
          'T-CON 1  %s\n' % (V.fmt(E), V.fmt(NU), V.fmt(RHO),
                             V.fmt(ALPHA), V.fmt(COND)))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    # rigid-body supports: x = 0 plane (ux), y = 0 plane (uy), z = 0 (uz)
    recs = [V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
            V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
            V.dplane(3, 0, 0, 1, 0, None, None, 0.0)] + bcs
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text(
        [(0.55 * L, 0.5 * A, 0.5 * B), (L - 1e-9, 0.5 * A, 0.5 * B)]))
    return c


def row(res, k):
    r = res.points[k]
    return dict(u=r[10:13], sig=r[25:31], T=r[37], flux=r[46:49])


DT = 20.0
# ---- 1. uniform temperature, free body: u = alpha*dT*x, no stress
r = bar_case('th_free', ['T-CONST 4  %s' % V.fmt(DT)]).run()
check('free expansion runs', r.ok, r.log[-300:] if not r.ok else '')
p = row(r, 1)
close('free: temperature', p['T'], DT, 1e-9)
close('free: end displacement alpha*dT*L', p['u'][0], ALPHA * DT * L, 1e-6)
check('free: stress free', max(abs(x) for x in p['sig']) < 1e-6 * E * ALPHA
      * DT, 'max |sigma| %.3e' % max(abs(x) for x in p['sig']))

# ---- 2. both ends clamped: sigma_x = -E alpha dT
r = bar_case('th_clamped', ['T-CONST 4  %s' % V.fmt(DT),
                            V.dplane(5, 1, 0, 0, -L, 0.0, None, None)]
             ).run()
p = row(r, 0)
close('clamped: axial stress -E*alpha*dT', p['sig'][0], -E * ALPHA * DT,
      1e-6)
check('clamped: lateral stress free',
      abs(p['sig'][1]) < 1e-6 * E * ALPHA * DT and
      abs(p['sig'][2]) < 1e-6 * E * ALPHA * DT, '')

# ---- 3. conduction between two temperatures
T0, T1 = 10.0, 110.0
r = bar_case('th_cond', ['T-PLANE 4  1 0 0 0  %s' % V.fmt(T0),
                         'T-PLANE 5  1 0 0 %s  %s' % (V.fmt(-L),
                                                       V.fmt(T1))]).run()
check('conduction runs', r.ok, r.log[-300:] if not r.ok else '')
p = row(r, 0)
close('conduction: temperature at x = 0.55 L', p['T'],
      T0 + 0.55 * (T1 - T0), 1e-9)
close('conduction: flux -k dT/dx', p['flux'][0], -COND * (T1 - T0) / L,
      1e-8)
# thermal stress of a linear temperature field is (almost) zero
check('conduction: linear T gives (almost) no stress',
      max(abs(x) for x in p['sig']) < 5e-3 * E * ALPHA * (T1 - T0),
      'max |sigma| %.3e' % max(abs(x) for x in p['sig']))
q = row(r, 1)
close('conduction: end temperature', q['T'], T1, 1e-6)

# ---- 4. heat power: T fixed at x = 0, power Q spread on the end face
Q = 50.0
recs = ['T-PLANE 4  1 0 0 0  0.0']
for (y, z) in ((0.0, 0.0), (A, 0.0), (0.0, B), (A, B)):
    recs.append('Q-POINT %d  %s %s %s  %s' % (
        5 + len(recs) - 1, V.fmt(L), V.fmt(y), V.fmt(z), V.fmt(Q / 4.0)))
r = bar_case('th_power', recs).run()
check('heat power runs', r.ok, r.log[-300:] if not r.ok else '')
q = row(r, 1)
close('heat power: end temperature Q*L/(k*A*B)', q['T'],
      Q * L / (COND * A * B), 1e-8)

# ---- 5. the same physics with beam (1D), plate (2D) and solid (3D) models
import re  # noqa: E402
LB, BB, HB = 1.0, 0.1, 0.1


def patch_t(c, bcs):
    c.put('NODES.dat', re.sub(r'[ \t]+(H?LE|TE)[ \t]*\d*[ \t]*$', ' 1',
                              c.files['NODES.dat'], flags=re.M))
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE '
          'NONE NONE NONE\n')
    c.put('MATERIAL.dat', '1 3\n\nISO-M 1  %s %s %s\nT-EXP 1  %s\n'
          'T-CON 1  %s\n' % (V.fmt(E), V.fmt(NU), V.fmt(RHO),
                             V.fmt(ALPHA), V.fmt(COND)))
    recs = [V.dplane(1, 0, 1, 0, 0, None, 0.0, None),
            V.dplane(2, 1, 0, 0, 0, 0.0, None, None),
            V.dplane(3, 0, 0, 1, 0, None, None, 0.0)] + bcs
    c.put('BC.dat', V.bc_text(recs))
    return c


def models(name, bcs):
    pts = [(0.0, 0.55 * LB, 0.0), (0.0, LB - 1e-7, 0.0)]
    sec = V.rect_mesh('Q9', 2, 2, -BB / 2, BB / 2, -HB / 2, HB / 2)
    yield 'beam', patch_t(V.beam_case(
        name + '_beam', sec, ['LE'] * 21, L=LB, nel=5, btype='B4',
        nmodes=4, points=pts), bcs)
    yield 'plate', patch_t(V.plate_case(
        name + '_plate', 'Q9', 5, ('LE', 'B3', 1), L=LB, b=BB, h=HB,
        nx=1, nmodes=4, points=pts), bcs)
    yield 'solid', patch_t(V.solid_case(
        name + '_solid', 'H27', 5, 1, L=LB, b=BB, h=HB, nx=1, nmodes=4,
        plane_strain=False, points=pts), bcs)


for nm, c in models('thm_free', ['T-CONST 4  %s' % V.fmt(DT)]):
    r = c.run()
    check('%s: uniform temperature runs' % nm, r.ok,
          r.log[-300:] if not r.ok else '')
    close('%s: free expansion alpha*dT*L' % nm, r.points[1][11],
          ALPHA * DT * LB, 1e-5)
    check('%s: free expansion is stress free' % nm,
          max(abs(x) for x in r.points[1][25:31]) < 1e-6 * E * ALPHA * DT,
          '')
for nm, c in models('thm_cond', ['T-PLANE 4  0 1 0 0  %s' % V.fmt(T0),
                                 'T-PLANE 5  0 1 0 %s  %s' % (
                                     V.fmt(-LB), V.fmt(T1))]):
    r = c.run()
    check('%s: conduction runs' % nm, r.ok,
          r.log[-300:] if not r.ok else '')
    close('%s: temperature at 0.55 L' % nm, r.points[0][37],
          T0 + 0.55 * (T1 - T0), 1e-8)
    close('%s: heat flux -k dT/dy' % nm, r.points[0][47],
          -COND * (T1 - T0) / LB, 1e-7)
# ---- 6. surface heat loads: flux, convection, sun
import re as _re  # noqa: E402


def surface_log(res):
    """{id: (area, power)} from the console log."""
    out = {}
    for m in _re.finditer(r'SURFACE LOAD (\d+): AREA\s+(\S+), HEAT POWER'
                          r'\s+(\S+)', res.log):
        out[int(m.group(1))] = (float(m.group(2)), float(m.group(3)))
    return out


QFLUX = 2.0e3
r = bar_case('th_qflux', ['T-PLANE 4  1 0 0 0  0.0',
                          'Q-PLANE 5  1 0 0 %s  %s' % (V.fmt(-L),
                                                       V.fmt(QFLUX))]).run()
check('Q-PLANE runs', r.ok, r.log[-300:] if not r.ok else '')
q = row(r, 1)
close('Q-PLANE: end temperature q*L/k', q['T'], QFLUX * L / COND, 1e-8)
sl = surface_log(r)
close('Q-PLANE: area of the end face', sl[5][0], A * B, 1e-10)
close('Q-PLANE: power q*A', sl[5][1], QFLUX * A * B, 1e-10)

H, TINF = 50.0, 100.0
r = bar_case('th_conv', ['T-PLANE 4  1 0 0 0  0.0',
                         'Q-CONV 5  1 0 0 %s  %s %s' % (V.fmt(-L),
                                                         V.fmt(H),
                                                         V.fmt(TINF))]
             ).run()
q = row(r, 1)
close('Q-CONV: end temperature (series conduction/convection)', q['T'],
      H * TINF / (COND / L + H), 1e-8)

GSUN, ABSORB = 1000.0, 0.6
r = bar_case('th_sun_end', ['T-PLANE 4  1 0 0 0  0.0',
                            'Q-SUN 5  1 0 0  %s %s' % (V.fmt(GSUN),
                                                       V.fmt(ABSORB))]
             ).run()
q = row(r, 1)
close('Q-SUN on the end face: T = a*G*L/k', q['T'],
      ABSORB * GSUN * L / COND, 1e-8)
sl = surface_log(r)
close('Q-SUN: illuminated area only', sl[5][0], A * B, 1e-10)

# exposed skin and sun on beam, plate and solid models of one bar
skin = 2 * LB * (BB + HB) + 2 * BB * HB
for nm, c in models('thm_skin', ['T-PLANE 4  0 1 0 0  0.0',
                                 'Q-CONV 5  0 0 0 0  %s %s' % (
                                     V.fmt(H), V.fmt(TINF))]):
    r = c.run()
    check('%s: convection runs' % nm, r.ok, r.log[-300:] if not r.ok
          else '')
    sl = surface_log(r)
    close('%s: exposed skin area' % nm, sl[5][0], skin, 1e-9)
for nm, c in models('thm_sun', ['T-PLANE 4  0 1 0 0  0.0',
                                'Q-SUN 5  0 0 1  %s %s' % (
                                    V.fmt(GSUN), V.fmt(ABSORB))]):
    r = c.run()
    check('%s: sun runs' % nm, r.ok, r.log[-300:] if not r.ok else '')
    sl = surface_log(r)
    close('%s: sun power on the top face' % nm, sl[5][1],
          ABSORB * GSUN * LB * BB, 1e-9)
for nm, c in models('thm_qend', ['T-PLANE 4  0 1 0 0  0.0',
                                 'Q-PLANE 5  0 1 0 %s  %s' % (
                                     V.fmt(-LB), V.fmt(QFLUX))]):
    r = c.run()
    close('%s: end flux gives T = q*L/k' % nm, r.points[1][37],
          QFLUX * LB / COND, 1e-7)
# ---- 7. thermal bending: linear temperature through the thickness
DTH = 40.0


def bending_models():
    pts = [(0.0, LB - 1e-7, 0.0)]
    sec = V.rect_mesh('Q9', 2, 2, -BB / 2, BB / 2, -HB / 2, HB / 2)
    yield 'beam', V.beam_case('thb_beam', sec, ['LE'] * 21, L=LB, nel=5,
                              btype='B4', nmodes=4, points=pts)
    yield 'solid', V.solid_case('thb_solid', 'H27', 5, 1, L=LB, b=BB,
                                h=HB, nx=1, nmodes=4,
                                plane_strain=False, points=pts)


for nm, c in bending_models():
    patch_t(c, [])
    c.put('BC.dat', V.bc_text([
        V.dplane(1, 0, 1, 0, 0, None, 0.0, 0.0),
        V.dplane(4, 1, 0, 0, 0, 0.0, None, None),
        'T-PLANE 2  0 0 1 %s  %s' % (V.fmt(-HB / 2), V.fmt(-DTH / 2)),
        'T-PLANE 3  0 0 1 %s  %s' % (V.fmt(HB / 2), V.fmt(DTH / 2))]))
    r = c.run()
    check('%s: thermal bending runs' % nm, r.ok,
          r.log[-300:] if not r.ok else '')
    close('%s: tip deflection alpha*dT*L^2/(2h)' % nm, r.points[0][12],
          ALPHA * DTH * LB ** 2 / (2 * HB), 3e-2)
# ---- 8. FIELDS.dat: boundary values multiplied by f(x, y, z)
c = bar_case('th_fields', ['D-PLANE 5  1 0 0 %s  %s N N  1' % (
    V.fmt(-L), V.fmt(1.0e-3)),
    'T-PLANE 6  1 0 0 0  %s  2' % V.fmt(10.0),
    'T-PLANE 7  1 0 0 %s  %s  2' % (V.fmt(-L), V.fmt(10.0))])
c.put('FIELDS.dat', '2\n\nFIELD 1 1\nY-EXP 1.0D0 1.0D0\n\nFIELD 2 2\n'
      'CONST 1.0D0\nZ-EXP 2.0D0 1.0D0\n')
r = c.run()
check('FIELDS.dat runs', r.ok, r.log[-300:] if not r.ok else '')
p = row(r, 1)
close('D-PLANE value times field y: u_x = 1e-3*y', p['u'][0],
      1.0e-3 * 0.5 * A, 1e-6)
close('T-PLANE value times field 1+2z: T = 10(1+2z)', p['T'],
      10.0 * (1.0 + 2.0 * 0.5 * B), 1e-6)
if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL THERMAL TESTS PASSED')
