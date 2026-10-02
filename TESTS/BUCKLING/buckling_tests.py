"""Linear buckling (105): Euler columns, mechanical and thermal loads.

    python TESTS/BUCKLING/buckling_tests.py [path_to_MUL2_V3.exe]
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
    tempfile.gettempdir(), 'mul2_buckling_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []
E, NU, RHO = V.E0, V.NU0, V.RHO0
L, B, H = V.LB, V.BB, V.HB_
I_SEC = B * H ** 3 / 12.0
A_SEC = B * H


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


def factors(res):
    path = os.path.join(res.case_dir, 'DYNAMIC', 'BUCKLING_FACTORS.dat')
    out = []
    if os.path.exists(path):
        for line in open(path):
            if ':' in line:
                out.append(float(line.split(':')[1]))
    return out


def run105(case, nmodes=4):
    case.put('ANALYSIS.dat', V.analysis_text(105, nmodes))
    res = case.run()
    res.lam = factors(res)
    return res


P_REF = 1.0e6
P_EULER = math.pi ** 2 * E * I_SEC / (4.0 * L ** 2)     # cantilever

# ---- 1. cantilever beam under an axial force at the tip
sec = V.rect_mesh('Q9', 2, 2, -B / 2, B / 2, -H / 2, H / 2)
c = V.beam_case('bk_beam', sec, 'LE 1', load=('axial_force', -P_REF),
                nel=5, bc='clamp')
r = run105(c)
check('beam buckling runs', r.ok and len(r.lam) >= 3,
      r.log[-300:] if not r.ok else '')
close('cantilever beam: first load factor = Euler load', r.lam[0] * P_REF,
      P_EULER, 3e-2)
close('cantilever beam: the two bending planes are degenerate', r.lam[1],
      r.lam[0], 1e-3)
kga = V.kappa_rect(NU) * E / (2 * (1 + NU)) * A_SEC
shear = lambda n: n * n * P_EULER / (1.0 + n * n * P_EULER / kga)
close('cantilever beam: third factor with the Timoshenko shear term',
      r.lam[2] * P_REF, shear(3), 1.5e-2)

# ---- 2. the same column as a solid (3D) model
c = V.solid_case('bk_solid', 'H27', 5, 1, L=L, b=B, h=H, nx=1, sol=101,
                 plane_strain=False)
w1 = [1.0 / 6, 4.0 / 6, 1.0 / 6]                 # 1D Q2 consistent weights
recs = c.files['BC.dat'].strip().split('\n')[2:]
recs = [x for x in recs if x.strip()]
nodes = c.files['NODES.dat'].strip().split('\n')[2:]
for line in nodes:
    tok = [float(s.replace('D', 'E')) for s in line.split()[1:4]]
    x, y, z = tok
    if abs(y - L) < 1e-12:
        i = int(round((x + B / 2) / (B / 2)))
        k = int(round((z + H / 2) / (H / 2)))
        recs.append('F-POINT %d  %s %s %s  0.0 %s 0.0' % (
            len(recs) + 1, V.fmt(x), V.fmt(y), V.fmt(z),
            V.fmt(-P_REF * w1[i] * w1[k])))
c.put('BC.dat', V.bc_text(recs))
r = run105(c)
check('solid buckling runs', r.ok and len(r.lam) >= 1,
      r.log[-300:] if not r.ok else '')
close('cantilever solid: first load factor = Euler load', r.lam[0] * P_REF,
      P_EULER, 5e-2)

# ---- 3. thermal buckling of a clamped-clamped bar
ALPHA = 1.0e-5
dT_cr = 4.0 * math.pi ** 2 * I_SEC / (ALPHA * A_SEC * L ** 2)
c = V.beam_case('bk_thermal', sec, ['LE'] * 16, nel=5, btype='B4',
                sol=101)
c.put('NODES.dat', re.sub(r'[ \t]+(H?LE|TE)[ \t]*\d*[ \t]*$', ' 1',
                          c.files['NODES.dat'], flags=re.M))
c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE NONE '
      'NONE NONE\n')
c.put('MATERIAL.dat', '1 3\n\nISO-M 1  %s %s %s\nT-EXP 1  %s\n'
      'T-CON 1  100.0\n' % (V.fmt(E), V.fmt(NU), V.fmt(RHO),
                            V.fmt(ALPHA)))
c.put('BC.dat', V.bc_text([
    V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
    V.dplane(2, 0, 1, 0, -L, 0.0, 0.0, 0.0),
    'T-CONST 3  1.0']))
r = run105(c)
check('thermal buckling runs', r.ok and len(r.lam) >= 1,
      r.log[-300:] if not r.ok else '')
P_CC = 4.0 * math.pi ** 2 * E * I_SEC / L ** 2
P_CC_T = P_CC / (1.0 + P_CC / kga)          # with the shear term
close('clamped-clamped bar: critical temperature rise (Timoshenko)',
      r.lam[0] * E * ALPHA * A_SEC, P_CC_T, 6e-2)

# ---- 4. clamped-clamped column under a prescribed axial displacement
c = V.beam_case('bk_cc', sec, 'LE 1', load=('axial_disp', -1.0e-3),
                nel=5)
r = run105(c)
close('clamped-clamped beam: critical axial displacement (Timoshenko)',
      r.lam[0] * 1.0e-3 / L * E * A_SEC, P_CC_T, 3e-2)

if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL BUCKLING TESTS PASSED')
