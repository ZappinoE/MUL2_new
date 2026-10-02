"""Extended campaign: every analysis on every element family, mixed
physics, thread invariance and the error handling of the new inputs.

    python TESTS/EXTENDED/extended_tests.py [path_to_MUL2_V3.exe]

Lines starting with KNOWN are limitations that are documented, not
failures (see the critical analysis in DOC/CRITICAL_ANALYSIS.md).
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
    tempfile.gettempdir(), 'mul2_extended_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []
E, NU, RHO = V.E0, V.NU0, V.RHO0
L, B, H = V.LB, V.BB, V.HB_
EI = E * B * H ** 3 / 12.0


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def known(name, detail):
    print('KNOWN ' + name + '  ' + detail)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


def hist(res):
    path = os.path.join(res.case_dir, 'DYNAMIC', 'TIME_HISTORY.dat')
    rows = [[float(x.replace('D', 'E')) for x in line.split()]
            for line in open(path).read().split('\n')[1:] if line.strip()]
    return rows


def freqs(res):
    path = os.path.join(res.case_dir, 'DYNAMIC', 'BUCKLING_FACTORS.dat')
    return [float(l.split(':')[1]) for l in open(path)
            if ':' in l] if os.path.exists(path) else []


sec = V.rect_mesh('Q9', 2, 2, -B / 2, B / 2, -H / 2, H / 2)
pts = [(0.0, L - 1e-6, 0.0)]

# ---------------------------------------------------------------- plate
# plane-strain strip: E' = E / (1 - nu^2), unit width (b = B)
Ep = E / (1 - NU ** 2)
EIp = Ep * B * H ** 3 / 12.0


def plate(name, **kw):
    return V.plate_case(name, 'Q9', 5, ('LE', 'B3', 1), L=L, b=B, h=H,
                        nx=1, points=pts, **kw)


r103 = plate('x_plate_modal', sol=103, nmodes=3).run()
f1 = r103.freq[0]
r101 = plate('x_plate_static', load=('shear', 1.0e6)).run()
us = r101.u()[2]
c = plate('x_plate_time', load=('shear', 1.0e6))
c.put('ANALYSIS.dat', V.analysis_text(104, 3))
T1 = 1.0 / f1
c.put('TIME_RESP.dat', '0.0 %s\n600\n1\n0\n---\n1\nSTEP 0.0 1.0\n'
      % V.fmt(3 * T1))
r = c.run()
check('plate: time response runs', r.ok, r.log[-200:] if not r.ok else '')
rows = hist(r)
uz = [(row[0], row[13]) for row in rows]
cross = [t0 + (t1 - t0) * (us - a) / (b_ - a) for (t0, a), (t1, b_)
         in zip(uz, uz[1:]) if (a - us) * (b_ - us) < 0]
close('plate: Newmark period = 103 period', cross[2] - cross[0], T1, 2e-2)

c = plate('x_plate_freq', load=('shear', 1.0e6))
c.put('ANALYSIS.dat', V.analysis_text(106, 3))
c.put('FREQ_RESP.dat', '0.0 %s\n200\n1\nRAYLEIGH %s 0.0\n' % (
    V.fmt(2 * f1), V.fmt(0.04 * 2 * math.pi * f1)))
r = c.run()
check('plate: frequency response runs', r.ok, r.log[-200:] if not r.ok
      else '')
rows = [[float(x.replace('D', 'E')) for x in line.split()]
        for line in open(os.path.join(r.case_dir, 'DYNAMIC',
                                      'FREQ_HISTORY.dat')).read().split(
                                          '\n')[1:] if line.strip()]
fpk = max(rows, key=lambda w: math.hypot(w[6], w[7]))[0]
close('plate: frequency response peaks at the 103 frequency', fpk, f1, 2e-2)

p = 1.0 * EIp / L ** 2
c = plate('x_plate_nl', load=('shear', p), sol=101)
c.put('ANALYSIS.dat', V.analysis_text(108, 3))
c.put('NL_INFO.dat', '1\n10\n30\n1.0D-8\n1\n')
r = c.run()
check('plate: nonlinear static runs', r.ok, r.log[-200:] if not r.ok
      else '')
sys.path.insert(0, os.path.join(HERE, '..', 'NONLINEAR'))
src = open(os.path.join(HERE, '..', 'NONLINEAR', 'nonlinear_tests.py')
           ).read().split('def nl_case')[0].split('def elastica')[1]
ns = {'math': math}
exec('def elastica' + src, ns)
xe, ye = ns['elastica'](1.0)
close('plate: elastica deflection (plane strain)', r.u()[2] / L, ye, 4e-2)

# ---------------------------------------------------------- Taylor + T
c = V.beam_case('x_te_thermal', V.rect_mesh('Q9', 2, 2, -B / 2, B / 2,
                                             -H / 2, H / 2), 'TE 2',
                load=('shear', 1.0), points=pts)
c.put('NODES.dat', re.sub(r'[ \t]+TE[ \t]*\d*[ \t]*$', ' 1',
                          c.files['NODES.dat'], flags=re.M))
c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  TE2 TE2 TE2 TE2 NONE NONE '
      'NONE NONE NONE\n')
c.put('MATERIAL.dat', '1 3\n\nISO-M 1  %s %s %s\nT-EXP 1  1.0D-5\n'
      'T-CON 1  100.0\n' % (V.fmt(E), V.fmt(NU), V.fmt(RHO)))
c.put('BC.dat', V.bc_text([V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
                           V.dplane(2, 0, 1, 0, -L, 0.0, None, 0.0),
                           'T-PLANE 3  0 1 0 0  10.0',
                           'T-PLANE 4  0 1 0 %s  110.0' % V.fmt(-L)]))
r = c.run()
check('Taylor expansion with a temperature field runs', r.ok,
      r.log[-200:] if not r.ok else '')
if r.ok:
    close('Taylor T field: linear temperature profile (x = 0.5 L)',
          r.points[0][37] if len(r.points[0]) > 37 else float('nan'),
          10.0 + 100.0 * (L - 1e-6) / L, 1e-6)

# ------------------------------------------------- error handling tests


def run_expect_error(name, case, text):
    r = case.run()
    check(name, (not r.ok) and text in r.log.upper(),
          'log: ' + r.log.strip().split('\n')[-2][:90])


c = V.beam_case('x_err_cond', sec, ['LE'] * 16, nel=5, btype='B4',
                load=('shear', 1.0))
c.put('NODES.dat', re.sub(r'[ \t]+(H?LE|TE)[ \t]*\d*[ \t]*$', ' 1',
                          c.files['NODES.dat'], flags=re.M))
c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE NONE '
      'NONE NONE\n')
c.put('MATERIAL.dat', '1 2\n\nISO-M 1  %s %s %s\nT-EXP 1  1.0D-5\n'
      % (V.fmt(E), V.fmt(NU), V.fmt(RHO)))
c.put('BC.dat', V.bc_text([V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
                           'T-PLANE 2  0 1 0 0  10.0']))
r = c.run()
check('temperature field without conductivity is reported', not r.ok,
      'log: ' + r.log.strip().split('\n')[-2][:100])

c = V.beam_case('x_err_103T', sec, ['LE'] * 16, nel=5, btype='B4', sol=103)
c.put('NODES.dat', re.sub(r'[ \t]+(H?LE|TE)[ \t]*\d*[ \t]*$', ' 1',
                          c.files['NODES.dat'], flags=re.M))
c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE NONE '
      'NONE NONE\n')
c.put('MATERIAL.dat', '1 3\n\nISO-M 1  %s %s %s\nT-EXP 1  1.0D-5\n'
      'T-CON 1  100.0\n' % (V.fmt(E), V.fmt(NU), V.fmt(RHO)))
run_expect_error('103 rejects the temperature field with a message', c,
                 'NOT SUPPORTED BY 103')

c = V.beam_case('x_err_bc', sec, 'LE 1', load=('shear', 1.0))
bc = c.files['BC.dat'].strip().split('\n')
bc[0] = str(int(bc[0]) + 1)
c.put('BC.dat', '\n'.join(bc) + '\nXXXX 9 0 0 0\n')
r = c.run()
check('unknown boundary record is an error', not r.ok, '')

c = V.beam_case('x_err_time', sec, 'LE 1', load=('shear', 1.0))
c.put('ANALYSIS.dat', V.analysis_text(104, 3))
r = c.run()
check('104 without TIME_RESP.dat is an error', not r.ok, '')

# -------------------------------------------------- thread invariance
c = V.beam_case('x_threads', sec, 'LE 1', load=('shear', 1.0e6),
                points=pts)
c.put('ANALYSIS.dat', V.analysis_text(108, 3))
c.put('NL_INFO.dat', '1\n4\n30\n1.0D-9\n1\n')
r1 = c.run(env={'OMP_NUM_THREADS': '1'})
r2 = c.run(env={'OMP_NUM_THREADS': '4'})
check('nonlinear: result independent of the number of threads',
      r1.ok and r2.ok and r1.u()[2] == r2.u()[2],
      '%.15e / %.15e' % (r1.u()[2], r2.u()[2]))

# ------------------------------------------ preservation of 101 / 103
c = V.beam_case('x_pres', sec, 'LE 1', load=('shear', 1.0e6), points=pts)
r_a = c.run()
cm = V.beam_case('x_pres_m', sec, 'LE 1', sol=103, nmodes=3)
r_b = cm.run()
close('preserved: static tip deflection of the beam (Timoshenko)',
      r_a.u()[2], V.timoshenko_tip(1.0e6, L, E, B * H ** 3 / 12.0,
                                   E / (2 * (1 + NU)), B * H,
                                   V.kappa_rect(NU)), 2e-2)
close('preserved: first frequency of the beam (Timoshenko)', r_b.freq[0],
      V.timoshenko_freqs(L, E, B * H ** 3 / 12.0, RHO, B * H,
                         E / (2 * (1 + NU)), V.kappa_rect(NU))[0], 3e-2)

if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL EXTENDED TESTS PASSED')
