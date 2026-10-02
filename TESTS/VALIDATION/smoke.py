import vlib as V

P = 1e6
for nx, ny, nz, ps in ((1, 10, 2, True), (1, 10, 2, False), (2, 10, 2, False),
                       (3, 10, 3, False), (1, 4, 1, False)):
    c = V.solid_case('smoke_h8', 'H8', ny, nz, nx=nx, shear='MITC',
                     plane_strain=ps, load=('shear', P))
    r = c.run()
    print(nx, ny, nz, ps, r.ok, r.ndof, r.u()[2] if r.points else None,
          [l for l in r.log.splitlines() if 'ERROR' in l or 'WARN' in l][:2])
