"""piezo on beam (1D), plate (2D) and solid (3D) models of the same bar."""
import re
import sys
import pzlib as Z
import vlib as V

L, B, H = 0.1, 0.01, 0.002


def patch(c, circuit, volt=0.0, sol=101, clamp=True, ndiv=None):
    nodes = c.files['NODES.dat']
    nodes = re.sub(r'[ \t]+(H?LE|TE)[ \t]*\d*[ \t]*$', ' 1', nodes,
                   flags=re.M)
    c.put('NODES.dat', nodes)
    c.put('KINEMATICS.dat', Z.kinematics_text())
    c.put('MATERIAL.dat', Z.material_text())
    top, bot = -H / 2, H / 2
    if sol == 101:
        recs = [V.dplane(1, 0, 1, 0, 0, None, 0.0, None),
                V.dplane(2, 1, 0, 0, 0, 0.0, None, None),
                V.dplane(3, 0, 0, 1, 0, None, None, 0.0),
                Z.potential_plane(4, 0, 0, 1, H / 2, 0.0),
                Z.potential_plane(5, 0, 0, 1, -H / 2, volt)]
    else:
        recs = [V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
                Z.potential_plane(2, 0, 0, 1, H / 2, 0.0)]
        if circuit == 'SC':
            recs.append(Z.potential_plane(3, 0, 0, 1, -H / 2, 0.0))
        elif circuit == 'FLT':
            recs.append('V-FLOAT 3  0.0D0 0.0D0 1.0D0 %s' % V.fmt(-H / 2))
            recs[1] = 'V-FLOAT 2  0.0D0 0.0D0 1.0D0 %s' % V.fmt(H / 2)
    c.put('BC.dat', V.bc_text(recs))
    return c


def beam(name, **k):
    sec = V.rect_mesh('Q9', 2, 2, -B / 2, B / 2, -H / 2, H / 2)
    c = V.beam_case(name, sec, ['LE'] * 21, L=L, nel=5, btype='B4',
                    sol=k.get('sol', 101), nmodes=4,
                    points=[(0.0, L - 1e-7, 0.0), (0.0, L - 1e-7, H / 2)])
    return patch(c, k.get('circuit'), k.get('volt', 0.0), k.get('sol', 101))


def plate(name, **k):
    c = V.plate_case(name, 'Q9', 5, ('LE', 'B3', 1), L=L, b=B, h=H,
                     nx=1, sol=k.get('sol', 101), nmodes=4,
                     points=[(0.0, L - 1e-7, 0.0), (0.0, L - 1e-7, H / 2)])
    return patch(c, k.get('circuit'), k.get('volt', 0.0), k.get('sol', 101))


def solid(name, **k):
    c = V.solid_case(name, 'H27', 5, 1, L=L, b=B, h=H, nx=1,
                     sol=k.get('sol', 101), nmodes=4, plane_strain=False,
                     points=[(0.0, L - 1e-7, 0.0), (0.0, L - 1e-7, H / 2)])
    return patch(c, k.get('circuit'), k.get('volt', 0.0), k.get('sol', 101))


d = Z.d_matrix()
V0 = 100.0
print('expect uy', d[2][0] * (-V0 / H) * L, 'uz(top)', -d[2][2] * V0 / 2)
for nm, f in (('beam', beam), ('plate', plate), ('solid', solid)):
    r = f('pzb_' + nm + '_st', volt=V0).run()
    print(nm, 'static', r.ok, r.ndof,
          [r.points[k][10:13] for k in range(2)] if r.ok else r.log[-600:])
for nm, f in (('beam', beam), ('plate', plate), ('solid', solid)):
    for circ in ('SC', 'OC', 'FLT'):
        r = f('pzb_%s_%s' % (nm, circ), sol=103, circuit=circ).run()
        print(nm, circ, r.ok, r.ndof,
              r.freq[:4] if r.ok else r.log[-600:])
