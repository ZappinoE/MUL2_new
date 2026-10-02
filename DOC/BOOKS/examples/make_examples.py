"""Generate the worked examples used in the User Guide.

    python make_examples.py [output_root]

Creates one INPUT directory per example (default: ./cases). Every case is a
cantilever of length L = 1 m with a square 0.1 m x 0.1 m section (E = 70 GPa,
nu = 0.3, rho = 2700 kg/m3), clamped at y = 0 and loaded at the tip.
"""
import os
import sys

E, NU, RHO = 70.0e9, 0.3, 2700.0
L, B, H = 1.0, 0.1, 0.1
P = 1000.0   # tip load [N] along +z


def fmt(x):
    return ('%.10E' % x).replace('E', 'D')


def write(path, name, text):
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, name), 'w', newline='\n') as f:
        f.write(text)


def analysis(sol, modes, shear='MITC'):
    return ('%d\n\n%d modes\n\n%s\n%s\n%s\n' % (
        sol, modes, shear, shear, shear))


def beam_common(path, nel, model, tip_nodes_expansion=None, modal=False):
    """B4 elements along y; model = ('TE', n) or ('LE', n_side)."""
    nn = 3 * nel + 1
    lines = ['%d' % nn, '']
    for i in range(nn):
        y = L * i / (nn - 1)
        if model[0] == 'TE':
            lines.append('%d  0.0D0  %s  0.0D0  TE %d' % (i + 1, fmt(y), model[1]))
        else:
            lines.append('%d  0.0D0  %s  0.0D0  LE 2' % (i + 1, fmt(y)))
    write(path, 'NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % nel, '']
    for e in range(nel):
        b = 3 * e + 1
        el.append('B4  %d  %d %d %d %d  1  1' % (e + 1, b, b + 1, b + 2, b + 3))
    write(path, 'CONNECTIVITY.dat', '\n'.join(el) + '\n')
    write(path, 'VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    write(path, 'MATERIAL.dat', '1 1\n\nISO-M 1  %s  %s  %s\n' % (fmt(E), NU, RHO))
    write(path, 'LAMINATION.dat', '1\n\nLAM2 1 1 0.0 0.0\n')
    if model[0] == 'TE':
        # one Q9 section element: its nodes define the integration domain
        # and the points where loads and constraints can be applied
        mesh = ['9', '']
        k = 1
        for j in range(3):
            for i in range(3):
                mesh.append('%d  %s  0.0D0  %s' % (
                    k, fmt(-B / 2 + B * i / 2), fmt(-H / 2 + H * j / 2)))
                k += 1
        write(path, 'EXP_MESH_01.dat', '\n'.join(mesh) + '\n')
        write(path, 'EXP_CONN_01.dat', '1\n\nQ9 1 1  1 2 3 6 9 8 7 4 5\n')
    else:
        n = model[1]   # Q9 elements per side
        side = 2 * n + 1
        mesh = ['%d' % (side * side), '']
        k = 1
        for j in range(side):
            for i in range(side):
                mesh.append('%d  %s  0.0D0  %s' % (
                    k, fmt(-B / 2 + B * i / (side - 1)),
                    fmt(-H / 2 + H * j / (side - 1))))
                k += 1
        write(path, 'EXP_MESH_01.dat', '\n'.join(mesh) + '\n')
        conn = ['%d' % (n * n), '']
        eid = 1
        for b in range(n):
            for a in range(n):
                nd = lambda ii, jj: 1 + (2 * a + ii) + side * (2 * b + jj)
                ring = [nd(0, 0), nd(1, 0), nd(2, 0), nd(2, 1), nd(2, 2),
                        nd(1, 2), nd(0, 2), nd(0, 1), nd(1, 1)]
                conn.append('Q9 %d 1  %s' % (eid, ' '.join(map(str, ring))))
                eid += 1
        write(path, 'EXP_CONN_01.dat', '\n'.join(conn) + '\n')
    # BC: clamp y = 0 plane (0 1 0 0); tip load at the section centre
    if modal:
        write(path, 'BC.dat', '1\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n')
    else:
        write(path, 'BC.dat', '2\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n'
              'F-POINT 2  0.0 %s 0.0  0.0 0.0 %s\n' % (fmt(L), fmt(P)))
    pnt = ('PNT 1  0.0 %s 0.0\nPNT 2  0.0 0.5 0.05\n' % (fmt(L - 1e-6)))
    post = '3\n\nPARA 20 GLB 1 1 1 1 1 1 1 1 1\n' + pnt
    write(path, 'POSTPROCESSING.dat', post)
    write(path, 'ANALYSIS.dat', analysis(103 if modal else 101, 4, 'MITC'))


def plate_strip(path, modal=False, nx=1, ny=8):
    """cantilever strip modelled with Q9 plate elements; thickness H along z
    expanded with TE2 ... here with LE through the thickness (B3 x 1)."""
    # plate in the x-y plane, y is the length, thickness along z
    nxn, nyn = 2 * nx + 1, 2 * ny + 1
    lines = ['%d' % (nxn * nyn), '']
    k = 1
    for j in range(nyn):
        for i in range(nxn):
            lines.append('%d  %s  %s  0.0D0  LE 2' % (
                k, fmt(-B / 2 + B * i / (nxn - 1)), fmt(L * j / (nyn - 1))))
            k += 1
    write(path, 'NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % (nx * ny), '']
    eid = 1
    for b in range(ny):
        for a in range(nx):
            nd = lambda ii, jj: 1 + (2 * a + ii) + nxn * (2 * b + jj)
            ring = [nd(0, 0), nd(1, 0), nd(2, 0), nd(2, 1), nd(2, 2),
                    nd(1, 2), nd(0, 2), nd(0, 1), nd(1, 1)]
            el.append('Q9 %d  %s  1  1' % (eid, ' '.join(map(str, ring))))
            eid += 1
    write(path, 'CONNECTIVITY.dat', '\n'.join(el) + '\n')
    write(path, 'VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    write(path, 'MATERIAL.dat', '1 1\n\nISO-M 1  %s  %s  %s\n' % (fmt(E), NU, RHO))
    write(path, 'LAMINATION.dat', '1\n\nLAM2 1 1 0.0 0.0\n')
    # thickness mesh: B3 along z (nodes at -H/2, 0, H/2)
    write(path, 'EXP_MESH_01.dat', '3\n\n1  0.0D0 0.0D0 %s\n2  0.0D0 0.0D0 0.0D0\n3  0.0D0 0.0D0 %s\n' % (fmt(-H / 2), fmt(H / 2)))
    write(path, 'EXP_CONN_01.dat', '1\n\nB3 1 1  1 2 3\n')
    if modal:
        write(path, 'BC.dat', '1\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n')
    else:
        # load at the tip, distributed on the three tip nodes of the edge
        loads = ['F-POINT %d  %s %s 0.0  0.0 0.0 %s' % (
            2 + i, fmt(-B / 2 + B * i / 2), fmt(L), fmt(P * w)) for i, w in
            enumerate([1 / 6, 4 / 6, 1 / 6])]
        write(path, 'BC.dat', '4\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n' + '\n'.join(loads) + '\n')
    write(path, 'POSTPROCESSING.dat', '2\n\nPARA 20 GLB 1 1 1 1 1 1 1 1 1\nPNT 1  0.0 %s 0.0\n' % fmt(L - 1e-6))
    write(path, 'ANALYSIS.dat', analysis(103 if modal else 101, 4, 'MITC'))


def solid_block(path, modal=False, nx=1, ny=8, nz=1):
    """H27 elements"""
    nxn, nyn, nzn = 2 * nx + 1, 2 * ny + 1, 2 * nz + 1
    # H27 node order from the shape-function tables
    ix = [1, 3, 3, 1, 1, 3, 3, 1, 2, 1, 1, 3, 3, 2, 3, 1, 2, 1, 3, 2, 2, 2, 1, 3, 2, 2, 2]
    iy = [1, 1, 3, 3, 1, 1, 3, 3, 1, 2, 1, 2, 1, 3, 3, 3, 1, 2, 2, 3, 2, 1, 2, 2, 3, 2, 2]
    iz = [1, 1, 1, 1, 3, 3, 3, 3, 1, 1, 2, 1, 2, 1, 2, 2, 3, 3, 3, 3, 1, 2, 2, 2, 2, 3, 2]
    lines = ['%d' % (nxn * nyn * nzn), '']
    k = 1
    for kk in range(nzn):
        for j in range(nyn):
            for i in range(nxn):
                lines.append('%d  %s  %s  %s  LE 1' % (
                    k, fmt(-B / 2 + B * i / (nxn - 1)), fmt(L * j / (nyn - 1)),
                    fmt(-H / 2 + H * kk / (nzn - 1))))
                k += 1
    write(path, 'NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % (nx * ny * nz), '']
    eid = 1
    for c in range(nz):
        for b in range(ny):
            for a in range(nx):
                ids = []
                for m in range(27):
                    i = 2 * a + ix[m] - 1
                    j = 2 * b + iy[m] - 1
                    kk = 2 * c + iz[m] - 1
                    ids.append(1 + i + nxn * j + nxn * nyn * kk)
                el.append('H27 %d  %s  1  1' % (eid, ' '.join(map(str, ids))))
                eid += 1
    write(path, 'CONNECTIVITY.dat', '\n'.join(el) + '\n')
    write(path, 'VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    write(path, 'MATERIAL.dat', '1 1\n\nISO-M 1  %s  %s  %s\n' % (fmt(E), NU, RHO))
    write(path, 'LAMINATION.dat', '1\n\nLAM2 1 1 0.0 0.0\n')
    write(path, 'EXP_MESH_01.dat', '1\n\n1 0.0D0 0.0D0 0.0D0\n')
    write(path, 'EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    if modal:
        write(path, 'BC.dat', '1\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n')
    else:
        # tip load distributed over the nodes of the free face (equal share)
        nodes = [(i, kk) for kk in range(nzn) for i in range(nxn)]
        # consistent weights of a Q9 face: corners 1/36, mid 4/36, centre 16/36 (times area)
        w1 = {0: 1 / 6, 1: 4 / 6, 2: 1 / 6}
        loads = []
        for (i, kk) in nodes:
            w = w1[i] * w1[kk] if nx == 1 and nz == 1 else 1.0 / len(nodes)
            loads.append('F-POINT %d  %s %s %s  0.0 0.0 %s' % (
                2 + len(loads), fmt(-B / 2 + B * i / (nxn - 1)), fmt(L),
                fmt(-H / 2 + H * kk / (nzn - 1)), fmt(P * w)))
        write(path, 'BC.dat', '%d\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n%s\n' % (
            1 + len(loads), '\n'.join(loads)))
    write(path, 'POSTPROCESSING.dat', '2\n\nPARA 20 GLB 1 1 1 1 1 1 1 1 1\nPNT 1  0.0 %s 0.0\n' % fmt(L - 1e-6))
    write(path, 'ANALYSIS.dat', analysis(103 if modal else 101, 4, 'NONE'))


def plate_laminate(path, angles, modal=False, ny=8):
    """cantilever strip, 3-ply laminate through the thickness (B2 sub-elements).
    angles = (a1, a2, a3) rotation about the plate normal z, in degrees.
    Plies: carbon-like orthotropic ORT-M (fibres along the material axis L)."""
    nx = 1
    nxn, nyn = 2 * nx + 1, 2 * ny + 1
    lines = ['%d' % (nxn * nyn), '']
    k = 1
    for j in range(nyn):
        for i in range(nxn):
            lines.append('%d  %s  %s  0.0D0  LE 2' % (
                k, fmt(-B / 2 + B * i / (nxn - 1)), fmt(L * j / (nyn - 1))))
            k += 1
    write(path, 'NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % (nx * ny), '']
    eid = 1
    for b in range(ny):
        for a in range(nx):
            nd = lambda ii, jj: 1 + (2 * a + ii) + nxn * (2 * b + jj)
            ring = [nd(0, 0), nd(1, 0), nd(2, 0), nd(2, 1), nd(2, 2),
                    nd(1, 2), nd(0, 2), nd(0, 1), nd(1, 1)]
            el.append('Q9 %d  %s  1  1' % (eid, ' '.join(map(str, ring))))
            eid += 1
    write(path, 'CONNECTIVITY.dat', '\n'.join(el) + '\n')
    write(path, 'VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    # ORT-M: EL ET EZ nuLT nuLZ nuTZ GLT GLZ GTZ rho
    write(path, 'MATERIAL.dat', '1 1\n\nORT-M 1  140.0D9 10.0D9 10.0D9  0.3 0.3 0.4  5.0D9 5.0D9 3.5D9  1600.0\n')
    lam = ['3', ''] + ['LAM2 %d 1 0.0 %s' % (i + 1, fmt(a)) for i, a in enumerate(angles)]
    write(path, 'LAMINATION.dat', '\n'.join(lam) + '\n')
    zs = [-H / 2, -H / 6, H / 6, H / 2]
    write(path, 'EXP_MESH_01.dat', '4\n\n' + '\n'.join('%d  0.0D0 0.0D0 %s' % (i + 1, fmt(z)) for i, z in enumerate(zs)) + '\n')
    write(path, 'EXP_CONN_01.dat', '3\n\n' + '\n'.join('B2 %d %d  %d %d' % (i + 1, i + 1, i + 1, i + 2) for i in range(3)) + '\n')
    if modal:
        write(path, 'BC.dat', '1\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n')
    else:
        # tip load on the top-face nodes of the free edge
        loads = ['F-POINT %d  %s %s %s  0.0 0.0 %s' % (
            2 + i, fmt(-B / 2 + B * i / 2), fmt(L), fmt(H / 2), fmt(P * w)) for i, w in
            enumerate([1 / 6, 4 / 6, 1 / 6])]
        write(path, 'BC.dat', '4\n\nD-PLANE 1  0 1 0 0   0.0 0.0 0.0\n' + '\n'.join(loads) + '\n')
    write(path, 'POSTPROCESSING.dat', '2\n\nPARA 20 GLB 1 1 1 1 1 1 1 1 1\nPNT 1  0.0 %s 0.0\n' % fmt(L - 1e-6))
    write(path, 'ANALYSIS.dat', analysis(103 if modal else 101, 4, 'MITC'))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), 'cases')
    for order in (1, 2, 4):
        beam_common(os.path.join(root, 'beam_te%d_static' % order, 'INPUT'), 5, ('TE', order))
        beam_common(os.path.join(root, 'beam_te%d_modal' % order, 'INPUT'), 5, ('TE', order), modal=True)
    beam_common(os.path.join(root, 'beam_le2_static', 'INPUT'), 5, ('LE', 2))
    beam_common(os.path.join(root, 'beam_le2_modal', 'INPUT'), 5, ('LE', 2), modal=True)
    plate_strip(os.path.join(root, 'plate_strip_static', 'INPUT'))
    plate_strip(os.path.join(root, 'plate_strip_modal', 'INPUT'), modal=True)
    solid_block(os.path.join(root, 'solid_block_static', 'INPUT'))
    solid_block(os.path.join(root, 'solid_block_modal', 'INPUT'), modal=True)
    plate_laminate(os.path.join(root, 'plate_lam_0_90_0_static', 'INPUT'), (0, 90, 0))
    plate_laminate(os.path.join(root, 'plate_lam_90_0_90_static', 'INPUT'), (90, 0, 90))
    plate_laminate(os.path.join(root, 'plate_lam_0_90_0_modal', 'INPUT'), (0, 90, 0), modal=True)
    plate_laminate(os.path.join(root, 'plate_lam_90_0_90_modal', 'INPUT'), (90, 0, 90), modal=True)
    print('written to', root)


if __name__ == '__main__':
    main()
