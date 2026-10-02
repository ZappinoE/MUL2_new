"""Timing of the surface loads on a 3D block: python perf_surface.py [nx ny nz]"""
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_perf_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

nx, ny, nz = [int(a) for a in sys.argv[1:4]] if len(sys.argv) > 3 else (
    6, 24, 6)
c = V.solid_case('pf_surface', 'H8', ny, nz, nx=nx, L=10.0, b=1.0, h=1.0,
                 sol=101, plane_strain=False, points=[(0.0, 5.0, 0.0)])
c.put('NODES.dat', re.sub(r'[ \t]+LE[ \t]+1[ \t]*$', ' 1',
                          c.files['NODES.dat'], flags=re.M))
c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE NONE '
      'NONE NONE\n')
c.put('MATERIAL.dat', '1 3\n\nISO-M 1  70.0D9 0.3 2700.0\nT-EXP 1  1.0D-5\n'
      'T-CON 1  100.0\n')
c.put('BC.dat', V.bc_text([V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
                           'T-PLANE 2  0 1 0 0  0.0',
                           'Q-SUN 3  0 0 1  1000.0 0.6',
                           'Q-CONV 4  0 0 0 0  10.0 0.0']))
r = c.run()
for line in r.log.split('\n'):
    if 'SURFACE' in line or 'ASSEMBLED' in line or 'TIMES' in line:
        print(line)
print('ok', r.ok, 'wall %.1f' % r.wall)
