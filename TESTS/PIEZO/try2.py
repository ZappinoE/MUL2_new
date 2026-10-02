import math
import pzlib as Z
import vlib as V


def stack_case(name, nz=20, a=0.01, b=0.01, t=0.01, sol=103,
               circuit='SC', volt=0.0):
    """column of nz H8 elements along z, lateral displacements clamped
    (1D thickness vibration); bottom electrode grounded, top electrode
    grounded (SC) or free (OC)."""
    c = V.Case(name)
    nid = lambda i, j, k: i + 2 * j + 4 * k + 1
    lines = ['%d' % (4 * (nz + 1)), '']
    for k in range(nz + 1):
        for j in range(2):
            for i in range(2):
                lines.append('%d %s %s %s 1' % (
                    nid(i, j, k), V.fmt(i * a), V.fmt(j * b),
                    V.fmt(t * k / nz)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', Z.kinematics_text())
    el = ['%d' % nz, '']
    for k in range(nz):
        ids = []
        for (i, j, kk) in Z.H8_LAT:
            ids.append(nid(i - 1, j - 1, k + kk - 1))
        el.append('H8 %d  %s  1  1' % (k + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', V.analysis_text(sol, 6, solid='NONE'))
    c.put('MATERIAL.dat', Z.material_text())
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    recs = [V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
            V.dplane(2, 1, 0, 0, -a, 0.0, None, None),
            V.dplane(3, 0, 1, 0, 0, None, 0.0, None),
            V.dplane(4, 0, 1, 0, -b, None, 0.0, None),
            V.dplane(5, 0, 0, 1, 0, None, None, 0.0),
            Z.potential_plane(6, 0, 0, 1, 0, 0.0)]
    if circuit == 'SC':
        recs.append(Z.potential_plane(7, 0, 0, 1, -t, volt))
    if circuit == 'FLT':
        recs.append('V-FLOAT 7  0.0D0 0.0D0 1.0D0 %s' % V.fmt(-t))
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text([(0.5 * a, 0.5 * b, 0.5 * t)]))
    return c


t = 0.01
for circ in ('SC', 'OC', 'FLT'):
    r = stack_case('pz_stack_' + circ, circuit=circ).run()
    print(circ, r.ok, r.ndof, r.freq[:4] if r.ok else r.log[-500:])
cbar_sc = Z.C33
cbar_oc = Z.C33 + Z.E33 ** 2 / Z.EPS33
for n in (1, 2, 3):
    print('closed form', n,
          (2 * n - 1) / (4 * t) * math.sqrt(cbar_sc / Z.RHO),
          (2 * n - 1) / (4 * t) * math.sqrt(cbar_oc / Z.RHO))

