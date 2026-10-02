"""Timing of the phases of every analysis on a medium beam model.

    python TESTS/EXTENDED/perf_probe.py [path_to_MUL2_V3.exe] [nel] [mesh]

Prints the wall time of assembly, solution and output for 101, 103, 104,
105 (small), 106 and 108 so that optimisations can be compared.
"""
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
args = [a for a in sys.argv[1:]]
if args and args[0].lower().endswith('.exe'):
    os.environ['MUL2_EXE'] = os.path.abspath(args.pop(0))
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_perf_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

NEL = int(args[0]) if args else 20
MESH = int(args[1]) if len(args) > 1 else 3
L, B, H = V.LB, V.BB, V.HB_
sec = V.rect_mesh('Q9', MESH, MESH, -B / 2, B / 2, -H / 2, H / 2)
pts = [(0.0, L - 1e-6, 0.0)]


def case(name, sol, nmodes=4):
    c = V.beam_case(name, sec, 'LE 1', load=('shear', 1.0e5), nel=NEL,
                    points=pts)
    c.put('ANALYSIS.dat', V.analysis_text(sol, nmodes))
    return c


def report(name, r):
    t = re.search(r'TIMES \[S\] INPUT/PRE/ANALYSIS/OUT:\s+(\S+)\s+(\S+)\s+'
                  r'(\S+)\s+(\S+)', r.log)
    a = re.search(r'K,?M? ?ASSEMBLED: (\d+) DOF.*?([\d.]+) S', r.log)
    print('%-22s ok=%s dof=%s  assembly=%s  pre=%s analysis=%s output=%s '
          'wall=%.1f' % (name, r.ok, r.ndof, a.group(2) if a else '-',
                         t.group(2) if t else '-', t.group(3) if t else '-',
                         t.group(4) if t else '-', r.wall))


report('101 static', case('pf_101', 101).run())
report('103 modal (8 modes)', case('pf_103', 103, 8).run())
c = case('pf_104', 104)
c.put('TIME_RESP.dat', '0.0 0.2\n50\n10\n0\n---\n1\nSTEP 0.0 1.0\n')
report('104 time 50 steps', c.run())
if os.environ.get('PERF_FAST') != '1':
    c = case('pf_106', 106)
    c.put('FREQ_RESP.dat', '1.0 40.0\n10\n1\n')
    report('106 11 frequencies', c.run())
    c = case('pf_108', 108)
    c.put('NL_INFO.dat', '1\n3\n30\n1.0D-8\n1\n')
    report('108 nonlinear 3 steps', c.run())
report('105 buckling', case('pf_105', 105, 3).run()
       if NEL * MESH * MESH < 40 else type('R', (), dict(
           ok=False, ndof=0, log='skipped (dense)', wall=0))())
