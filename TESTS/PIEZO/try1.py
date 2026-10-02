import pzlib as Z

d = Z.d_matrix()
print('d31 d33 d15', d[2][0], d[2][2], d[0][3])
a, b, t, volt = 0.02, 0.02, 0.002, 100.0
c = Z.slab_case('pz_slab', a, b, t, volt)
r = c.run()
print(r.ok, r.ndof)
if not r.ok:
    print(r.log[-800:])
else:
    p = Z.point_row(r, 0)
    print('u', p['u'], 'expected uz', -d[2][2] * volt)
    print('volt', p['volt'], 'E', p['E'], 'D', p['D'])
    print('sig', p['sig'])
    q = Z.point_row(r, 1)
    print('mid', q['u'], q['volt'], q['E'])
