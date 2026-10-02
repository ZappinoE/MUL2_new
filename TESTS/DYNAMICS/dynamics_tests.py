"""Time response (104): Newmark, Rayleigh damping, thermal capacity.

    python TESTS/DYNAMICS/dynamics_tests.py [path_to_MUL2_V3.exe]
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
    tempfile.gettempdir(), 'mul2_dynamics_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


def history(res, point=0):
    """[(t, row)] of POST point `point` from DYNAMIC/TIME_HISTORY.dat; row
    has the POST_POINT columns (u at 10:13, T at 37, V at 38)."""
    path = os.path.join(res.case_dir, 'DYNAMIC', 'TIME_HISTORY.dat')
    rows = []
    for line in open(path).read().split('\n')[1:]:
        tok = line.split()
        if len(tok) < 14:
            continue
        rows.append([float(x.replace('D', 'E')) for x in tok])
    npt = max(1, int(round(len(rows) / max(1, len(set(r[0] for r in rows))))))
    return [(r[0], r[1:]) for k, r in enumerate(rows) if k % npt == point]


def beam104(name, tf, nstep, loads, extra='', every=1):
    sec = V.rect_mesh('Q9', 2, 2, -V.BB / 2, V.BB / 2, -V.HB_ / 2,
                      V.HB_ / 2)
    c = V.beam_case(name, sec, 'LE 1', load=('shear', 1.0e6),
                    points=[(0.0, V.LB - 1e-6, 0.0)])
    c.put('ANALYSIS.dat', V.analysis_text(104, 4))
    c.put('TIME_RESP.dat', '0.0 %s\n%d\n%d\n0\n---\n%d\n%s\n%s\n' % (
        V.fmt(tf), nstep, every, len(loads), '\n'.join(loads), extra))
    return c


# static reference and first natural frequency of the same beam
sec = V.rect_mesh('Q9', 2, 2, -V.BB / 2, V.BB / 2, -V.HB_ / 2, V.HB_ / 2)
r0 = V.beam_case('dyn_static', sec, 'LE 1', load=('shear', 1.0e6),
                 points=[(0.0, V.LB - 1e-6, 0.0)]).run()
us = r0.u()[2]
rm = V.beam_case('dyn_modal', sec, 'LE 1', sol=103, nmodes=3).run()
f1 = rm.freq[0]
T1 = 1.0 / f1
print('static tip %.6e, f1 = %.4f Hz' % (us, f1))

# ---- 1. step load, undamped: u = us (1 - cos w t) for the first mode
TF = 3.0 * T1
r = beam104('dyn_step', TF, 600, ['STEP 0.0 1.0']).run()
check('step response runs', r.ok, r.log[-300:] if not r.ok else '')
h = history(r)
uz = [(t, row[12]) for t, row in h]
peak = max(uz, key=lambda p: abs(p[1]))
close('step: peak is twice the static deflection', abs(peak[1]), 2 * abs(us),
      6e-2)
# period from the zero crossings of u - u_static (insensitive to the
# higher modes, which only shift the position of the first maximum)
cross = []
for (t0, a), (t1, b) in zip(uz, uz[1:]):
    if (a - us) * (b - us) < 0:
        cross.append(t0 + (t1 - t0) * (us - a) / (b - a))
close('step: period of mode 1 from the zero crossings',
      cross[2] - cross[0], T1, 1.5e-2)
mean = sum(v for _, v in uz) / len(uz)
close('step: mean of the oscillation is the static deflection', mean, us,
      5e-2)

# ---- 2. Rayleigh damping (mass proportional): overshoot exp(-pi z/...)
zeta = 0.05
alpha = 2 * zeta * 2 * math.pi * f1
r = beam104('dyn_ray', 3.0 * T1, 900, ['STEP 0.0 1.0'],
            'RAYLEIGH %s 0.0' % V.fmt(alpha)).run()
h = history(r)
uz = [(t, row[12]) for t, row in h]
over = (max(abs(v) for _, v in uz[: len(uz) // 2]) - abs(us)) / abs(us)
ref = math.exp(-math.pi * zeta / math.sqrt(1 - zeta ** 2))
close('Rayleigh: first overshoot exp(-pi z/sqrt(1-z^2))', over, ref, 8e-2)

# ---- 3. slow ramp: quasi-static response a(t) * u_s
r = beam104('dyn_ramp', 40.0 * T1, 800, ['RAMP 0.0 %s 1.0' % V.fmt(
    30.0 * T1)]).run()
h = history(r)
uz = [(t, row[12]) for t, row in h]
close('ramp: final value is the static deflection', uz[-1][1], us, 3e-2)
mid = [v for t, v in uz if abs(t - 15.0 * T1) < 0.3 * T1]
close('ramp: half way the deflection is half the static one',
      sum(mid) / len(mid), 0.5 * us, 5e-2)

# ---- 4. transient heat conduction with thermal capacity
KC, RHO, CP, LEN = 100.0, 2700.0, 900.0, 1.0
ALPHA_TH = KC / (RHO * CP)
TH1 = 50.0


def series(x, t, terms=60):
    s = 0.0
    for n in range(terms):
        lam = (2 * n + 1) * math.pi / (2 * LEN)
        s += (4.0 / ((2 * n + 1) * math.pi)) * math.sin(lam * x) * \
            math.exp(-lam * lam * ALPHA_TH * t)
    return TH1 * (1.0 - s)


def heat_case(name, tf, nstep, theta, nel=20):
    c = V.Case(name)
    H8 = V.H_PATTERN['H8'][1]
    A = B = 0.05
    nid = lambda i, j, k: i + (nel + 1) * (j + 2 * k) + 1
    lines = ['%d' % (4 * (nel + 1)), '']
    for k in range(2):
        for j in range(2):
            for i in range(nel + 1):
                lines.append('%d %s %s %s 1' % (
                    nid(i, j, k), V.fmt(LEN * i / nel), V.fmt(A * j),
                    V.fmt(B * k)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE '
          'NONE NONE NONE\n')
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [nid(e + i - 1, j - 1, k - 1) for (i, j, k) in H8]
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
    c.put('POSTPROCESSING.dat', V.post_text([(LEN - 1e-9, 0.5 * A, 0.5 * B),
                                             (0.5 * LEN, 0.5 * A,
                                              0.5 * B)]))
    c.put('TIME_RESP.dat', '0.0 %s\n%d\n%d\n0\n---\n1\nSTEP 0.0 1.0\n'
          'THETA %s\n' % (V.fmt(tf), nstep, nstep // 10, V.fmt(theta)))
    return c


TF = 8000.0
r = heat_case('dyn_heat', TF, 800, 1.0).run()
check('transient heat runs', r.ok, r.log[-300:] if not r.ok else '')
h = history(r, 0)
for t_check in (2000.0, 4000.0, 8000.0):
    t, row = min(h, key=lambda p: abs(p[0] - t_check))
    close('heat: insulated end T(L, %g s) of the series solution'
          % t_check, row[37], series(LEN, t), 3e-2)
r = heat_case('dyn_heat_cn', TF, 400, 0.5).run()
h = history(r, 0)
t, row = min(h, key=lambda p: abs(p[0] - 4000.0))
close('heat: Crank-Nicolson at 4000 s', row[37], series(LEN, t), 2e-2)

# ---- 5. thermoelastic damping: two-way coupling with T0 > 0
sys.path.insert(0, os.path.join(HERE, '..', 'PIEZO'))
import pzlib as Z  # noqa: E402


def ted_case(name, t0):
    sec = V.rect_mesh('Q9', 2, 2, -V.BB / 2, V.BB / 2, -V.HB_ / 2,
                      V.HB_ / 2)
    nn = 3 * 5 + 1
    c = V.beam_case(name, sec, ['LE'] * nn, load=('shear', 1.0e6),
                    btype='B4', points=[(0.0, V.LB - 1e-6, 0.0)])
    c.put('NODES.dat', re.sub(r'[ \t]+(H?LE|TE)[ \t]*\d*[ \t]*$', ' 1',
                              c.files['NODES.dat'], flags=re.M))
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE '
          'NONE NONE NONE\n')
    c.put('MATERIAL.dat', '1 4\n\nISO-M 1  70.0D9 0.3 2700.0\n'
          'T-EXP 1  5.0D-5\nT-CON 1  4.0D6\nT-SPC 1  300.0\n')
    c.put('ANALYSIS.dat', V.analysis_text(104, 4))
    extra = 'T0 %s\n' % V.fmt(t0) if t0 > 0 else ''
    c.put('TIME_RESP.dat', '0.0 %s\n600\n1\n0\n---\n1\nSTEP 0.0 1.0\n%s'
          % (V.fmt(3.0 * T1), extra))
    return c


peaks = {}
for t0 in (0.0, 300.0):
    r = ted_case('dyn_ted_%d' % int(t0), t0).run()
    check('thermoelastic run T0=%g' % t0, r.ok,
          r.log[-300:] if not r.ok else '')
    h = history(r)
    uz = [(t, row[12]) for t, row in h]
    up = [abs(b[1] - us) for a, b, c in zip(uz, uz[1:], uz[2:])
          if b[1] > a[1] and b[1] > c[1]]
    peaks[t0] = up
check('TED: no damping without T0 (Newmark conserves energy)',
      peaks[0.0][2] > 0.985 * peaks[0.0][0], '')
check('TED: the coupled problem damps the vibration',
      peaks[300.0][2] < 0.95 * peaks[300.0][0],
      'peak ratio %.4f (undamped %.4f)' % (
          peaks[300.0][2] / peaks[300.0][0],
          peaks[0.0][2] / peaks[0.0][0]))

# ---- 6. piezoelectric actuation with a sinusoidal voltage
r_s = Z.slab_case('dyn_pz_static', 0.02, 0.02, 0.002, 100.0).run()
us_pz = Z.point_row(r_s, 0)['u'][2]
c = Z.slab_case('dyn_pz_time', 0.02, 0.02, 0.002, 100.0)
c.put('ANALYSIS.dat', V.analysis_text(104, 4, solid='NONE'))
OMEGA = 200.0
c.put('TIME_RESP.dat', '0.0 0.05\n500\n10\n0\n---\n1\nSINU 0.0 %s 1.0\n'
      % V.fmt(OMEGA))
r = c.run()
check('piezo time response runs', r.ok, r.log[-300:] if not r.ok else '')
h = history(r)
worst = max(abs(row[12] / us_pz - math.sin(OMEGA * t)) for t, row in h)
check('piezo: quasi-static response d33 V sin(w t)', worst < 2e-3,
      'worst error %.2e' % worst)
# ---- 7. harmonic response (106): static limit, resonance and damping
zeta = 0.02
alpha = 2 * zeta * 2 * math.pi * f1
c = V.beam_case('frq_beam', sec, 'LE 1', load=('shear', 1.0e6),
                points=[(0.0, V.LB - 1e-6, 0.0)])
c.put('ANALYSIS.dat', V.analysis_text(106, 4))
c.put('FREQ_RESP.dat', '0.0 %s\n400\n1\nRAYLEIGH %s 0.0\n' % (
    V.fmt(2.0 * f1), V.fmt(alpha)))
r = c.run()
check('frequency response runs', r.ok, r.log[-300:] if not r.ok else '')
rows = [[float(x.replace('D', 'E')) for x in line.split()]
        for line in open(os.path.join(r.case_dir, 'DYNAMIC',
                                      'FREQ_HISTORY.dat')).read().split(
                                          '\n')[1:] if line.strip()]
amp = [(row[0], math.hypot(row[6], row[7])) for row in rows]
close('frequency response: static limit at f = 0', amp[0][1], abs(us), 5e-3)
fpeak, apeak = max(amp, key=lambda p: p[1])
close('frequency response: resonance at the first natural frequency',
      fpeak, f1, 1e-2)
ratio = apeak / abs(us) * 2 * zeta
check('frequency response: resonance amplitude ~ 1/(2 zeta)',
      0.9 < ratio < 1.06, 'ratio %.3f' % ratio)
at = min(rows, key=lambda row: abs(row[0] - fpeak))
check('frequency response: quadrature phase at resonance',
      abs(at[6]) < 0.15 * abs(at[7]), 'Re/Im = %.3f' % (at[6] / at[7]))
# ---- 8. piezoelectric resonance with a voltage excitation (106)
src = open(os.path.join(HERE, '..', 'PIEZO', 'try2.py'),
           encoding='utf-8-sig').read().split('\nt = 0.01')[0]
ns = {}
exec(compile(src, 'try2_stack', 'exec'), ns)
c = ns['stack_case']('frq_stack', circuit='SC', volt=1.0)
c.put('ANALYSIS.dat', V.analysis_text(106, 4, solid='NONE'))
c.put('FREQ_RESP.dat', '80000.0 125000.0\n450\n1\nRAYLEIGH 0.0 3.0D-9\n')
c.put('POSTPROCESSING.dat', V.post_text([(0.005, 0.005, 0.01 - 1e-9)]))
r = c.run()
check('piezo stack frequency response runs', r.ok,
      r.log[-300:] if not r.ok else '')
rows = [[float(x.replace('D', 'E')) for x in line.split()]
        for line in open(os.path.join(r.case_dir, 'DYNAMIC',
                                      'FREQ_HISTORY.dat')).read().split(
                                          '\n')[1:] if line.strip()]
amp = [(row[0], math.hypot(row[6], row[7])) for row in rows]
fpk, _ = max(amp, key=lambda p: p[1])
close('piezo stack: voltage-driven resonance = short-circuit frequency',
      fpk, 101434.4, 1e-2)

# ---- 9. sun and convection on a thermally lumped bar (capacity)
KBIG, HCONV, GS, AB = 1.0e6, 10.0, 1000.0, 0.6
LB_, AB_ = 1.0, 0.05


def sun_case(name):
    c = V.Case(name)
    nel = 4
    H8 = V.H_PATTERN['H8'][1]
    nid = lambda i, j, k: i + (nel + 1) * (j + 2 * k) + 1
    lines = ['%d' % (4 * (nel + 1)), '']
    for k in range(2):
        for j in range(2):
            for i in range(nel + 1):
                lines.append('%d %s %s %s 1' % (
                    nid(i, j, k), V.fmt(LB_ * i / nel), V.fmt(AB_ * j),
                    V.fmt(AB_ * k)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE '
          'NONE NONE NONE\n')
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [nid(e + i - 1, j - 1, k - 1) for (i, j, k) in H8]
        el.append('H8 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', V.analysis_text(104, 4, solid='NONE'))
    c.put('MATERIAL.dat', '1 3\n\nISO-M 1  70.0D9 0.3 %s\nT-CON 1  %s\n'
          'T-SPC 1  %s\n' % (V.fmt(RHO), V.fmt(KBIG), V.fmt(CP)))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    c.put('BC.dat', V.bc_text([
        V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
        V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
        V.dplane(3, 0, 0, 1, 0, None, None, 0.0),
        'Q-SUN 4  0 0 1  %s %s' % (V.fmt(GS), V.fmt(AB)),
        'Q-CONV 5  0 0 0 0  %s 0.0' % V.fmt(HCONV)]))
    c.put('POSTPROCESSING.dat', V.post_text([(0.5 * LB_, 0.5 * AB_,
                                              0.5 * AB_)]))
    c.put('TIME_RESP.dat', '0.0 9000.0\n300\n10\n0\n---\n1\n'
          'STEP 0.0 1.0\n')
    return c


r = sun_case('dyn_sun').run()
check('sun and convection transient runs', r.ok,
      r.log[-300:] if not r.ok else '')
skin = 2 * LB_ * (2 * AB_) + 2 * AB_ * AB_
tau = RHO * CP * LB_ * AB_ * AB_ / (HCONV * skin)
tss = AB * GS * LB_ * AB_ / (HCONV * skin)
h = history(r)
worst = max(abs(row[37] - tss * (1 - math.exp(-t / tau))) / tss
            for t, row in h)
check('lumped bar: T(t) = a G A (1 - exp(-t/tau)) / (h S)', worst < 1.5e-2,
      'worst relative error %.2e (steady %.3f K, tau %.0f s)' % (
          worst, tss, tau))
if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL DYNAMICS TESTS PASSED')
