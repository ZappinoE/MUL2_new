"""Generators and closed forms for the piezoelectric tests (analysis 101).

Material: PZT-5H like, transversely isotropic about z (SI units).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

# stiffness at constant electric field [Pa], voigt order xx yy zz xz yz xy
C11, C12, C13, C33, C44 = 127.2e9, 80.2e9, 84.7e9, 117.4e9, 23.0e9
C66 = 0.5 * (C11 - C12)
E31, E33, E15 = -6.62, 23.24, 17.03            # [C/m^2]
EPS11, EPS33 = 1.503e-8, 1.300e-8              # [F/m] at constant strain
RHO = 7500.0

CMAT = [[C11, C12, C13, 0, 0, 0], [C12, C11, C13, 0, 0, 0],
        [C13, C13, C33, 0, 0, 0], [0, 0, 0, C44, 0, 0],
        [0, 0, 0, 0, C44, 0], [0, 0, 0, 0, 0, C66]]
EMAT = [[0, 0, 0, E15, 0, 0], [0, 0, 0, 0, E15, 0],
        [E31, E31, E33, 0, 0, 0]]
PERM = [[EPS11, 0, 0], [0, EPS11, 0], [0, 0, EPS33]]


def material_text(angle_note=None):
    flat = ' '.join(V.fmt(x) for row in CMAT for x in row)
    e = ' '.join(V.fmt(x) for row in EMAT for x in row)
    p = ' '.join(V.fmt(x) for row in PERM for x in row)
    return ('1 3\n\nMAT-C 1  %s  %s\nZ-EXP 1  %s\nZ-PRM 1  %s\n'
            % (flat, V.fmt(RHO), e, p))


def inverse6(a):
    """Gauss-Jordan inverse of a 6x6 list matrix."""
    n = 6
    m = [list(map(float, a[i])) + [1.0 if i == j else 0.0
                                   for j in range(n)] for i in range(n)]
    for c in range(n):
        p = max(range(c, n), key=lambda r: abs(m[r][c]))
        m[c], m[p] = m[p], m[c]
        d = m[c][c]
        m[c] = [x / d for x in m[c]]
        for r in range(n):
            if r != c and m[r][c] != 0.0:
                f = m[r][c]
                m[r] = [x - f * y for x, y in zip(m[r], m[c])]
    return [row[n:] for row in m]


def d_matrix():
    """piezoelectric strain coefficients d = e s^E (3 x 6)."""
    s = inverse6(CMAT)
    return [[sum(EMAT[i][k] * s[k][j] for k in range(6)) for j in range(6)]
            for i in range(3)]


def kinematics_text(u='LE', p='LE'):
    return ('1\n\nKINEMATIC 1  %s %s %s NONE %s NONE NONE NONE NONE\n'
            % (u, u, u, p))


def potential_plane(i, a, b, c, d, value):
    return 'V-PLANE %d  %s %s %s %s  %s' % (i, V.fmt(a), V.fmt(b),
                                             V.fmt(c), V.fmt(d),
                                             V.fmt(value))


H8_LAT = V.H_PATTERN['H8'][1]


def slab_case(name, a=0.02, b=0.02, t=0.002, volt=100.0, sol=101,
              open_circuit=False):
    """one H8 block [0,a]x[0,b]x[0,t], electrodes on z = 0 and z = t.
    The symmetry planes x = 0, y = 0 and the bottom electrode z = 0 carry
    the minimal displacement constraints; the block expands freely."""
    c = V.Case(name)
    nodes = []
    for (i, j, k) in H8_LAT:
        nodes.append(((i - 1) * a, (j - 1) * b, (k - 1) * t))
    lines = ['8', '']
    for n, (x, y, z) in enumerate(nodes):
        lines.append('%d %s %s %s 1' % (n + 1, V.fmt(x), V.fmt(y),
                                        V.fmt(z)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    c.put('KINEMATICS.dat', kinematics_text())
    c.put('CONNECTIVITY.dat', '1\n\nH8 1  1 2 3 4 5 6 7 8  1  1\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
    c.put('ANALYSIS.dat', V.analysis_text(sol, 4, solid='NONE'))
    c.put('MATERIAL.dat', material_text())
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
    c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
    recs = [V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
            V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
            V.dplane(3, 0, 0, 1, 0, None, None, 0.0),
            potential_plane(4, 0, 0, 1, 0, 0.0)]
    if not open_circuit:
        recs.append(potential_plane(5, 0, 0, 1, -t, volt))
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text(
        [(0.5 * a, 0.5 * b, t - 1e-9), (0.7 * a, 0.3 * b, 0.5 * t)]))
    return c


def point_row(res, k):
    """named columns of POST_POINT row k."""
    r = res.points[k]
    return dict(u=r[10:13], eps=r[13:19], sig=r[25:31], volt=r[38],
                E=r[40:43], D=r[43:46])
