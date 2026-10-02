"""Joining by coincidence of the degrees of freedom (`JOIN COINCIDENT`).

    python TESTS/JOIN/join_tests.py [path_to_MUL2_V3.exe]

A cantilever of two segments with LE sections: the structural nodes of the
second segment are *shifted* with respect to the first and its section mesh
is shifted back, so that the section nodes coincide in space but the nodes
of the two segments at the junction are different. The reference is the
same beam with a shared node.
"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
if len(sys.argv) > 1:
    os.environ['MUL2_EXE'] = os.path.abspath(sys.argv[1])
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_join_runs'))
sys.path.insert(0, os.path.join(ROOT, 'TESTS', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


H = 0.05            # half side of the square section
L, NEL = 1.0, 4    # length, B3 elements (two per segment)
P = 1000.0
DX, DZ = 0.03, 0.02


def reference():
    sec = V.rect_mesh('Q9', 1, 1, -H, H, -H, H)
    c = V.beam_case('join_ref', sec, 'LE 1', L=L, nel=NEL, btype='B3',
                    load=('shear', P), points=[(0.0, L - 1e-6, 0.0)])
    return c.run()


def two_segments(name, record, dx=DX, dz=DZ):
    s1 = V.rect_mesh('Q9', 1, 1, -H, H, -H, H)
    s2 = V.rect_mesh('Q9', 1, 1, -H - dx, H - dx, -H - dz, H - dz)
    n_half = NEL                           # nodes per segment (B3: 2e+1)
    coords = [(0.0, 0.5 * L * i / (n_half), 0.0) for i in range(n_half + 1)]
    coords += [(dx, 0.5 * L + 0.5 * L * i / n_half, dz)
               for i in range(n_half + 1)]
    c = V.Case(name)
    nt, _ = V.kin_nodes_text(coords, 'LE 1')
    c.put('NODES.dat', nt)
    el = ['%d' % NEL, '']
    for seg in range(2):
        for e in range(NEL // 2):
            ids = [seg * (n_half + 1) + 2 * e + a + 1 for a in range(3)]
            el.append('B3 %d  %s  1  %d' % (seg * (NEL // 2) + e + 1,
                                            ' '.join(map(str, ids)),
                                            seg + 1))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', V.analysis_text(101, 4) + record)
    c.put('MATERIAL.dat', V.material_text())
    c.put('LAMINATION.dat', V.LAM_TEXT)
    for k, s in enumerate((s1, s2)):
        c.put('EXP_MESH_%02d.dat' % (k + 1), s.mesh_text(True))
        c.put('EXP_CONN_%02d.dat' % (k + 1), s.conn_text())
    recs = [V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0)]
    w = s1.consistent(lambda u, v: 1.0 / s1.area())
    for i in sorted(w):
        if abs(w[i]) > 1e-14:
            x, z = s1.nodes[i]
            recs.append(V.fpoint(len(recs) + 1, x, L, z, 0.0, 0.0,
                                 P * w[i]))
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text([(0.0, L - 1e-6, 0.0)]))
    return c


ref = reference()
check('reference beam runs', ref.ok, ref.log[-200:] if not ref.ok else '')
u_ref = ref.u()[2]

r = two_segments('join_on', 'JOIN COINCIDENT\n').run()
check('JOIN COINCIDENT runs', r.ok, r.log[-300:] if not r.ok else '')
check('the number of joined DOFs is announced',
      'JOINED BY COINCIDENCE' in r.log, '')
e = abs(r.u()[2] - u_ref) / abs(u_ref)
check('two segments with shifted nodes = beam with a shared node', e < 1e-9,
      'relative difference %.2e (tol 1e-09)' % e)

r = two_segments('join_tol', 'JOIN COINCIDENT 1.0e-4\n').run()
e = abs(r.u()[2] - u_ref) / abs(u_ref) if r.ok else 1.0
check('explicit tolerance', r.ok and e < 1e-9, 'relative difference %.2e' % e)

r = two_segments('join_off', '').run()
e = abs(r.u()[2] - u_ref) / abs(u_ref) if r.ok else 1.0
check('without the record the segments are not joined',
      (not r.ok) or e > 0.5, 'run ok %s, difference %.2e' % (r.ok, e))

# the joint also works when the nodes coincide as well
r = two_segments('join_same', 'JOIN COINCIDENT\n', dx=0.0, dz=0.0).run()
e = abs(r.u()[2] - u_ref) / abs(u_ref) if r.ok else 1.0
check('coincident nodes with different numbers', r.ok and e < 1e-9,
      'relative difference %.2e' % e)

for rec, msg in (('JOIN FOO\n', 'JOIN COINCIDENT'),
                 ('JOIN COINCIDENT -1.0\n', 'POSITIVE')):
    r = two_segments('join_bad', rec).run()
    check('%s is an error' % rec.strip(), (not r.ok) and msg in r.log, '')

print('ALL JOIN TESTS PASSED' if not FAILED else
      'FAILED: ' + ', '.join(FAILED))
sys.exit(1 if FAILED else 0)
