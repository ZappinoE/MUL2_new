"""Tests of the reduced (REDI) and selective (SELI) integration and of the
ANALYSIS.dat format without the solver record.

    python TESTS/REDUCED/reduced_tests.py [path_to_MUL2_V3.exe]

The comparison with the frozen baseline (displacements, stresses and
frequencies of beam and plate, REDI and SELI) is part of MUL2_ANALYSIS_TEST.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
if len(sys.argv) > 1:
    os.environ['MUL2_EXE'] = os.path.abspath(sys.argv[1])
import tempfile  # noqa: E402
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_reduced_runs'))
import vlib as V  # noqa: E402

FAILED = []
E, B, H, L = V.E0, V.BB, V.HB_, V.LB
I = B * H ** 3 / 12.0


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


sec9 = V.rect_mesh('Q9', 2, 2, -B / 2, B / 2, -H / 2, H / 2)
D0 = 1.0e-3

# ---- 1. ANALYSIS.dat without the solver record, and the historical one
c = V.beam_case('rt_fmt_new', sec9, 'LE 1', load=('shear', 1e6))
r_new = c.run()
c = V.beam_case('rt_fmt_old', sec9, 'LE 1', load=('shear', 1e6))
c.put('ANALYSIS.dat', '101\n\n100 !! NOT USED\n\n8 modes\n\nMITC\nMITC\n'
      'NONE\n')
r_old = c.run()
check('ANALYSIS.dat: both formats run', r_new.ok and r_old.ok, '')
close('ANALYSIS.dat: historical format gives the same result',
      r_old.u()[2], r_new.u()[2], 1e-13)
warn = os.path.join(r_old.case_dir, 'REPORT', 'WARNING_file.dat')
text = open(warn).read() if os.path.exists(warn) else ''
check('ANALYSIS.dat: the obsolete solver record is reported',
      'OBSOLETE' in text.upper(), '')
c = V.beam_case('rt_fmt_bad', sec9, 'LE 1')
c.put('ANALYSIS.dat', '101\n\n8 modes\n\nMITC\nXXXX\nNONE\n')
check('ANALYSIS.dat: unknown shear token is an error', not c.run().ok, '')

# ---- 2. patch test and pure bending with REDI / SELI
for sh in ('REDI', 'SELI'):
    r = V.beam_case('rt_pb_' + sh, sec9, 'LE 1', nu=0.0, shear=sh,
                    load=('axial_disp', D0),
                    points=[(0.1, 5.0, 0.2)]).run()
    close('beam %s: uniform extension' % sh, r.u()[1], D0 * 5.0 / L, 1e-9)
    r = V.beam_case('rt_bb_' + sh, sec9, 'LE 1', nu=0.0, shear=sh,
                    load=('moment', 1e6, I),
                    points=[(0.0, L - 1e-6, 0.0)]).run()
    ex = 1e6 * (L - 1e-6) ** 2 / (2 * E * I)
    close('beam %s: pure bending is exact' % sh, r.u()[2], ex, 1e-6)
    r = V.plate_case('rt_pp_' + sh, 'Q9', 8, ('LE', 'B3', 2), nu=0.0,
                     shear=sh, load=('axial_disp', D0),
                     points=[(0.1, 5.0, 0.2)]).run()
    close('plate %s: uniform extension' % sh, r.u()[1], D0 * 5.0 / L, 1e-9)
    if sh == 'SELI':
        r = V.solid_case('rt_ps_' + sh, 'H27', 5, 1, nu=0.0, shear=sh,
                         load=('axial_disp', D0),
                         points=[(0.1, 5.0, 0.2)]).run()
        close('solid H27 SELI: uniform extension', r.u()[1], D0 * 5.0 / L,
              1e-9)
    else:
        r = V.solid_case('rt_ps_' + sh, 'H27', 5, 1, nu=0.0, shear=sh,
                         load=('axial_disp', D0),
                         points=[(0.1, 5.0, 0.2)])
        res = r.run()
        wf = os.path.join(res.case_dir, 'REPORT', 'WARNING_file.dat')
        wt = open(wf).read().upper() if os.path.exists(wf) else ''
        check('solid H27 REDI: the hourglass modes are announced',
              'HOURGLASS' in wt, '')

# ---- 3. locking relief of slender beams and plates
ht = 0.1
tw = 1.0e-3
secs = V.rect_mesh('Q9', 1, 1, -ht / 2, ht / 2, -ht / 2, ht / 2)
Ib = ht ** 4 / 12.0
G = E / (2 * (1 + V.NU0))
w_ref = V.timoshenko_tip(1.0, L, E, Ib, G, ht * ht, V.kappa_rect(V.NU0))
ratio = {}
for sh in ('NONE', 'REDI', 'SELI', 'MITC'):
    r = V.beam_case('rt_lk_' + sh, secs, 'LE 1', btype='B2', nel=12,
                    shear=sh, load=('shear', 1.0)).run()
    ratio[sh] = r.u()[2] / w_ref
check('slender B2 beam: full integration locks', ratio['NONE'] < 0.2,
      'ratio %.3f' % ratio['NONE'])
for sh in ('REDI', 'SELI'):
    check('slender B2 beam: %s removes the locking' % sh,
          0.9 < ratio[sh] < 1.05, 'ratio %.3f' % ratio[sh])
Ep = E / (1 - V.NU0 ** 2)
Ih = ht ** 3 / 12.0
w_pl = V.timoshenko_tip(1.0e3 / 1.0, L, Ep, Ih, G, ht, 5 / 6.)
rp = {}
for sh in ('NONE', 'SELI'):
    r = V.plate_case('rt_pl_' + sh, 'Q4', 16, ('LE', 'B3', 1), h=ht,
                     shear=sh, load=('shear', 1.0e3)).run()
    rp[sh] = r.u()[2] / w_pl
check('slender Q4 plate: full integration locks', rp['NONE'] < 0.2,
      'ratio %.3f' % rp['NONE'])
check('slender Q4 plate: SELI removes the locking',
      0.9 < rp['SELI'] < 1.05, 'ratio %.3f' % rp['SELI'])

# ---- 4. REDI modal analysis (singular mass): dense and ARPACK paths
small = V.plate_case('rt_modal_small', 'Q9', 2, ('LE', 'B3', 1), sol=103,
                     nmodes=4, shear='REDI').run()
check('REDI modal (dense solver) gives finite positive frequencies',
      small.ok and len(small.freq) >= 4 and all(f > 0 for f in small.freq),
      str(small.freq[:3]))
big = V.plate_case('rt_modal_big', 'Q9', 10, ('LE', 'B4', 1), sol=103,
                   nmodes=4, shear='REDI').run()
ref = V.plate_case('rt_modal_ref', 'Q9', 10, ('LE', 'B4', 1), sol=103,
                   nmodes=4, shear='NONE').run()
check('REDI modal (%d DOF) runs' % big.ndof, big.ok and len(big.freq) >= 4,
      str(big.freq[:3]))
if big.ok and ref.ok:
    close('REDI f1 close to the full integration', big.freq[0],
          ref.freq[0], 0.03)

if FAILED:
    print('FAILED:', FAILED)
    sys.exit(1)
print('all reduced-integration checks passed')
