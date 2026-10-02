"""Geometrically nonlinear static (108): elastica, beam-column, limits.

    python TESTS/NONLINEAR/nonlinear_tests.py [path_to_MUL2_V3.exe]
"""
import math
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    os.environ['MUL2_EXE'] = os.path.abspath(sys.argv[1])
os.environ.setdefault('MUL2_VAL_WORK', os.path.join(
    tempfile.gettempdir(), 'mul2_nonlinear_runs'))
sys.path.insert(0, os.path.join(HERE, '..', 'VALIDATION'))
import vlib as V  # noqa: E402

FAILED = []
E, NU = V.E0, V.NU0
L, B, H = V.LB, V.BB, V.HB_
EI = E * B * H ** 3 / 12.0


def check(name, ok, detail):
    print(('PASS  ' if ok else 'FAIL  ') + name + '  ' + detail)
    if not ok:
        FAILED.append(name)


def close(name, a, b, tol):
    e = abs(a - b) / max(abs(b), 1e-300)
    check(name, e <= tol, 'relative difference %.2e (tol %.0e)' % (e, tol))


def elastica(alpha, n=4000):
    """tip (x, y)/L of a cantilever with a dead end load P ⟂ the
    undeformed axis, alpha = P L^2 / EI (shooting + RK4)."""
    def integrate(k0):
        th, k, x, y = 0.0, k0, 0.0, 0.0
        h = 1.0 / n

        def f(th_, k_):
            return k_, -alpha * math.cos(th_), math.cos(th_), math.sin(th_)
        for _ in range(n):
            a1 = f(th, k)
            a2 = f(th + 0.5 * h * a1[0], k + 0.5 * h * a1[1])
            a3 = f(th + 0.5 * h * a2[0], k + 0.5 * h * a2[1])
            a4 = f(th + h * a3[0], k + h * a3[1])
            th += h * (a1[0] + 2 * a2[0] + 2 * a3[0] + a4[0]) / 6
            k += h * (a1[1] + 2 * a2[1] + 2 * a3[1] + a4[1]) / 6
            x += h * (a1[2] + 2 * a2[2] + 2 * a3[2] + a4[2]) / 6
            y += h * (a1[3] + 2 * a2[3] + 2 * a3[3] + a4[3]) / 6
        return k, x, y
    lo, hi = 0.0, 2.0 * alpha
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if integrate(mid)[0] > 0.0:
            hi = mid
        else:
            lo = mid
    _, x, y = integrate(0.5 * (lo + hi))
    return x, y


def nl_case(case, steps, itmax=30, tol=1e-8):
    case.put('ANALYSIS.dat', V.analysis_text(108, 4))
    case.put('NL_INFO.dat', '1\n%d\n%d\n%s\n1\n' % (steps, itmax,
                                                    V.fmt(tol)))
    return case.run()


sec = V.rect_mesh('Q9', 2, 2, -B / 2, B / 2, -H / 2, H / 2)
pts = [(0.0, L - 1e-6, 0.0)]

# ---- 1. small load: the nonlinear solution is the linear one
c = V.beam_case('nl_small', sec, 'LE 1', load=('shear', 1.0e3),
                points=pts)
r_lin = c.run()
r = nl_case(V.beam_case('nl_small_nl', sec, 'LE 1', load=('shear', 1.0e3),
                        points=pts), 2)
check('small load runs', r.ok, r.log[-300:] if not r.ok else '')
close('small load: nonlinear = linear tip deflection', r.u()[2],
      r_lin.u()[2], 1e-4)

# ---- 2. large deflection of a cantilever (elastica)
for alpha in (1.0, 2.0):
    p = alpha * EI / L ** 2
    r = nl_case(V.beam_case('nl_elastica_%d' % alpha, sec, 'LE 1',
                            load=('shear', p), points=pts), 10)
    check('elastica PL^2/EI = %g runs' % alpha, r.ok,
          r.log[-300:] if not r.ok else '')
    xe, ye = elastica(alpha)
    u = r.u()
    close('elastica %g: tip deflection w/L' % alpha, u[2] / L, ye, 3e-2)
    close('elastica %g: tip shortening u/L' % alpha, -u[1] / L, 1.0 - xe,
          5e-2)
    iters = re.findall(r'CONVERGED IN (\d+) ITERATIONS', r.log)
    check('elastica %g: Newton converges in few iterations' % alpha,
          iters and max(int(i) for i in iters) <= 8,
          'iterations per step %s' % iters)

# ---- 3. beam-column: axial compression 0.5 P_cr and a small lateral load
p_cr = math.pi ** 2 * EI / (4.0 * L ** 2)
pax = 0.5 * p_cr
hlat = 1.0e-3 * pax
ca = V.beam_case('nl_col_a', sec, 'LE 1', load=('axial_force', -pax),
                 points=pts)
cl = V.beam_case('nl_col_l', sec, 'LE 1', load=('shear', hlat),
                 points=pts)
lines = ca.files['BC.dat'].strip().split('\n')[2:]
lines = [x for x in lines if x.strip()]
lines += [x for x in cl.files['BC.dat'].strip().split('\n')[2:]
          if x.strip() and not x.startswith('D-PLANE')]
ca.put('BC.dat', V.bc_text(lines))
r = nl_case(ca, 5)
check('beam-column runs', r.ok, r.log[-300:] if not r.ok else '')
u_param = L * math.sqrt(pax / EI)
amplification = 3.0 * (math.tan(u_param) - u_param) / u_param ** 3
w_ref = hlat * L ** 3 / (3.0 * EI) * amplification
close('beam-column: lateral deflection with P-delta amplification',
      r.u()[2], w_ref, 3e-2)

# ---- 4. the same cantilever as a solid (3D) model
p = 1.0 * EI / L ** 2
c = V.solid_case('nl_solid', 'H27', 5, 1, L=L, b=B, h=H, nx=1,
                 sol=101, plane_strain=False,
                 load=('shear', p), points=pts)
r = nl_case(c, 10)
check('solid elastica runs', r.ok, r.log[-300:] if not r.ok else '')
xe, ye = elastica(1.0)
close('solid elastica: tip deflection w/L', r.u()[2] / L, ye, 5e-2)

# ---- 5. thermal expansion in the Green measure: (1 + L')^2 = 1 + 2 a dT
A_BAR, N_EL = 0.1, 10
H8 = V.H_PATTERN['H8'][1]
ALPHA_BIG, DT_BIG = 1.0e-3, 10.0
c = V.Case('nl_thermal')
nid = lambda i, j, k: i + (N_EL + 1) * (j + 2 * k) + 1
lines = ['%d' % (4 * (N_EL + 1)), '']
for k in range(2):
    for j in range(2):
        for i in range(N_EL + 1):
            lines.append('%d %s %s %s 1' % (nid(i, j, k),
                                            V.fmt(L * i / N_EL),
                                            V.fmt(A_BAR * j),
                                            V.fmt(A_BAR * k)))
c.put('NODES.dat', '\n'.join(lines) + '\n')
c.put('KINEMATICS.dat', '1\n\nKINEMATIC 1  LE LE LE LE NONE NONE NONE '
      'NONE NONE\n')
el = ['%d' % N_EL, '']
for e in range(N_EL):
    ids = [nid(e + i - 1, j - 1, k - 1) for (i, j, k) in H8]
    el.append('H8 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
c.put('VERSORS.dat', '1\n\nVERSOR 1  0 0 1\n')
c.put('MATERIAL.dat', '1 3\n\nISO-M 1  70.0D9 0.3 2700.0\nT-EXP 1  %s\n'
      'T-CON 1  100.0\n' % V.fmt(ALPHA_BIG))
c.put('LAMINATION.dat', V.LAM_TEXT)
c.put('EXP_MESH_01.dat', '1\n\n1  0.0D0 0.0D0 0.0D0\n')
c.put('EXP_CONN_01.dat', '1\n\nS1 1 1 1\n')
c.put('BC.dat', V.bc_text([V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
                           V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
                           V.dplane(3, 0, 0, 1, 0, None, None, 0.0),
                           'T-CONST 4  %s' % V.fmt(DT_BIG)]))
c.put('POSTPROCESSING.dat', V.post_text([(L - 1e-9, 0.5 * A_BAR,
                                          0.5 * A_BAR)]))
r = nl_case(c, 4)
check('thermal Green-measure run', r.ok, r.log[-300:] if not r.ok else '')
close('thermal expansion in the Green measure',
      r.points[0][10] / L, math.sqrt(1.0 + 2.0 * ALPHA_BIG * DT_BIG) - 1.0,
      2e-3)
# ---- 6. arc length (SOLVTEC 2): shallow clamped arch, snap-through
RISE, P_ARC = 2.5, 1.0e9
# one quadratic section element (9 nodes, one at the axis for the load):
# the path has a few hundred steps
SEC_ARCH = V.rect_mesh('Q9', 1, 1, -B / 2, B / 2, -H / 2, H / 2)


def arch_case(name, tech, steps, lmax, ds=0.0, dsmin=0.0, dsmax=0.0,
              nel=6):
    """faceted arch in the y-z plane: the ends of the elements lie on a
    parabola (span L, rise RISE) and every beam element is straight (the
    nonlinear analysis does not support curved elements); clamped at
    both ends, vertical dead load at the crown (lambda = 1: P_ARC)."""
    p = 3
    nn = p * nel + 1
    coords = []
    for i in range(nn):
        e = min(i // p, nel - 1)
        s = (i - p * e) / p
        pts = []
        for k in (e, e + 1):
            y = L * k / nel
            pts.append((y, 4.0 * RISE * y * (L - y) / L ** 2))
        coords.append((0.0, pts[0][0] + s * (pts[1][0] - pts[0][0]),
                       pts[0][1] + s * (pts[1][1] - pts[0][1])))
    c = V.Case(name)
    nt, _ = V.kin_nodes_text(coords, 'LE 1')
    c.put('NODES.dat', nt)
    el = ['%d' % nel, '']
    for e in range(nel):
        ids = [p * e + a + 1 for a in range(p + 1)]
        el.append('B4 %d  %s  1  1' % (e + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(108, 4))
    c.put('MATERIAL.dat', V.material_text())
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', SEC_ARCH.mesh_text(True))
    c.put('EXP_CONN_01.dat', SEC_ARCH.conn_text())
    c.put('BC.dat', V.bc_text([
        V.dplane(1, 0, 1, 0, 0, 0.0, 0.0, 0.0),
        V.dplane(2, 0, 1, 0, -L, 0.0, 0.0, 0.0),
        V.fpoint(3, 0.0, L / 2, RISE, 0.0, 0.0, -P_ARC)]))
    c.put('POSTPROCESSING.dat', V.post_text([(0.0, L / 2, RISE)]))
    tail = '%s %s %s %s\n' % (V.fmt(ds), V.fmt(dsmin), V.fmt(dsmax),
                              V.fmt(lmax)) if tech == 2 else ''
    c.put('NL_INFO.dat', '%d\n%d\n30\n1.0D-8\n1\n%s' % (tech, steps, tail))
    return c


def crown_path(r):
    """[(lambda, u_z)] of the crown from TIME_HISTORY.dat."""
    rows = []
    with open(os.path.join(r.case_dir, 'DYNAMIC', 'TIME_HISTORY.dat')) as f:
        head = f.readline().split()
        iz = head.index('U_Z')
        for line in f:
            tok = line.split()
            if len(tok) > iz:
                rows.append((float(tok[0].replace('D', 'E')),
                             float(tok[iz].replace('D', 'E'))))
    return rows


def peak(path):
    """first limit load (parabola through the three points around the
    first local maximum of lambda)."""
    lam = [a for a, _ in path]
    for k in range(1, len(lam) - 1):
        if lam[k] > lam[k - 1] and lam[k] > lam[k + 1]:
            return k, lam[k]
    return None, None


# below the limit load the two techniques follow the same path
r_lc = nl_case(arch_case('arc_lc', 1, 10, 1.0), 10)
r_al = arch_case('arc_al_low', 2, 40, 1.0).run()
check('arc length (lambda 1) runs', r_al.ok, r_al.log[-300:]
      if not r_al.ok else '')
close('arc length = load control below the limit load (crown w)',
      crown_path(r_al)[-1][1], crown_path(r_lc)[-1][1], 1e-4)

# snap-through: the load reaches a maximum and then decreases
r_coarse = arch_case('arc_al_coarse', 2, 60, 3.0).run()
r_fine = arch_case('arc_al_fine', 2, 400, 3.0, ds=0.6, dsmin=0.01,
                   dsmax=0.6).run()
check('arc length through the limit point runs', r_coarse.ok and r_fine.ok,
      (r_coarse.log + r_fine.log)[-300:])
pc, pf = crown_path(r_coarse), crown_path(r_fine)
kc, lc = peak(pc)
kf, lf = peak(pf)
check('snap-through: lambda reaches a maximum then decreases',
      kc is not None and kf is not None,
      'coarse limit %s fine limit %s' % (lc, lf))
if kf is not None:
    lam_f = [a for a, _ in pf]
    check('snap-through: the load drops below the limit load',
          min(lam_f[kf:]) < 0.5 * lf,
          'limit %.4f, lowest %.4f' % (lf, min(lam_f[kf:])))
    # the limit load from the fine path is refined by the coarse one
    close('limit load: coarse and fine arc length agree', lc, lf, 1.5e-2)
    lim_dir = [w for _, w in pf][kf]
    check('snap-through: crown moves down at the limit',
          lim_dir < 0.0, 'u_z = %.4g' % lim_dir)

if FAILED:
    print('FAILED: ' + ', '.join(FAILED))
    sys.exit(1)
print('ALL NONLINEAR TESTS PASSED')
