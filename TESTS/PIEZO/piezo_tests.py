"""Piezoelectric tests: statics (101) and short/open-circuit modal (103).

    python TESTS/PIEZO/piezo_tests.py [path_to_MUL2_V3.exe]
"""
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    os.environ['MUL2_EXE'] = os.path.abspath(sys.argv[1])
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_piezo_runs'))
sys.path.insert(0, HERE)
import pzlib as Z  # noqa: E402

FAILED = []


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


def run_stack(circuit):
    """thickness-mode column; the stack file is shared with try2.py"""
    import importlib.util
    src = open(os.path.join(HERE, 'try2.py'), encoding='utf-8-sig').read().split('\nt = 0.01')[0]
    ns = {}
    exec(compile(src, 'try2_stack', 'exec'), ns)
    return ns['stack_case']('pz_stack_' + circuit, circuit=circuit).run()


# ---- 1. slab statics: d33, d31, E and D
d = Z.d_matrix()
volt = 100.0
r = Z.slab_case('pz_slab', 0.02, 0.02, 0.002, volt).run()
check('slab runs', r.ok, '')
p = Z.point_row(r, 0)
close('slab: free thickness strain d33*V', p['u'][2], -d[2][2] * volt, 1e-6)
close('slab: lateral strain d31*E', p['u'][0],
      0.5 * 0.02 * d[2][0] * (-volt / 0.002), 1e-6)
close('slab: electric field E = -V/t', p['E'][2], -volt / 0.002, 1e-6)
close('slab: potential at mid thickness', Z.point_row(r, 1)['volt'],
      0.5 * volt, 1e-6)

# ---- 1b. the FIELDS record of ANALYSIS.dat selects the physics
def with_fields(tag, rec):
    c = Z.slab_case('pz_fld_' + tag, 0.02, 0.02, 0.002, volt)
    c.files['ANALYSIS.dat'] += rec + '\n'
    return c.run()


rf = with_fields('piezo', 'FIELDS MECH PIEZO')
check('FIELDS MECH PIEZO runs', rf.ok, '')
close('FIELDS MECH PIEZO equals the file without the record',
      Z.point_row(rf, 0)['u'][2], p['u'][2], 1e-12)
rf = with_fields('mech', 'FIELDS MECH')
check('FIELDS MECH switches the potential off (no electromechanical '
      'deformation)', rf.ok and abs(Z.point_row(rf, 0)['u'][2]) < 1e-15, '')
for tag, rec, msg in (
        ('thermo', 'FIELDS MECH THERMO', 'NO KINEMATICS EXPANDS THE TEMPERATURE'),
        ('nomech', 'FIELDS PIEZO', 'MUST CONTAIN MECH'),
        ('rmvt', 'FIELDS MECH STRESS', 'RMVT'),
        ('typo', 'FIELDS MECH FOO', 'UNKNOWN FIELD')):
    rf = with_fields(tag, rec)
    check('%s is an error' % rec, (not rf.ok) and msg in rf.log, '')
# ---- 2. thickness vibration: short, open and floating electrode
t = 0.01
c_sc = Z.C33
c_oc = Z.C33 + Z.E33 ** 2 / Z.EPS33
f_sc = 0.25 / t * math.sqrt(c_sc / Z.RHO)
f_oc = 0.25 / t * math.sqrt(c_oc / Z.RHO)
res = {k: run_stack(k) for k in ('SC', 'OC', 'FLT')}
check('stack runs', all(x.ok for x in res.values()), '')
f_oc_ref = f_oc
# short circuit: regression value (0.18% from the transcendental solution)
close('stack: short-circuit fundamental frequency', res['SC'].freq[0],
      101434.4, 1e-4)
close('stack: open-circuit fundamental frequency', res['OC'].freq[0],
      f_oc_ref, 5e-3)
close('stack: floating electrode equals open circuit',
      res['FLT'].freq[0], res['OC'].freq[0], 1e-6)
check('stack: short circuit is softer than open circuit',
      res['SC'].freq[0] < res['OC'].freq[0], '')
check('stack: floating electrode keeps short-circuit shear modes',
      abs(res['FLT'].freq[1] - res['SC'].freq[1]) < 1e-3 * res['SC'].freq[1],
      '')

# ---- 3. the same bar as beam (1D), plate (2D) and solid (3D) models
import pzbeams as PB  # noqa: E402
models = {'beam': PB.beam, 'plate': PB.plate, 'solid': PB.solid}
v0 = 100.0
uy_ref = d[2][0] * (-v0 / PB.H) * PB.L
uz_ref = -d[2][2] * v0 / 2.0
mod = {}
for nm, fn in models.items():
    r = fn('pzb_%s_st' % nm, volt=v0).run()
    check('%s statics runs' % nm, r.ok, '')
    close('%s: free axial expansion d31*E*L' % nm, r.points[0][11], uy_ref,
          1e-5)
    close('%s: free thickness expansion d33*V/2' % nm, r.points[1][12],
          uz_ref, 1e-6)
    for circ in ('SC', 'OC', 'FLT'):
        mod[nm, circ] = fn('pzb_%s_%s' % (nm, circ), sol=103,
                           circuit=circ).run()
        check('%s modal %s runs' % (nm, circ), mod[nm, circ].ok, '')
for nm in ('beam', 'plate'):
    for k in (0, 1):
        close('%s vs solid, SC mode %d' % (nm, k + 1),
              mod[nm, 'SC'].freq[k], mod['solid', 'SC'].freq[k], 3e-2)
    # width bending (mode 2) carries E_z: open circuit is stiffer
    shift = {n: mod[n, 'OC'].freq[1] / mod[n, 'SC'].freq[1]
             for n in ('beam', 'plate', 'solid')}
    close('%s: OC/SC shift of mode 2 as in the solid' % nm, shift[nm],
          shift['solid'], 1e-2)
    check('%s: floating electrodes give the short-circuit frequencies' % nm,
          abs(mod[nm, 'FLT'].freq[1] / mod[nm, 'SC'].freq[1] - 1) < 1e-6, '')
    # bending in the thickness direction produces no net charge
    check('%s: thickness bending insensitive to the circuit' % nm,
          abs(mod[nm, 'OC'].freq[0] / mod[nm, 'SC'].freq[0] - 1) < 1e-3, '')
# ---- 4. pyroelectric slab: D = p*T (closed circuit), E = -p*T/eps^T (open)
ALPHA_PZ = [4.0e-6, 4.0e-6, 2.0e-6, 0.0, 0.0, 0.0]
P_SIGMA = 2.5e-4          # [C/m^2/K] at zero stress
THETA = 10.0
eps_t = Z.EPS33 + sum(Z.EMAT[2][k] * d[2][k] for k in range(6))


def pyro_slab(name, open_circuit):
    c = Z.slab_case(name, 0.02, 0.02, 0.002, 0.0,
                    open_circuit=open_circuit)
    c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE LE NONE NONE '
          'NONE NONE\n')
    mat = Z.material_text().split('\n')
    extra = ['T-EXP 1  ' + ' '.join(PB.V.fmt(x) for x in ALPHA_PZ),
             'T-CON 1  1.2', 'PIROE 1  0.0 0.0 %s' % PB.V.fmt(P_SIGMA)]
    c.put('MATERIAL.dat', '1 6\n\n' + '\n'.join(mat[2:6] + extra) + '\n')
    bc = c.files['BC.dat'].strip().split('\n')
    n = int(bc[0]) + 1
    c.put('BC.dat', '%d\n\n%s\nT-CONST %d  %s\n' % (
        n, '\n'.join(x for x in bc[2:] if x.strip()), n + 10,
        PB.V.fmt(THETA)))
    return c


r = pyro_slab('pyro_sc', False).run()
check('pyro closed circuit runs', r.ok, r.log[-300:] if not r.ok else '')
p = Z.point_row(r, 1)
close('pyro closed circuit: D = p*T', p['D'][2], P_SIGMA * THETA, 1e-6)
check('pyro closed circuit: no field', abs(p['E'][2]) < 1e-6 * 1e5, '')
r = pyro_slab('pyro_oc', True).run()
check('pyro open circuit runs', r.ok, r.log[-300:] if not r.ok else '')
p = Z.point_row(r, 0)
close('pyro open circuit: top voltage p*T*t/eps^T', p['volt'],
      P_SIGMA * THETA * 0.002 / eps_t, 1e-5)
if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL PIEZO TESTS PASSED')

