"""Results of the auxetic cell: load - opening curve and deformed shapes.

    python EXAMPLES/AUXETIC/plot_auxetic.py CASE_DIR [scale]

Reads CASE_DIR/DYNAMIC/TIME_HISTORY.dat (the six corners of the hexagon,
one block of rows per step) and the RESULTS_PARA_01_Snnnnnn.vtk of some
steps; writes CASE_DIR/auxetic_curve.png and auxetic_shapes.png and prints a
table (force on each corner, mean radial displacement of the corners, area of
the hexagon of the corners / initial).
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.collections import PolyCollection  # noqa: E402


def read_history(d):
    rows = open(os.path.join(d, 'DYNAMIC', 'TIME_HISTORY.dat')).read().split('\n')
    head = rows[0].split()
    ix = {h: i for i, h in enumerate(head)}
    recs = np.array([[float(v.replace('D', 'E')) for v in l.split()[:len(head)]]
                     for l in rows[1:] if len(l.split()) >= 14])
    npt = int(recs[:, ix['ID']].max())
    nc = 6                                  # the corners are the first six points
    out = []
    for s in range(len(recs) // npt):
        b = recs[s * npt:s * npt + nc]
        x0 = b[:, [ix['X_REQ'], ix['Y_REQ']]]
        u = b[:, [ix['U_X'], ix['U_Y']]]
        x = x0 + u
        order = np.argsort(np.arctan2(x0[:, 1], x0[:, 0]))
        px = x[order]
        area = 0.5 * abs(np.dot(px[:, 0], np.roll(px[:, 1], -1)) -
                         np.dot(px[:, 1], np.roll(px[:, 0], -1)))
        rad = np.sum(u * x0, axis=1) / np.linalg.norm(x0, axis=1)
        out.append((b[0, ix['TIME']], rad.mean(), area))
    return np.array(out)


def force_per_corner(d):
    """total radial force on a corner (the F-POINT records are per face)"""
    tot = {}
    for line in open(os.path.join(d, 'INPUT', 'BC.dat')):
        if line.startswith('F-POINT'):
            t = line.split()
            key = (round(float(t[2].replace('D', 'E')), 5),
                   round(float(t[3].replace('D', 'E')), 5))
            f = np.hypot(float(t[5].replace('D', 'E')), float(t[6].replace('D', 'E')))
            tot[key] = tot.get(key, 0.0) + f
    return float(np.mean(list(tot.values()))) if tot else 1.0


def read_model(d):
    nl = open(os.path.join(d, 'INPUT', 'NODES.dat')).read().split('\n')
    n = int(nl[0])
    xy = np.array([[float(v.replace('D', 'E')) for v in l.split()[1:3]]
                   for l in nl[2:2 + n]])
    elems = []
    for l in open(os.path.join(d, 'INPUT', 'CONNECTIVITY.dat')).read().split('\n')[2:]:
        t = l.split()
        if len(t) > 4 and t[0] in ('T6', 'Q9'):
            nn = 6 if t[0] == 'T6' else 9
            ids = [int(v) - 1 for v in t[2:2 + nn]]
            corners = ids[:3] if t[0] == 'T6' else [ids[0], ids[2], ids[4], ids[6]]
            elems.append((corners, int(t[-1])))
    return xy, elems


def read_vtk(path):
    text = open(path).read().split('\n')
    pts = disp = None
    for i, l in enumerate(text):
        if l.startswith('POINTS'):
            n = int(l.split()[1])
            pts = np.array([[float(v) for v in text[i + 1 + k].split()]
                            for k in range(n)])
        elif l.startswith('VECTORS Displacements'):
            disp = np.array([[float(v) for v in text[i + 1 + k].split()]
                             for k in range(n)])
    return pts, disp


def deformed_polygons(xy, elems, pts, disp, scale):
    """deformed corner polygons: the 27 output points of an element include
    its corners (bottom face z = min) whose displacement is used"""
    npe = len(pts) // len(elems)
    polys, mats = [], []
    for e, (corners, mat) in enumerate(elems):
        blk = slice(e * npe, (e + 1) * npe)
        p, u = pts[blk], disp[blk]
        zmin = p[:, 2].min()
        poly = []
        for c in corners:
            d = np.hypot(p[:, 0] - xy[c, 0], p[:, 1] - xy[c, 1])
            d[np.abs(p[:, 2] - zmin) > 1e-9] = 1e9
            k = int(np.argmin(d))
            poly.append(xy[c] + scale * u[k, :2])
        polys.append(poly)
        mats.append(mat)
    return polys, mats


def main(d, scale=1.0):
    h = read_history(d)
    f0 = force_per_corner(d)
    force = h[:, 0] * f0
    area0 = h[0, 2]
    print('load per corner [N]   mean radial disp [mm]   area / area0')
    for k in range(0, len(h), max(1, len(h) // 15)):
        print('%10.3f           %10.4f             %8.4f' % (
            force[k], h[k, 1], h[k, 2] / area0))
    fig, ax = plt.subplots(1, 2, figsize=(9, 3.6))
    ax[0].plot(h[:, 1], force, 'o-', ms=2.5)
    ax[0].set_xlabel('radial displacement of the corners [mm]')
    ax[0].set_ylabel('force on each corner [N]')
    ax[0].grid(True, alpha=0.3)
    ax[1].plot(force, h[:, 2] / area0, 'o-', ms=2.5)
    ax[1].set_xlabel('force on each corner [N]')
    ax[1].set_ylabel('area of the hexagon / initial')
    ax[1].grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(d, 'auxetic_curve.png'), dpi=150)
    plt.close(fig)
    xy, elems = read_model(d)
    targets = [0.0, 0.25, 0.5, 1.0]
    steps = [int(np.argmin(np.abs(h[:, 0] - t * h[:, 0].max()))) for t in targets]
    fig, axs = plt.subplots(1, len(steps), figsize=(3.4 * len(steps), 3.6))
    for a, s in zip(axs, steps):
        p = os.path.join(d, 'DYNAMIC', 'RESULTS_PARA_01_S%06d.vtk' % s)
        if not os.path.exists(p):
            continue
        pts, disp = read_vtk(p)
        polys, mats = deformed_polygons(xy, elems, pts, disp, scale)
        col = ['#cfd8e3' if m == 1 else '#e8453c' for m in mats]
        a.add_collection(PolyCollection(polys, facecolors=col,
                                        edgecolors='k', linewidths=0.15))
        allp = np.concatenate(polys)
        a.set_xlim(-24, 24)
        a.set_ylim(-24, 24)
        a.set_aspect('equal')
        a.set_title('F = %.1f N, area x%.3f' % (force[s], h[s, 2] / area0),
                    fontsize=8)
        a.axis('off')
    fig.tight_layout()
    fig.savefig(os.path.join(d, 'auxetic_shapes.png'), dpi=150)


if __name__ == '__main__':
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 1.0)
