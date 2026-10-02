"""Run ctest in the Release and Debug configurations and store the result
in results/regression.json (used by the report)."""
import json
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
BUILD = os.path.join(ROOT, 'BUILD', 'WINDOWS_IFX')
ONEAPI = r'C:\Program Files (x86)\Intel\oneAPI'

DESC = {
    'MUL2_BASE_TESTS': 'base unit tests of the modules',
    'MUL2_TESTS': 'unit tests (shape functions, quadrature, materials, '
                  'frames, kernels, assembly, readers)',
    'MUL2_HLE_TESTS': 'unit tests of the HLE modules',
    'MUL2_SMOKE_TEST': 'start-up smoke test of the executable',
    'MUL2_PARDISO_TEST': 'PARDISO against an analytic 2x2 system',
    'MUL2_ANALYSIS_TEST': 'frozen-baseline comparison (101/103, beam, '
                          'plate, solid, mixed, patch tests, threads)',
    'MUL2_HLE_SOLVER_TESTS': 'HLE at solver level',
    'MUL2_REDUCED_TESTS': 'reduced and selective integration, locking',
    'MUL2_PIEZO_TESTS': 'piezoelectric and pyroelectric fields',
    'MUL2_EXTENDED_TESTS': 'dynamics, frequency response, thermal and '
                           'thermoelastic fields',
    'MUL2_NONLINEAR_TESTS': 'nonlinear statics, load control and arc length',
    'MUL2_CURVED_TESTS': 'curved beams and shells, tubes, joints',
    'MUL2_JOIN_TESTS': 'joining of the DOFs by coincidence',
    'MUL2_BUCKLING_TESTS': 'linear and thermal buckling',
    'MUL2_DYNAMICS_TESTS': 'time response, damping, heat transient',
    'MUL2_THERMAL_TESTS': 'temperature field, heat loads, thermal stress',
}


def run(cfg, only=None):
    env = dict(os.environ)
    env['PATH'] = os.pathsep.join([ONEAPI + r'\mkl\2025.0\bin',
                                   ONEAPI + r'\compiler\2025.0\bin',
                                   env['PATH']])
    cmd = ['ctest', '--test-dir', BUILD, '-C', cfg, '--timeout', '1800', '-V']
    if only:
        cmd += ['-R', only]
    p = subprocess.run(cmd, capture_output=True, text=True, env=env)
    rows = []
    for m in re.finditer(r'Test\s+#\d+:\s+(\S+)\s+\.+\s*\**\s*(Passed|Failed|'
                         r'Timeout|\*\*\*\w+)\s+([\d.]+) sec', p.stdout):
        rows.append(('%s [%s] - %s' % (m.group(1), cfg, DESC.get(
            m.group(1), '')), 'PASSED' if m.group(2) == 'Passed' else
            'FAILED', m.group(3)))
    # the PASS / FAIL lines of every suite ("<n>: PASS  text  detail")
    names = {}
    for m in re.finditer(r'Start\s+(\d+): (\S+)', p.stdout):
        names[m.group(1)] = m.group(2)
    checks = {}
    for m in re.finditer(r'^(\d+): (PASS|FAIL)\s+(.*)$', p.stdout, re.M):
        line = m.group(3).rstrip()
        parts = re.split(r'\s{2,}', line, maxsplit=1)
        checks.setdefault(names.get(m.group(1), m.group(1)), []).append(
            [m.group(2), parts[0], parts[1] if len(parts) > 1 else ''])
    return rows, p.stdout, checks


def main():
    rows = []
    r, out, checks = run('Release')
    rows += r
    print(out[-300:])
    # Debug (full run-time checks): the suites that exercise the newest code
    r, out, _ = run('Debug', 'BASE|NONLINEAR|CURVED|JOIN')
    rows += r
    print(out[-300:])
    os.makedirs(os.path.join(HERE, 'results'), exist_ok=True)
    json.dump(dict(rows=rows, checks=checks), open(os.path.join(
        HERE, 'results', 'regression.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
