"""Structure at the largest opening before the limit point: displacement map
and plain solid view.

    python EXAMPLES/AUXETIC/plot_max_opening.py CASE_DIR [scale] [nsteps]

The step is the one with the largest load factor among the first `nsteps`
(default 10) of TIME_HISTORY.dat (the limit point of an arc-length run).
Writes CASE_DIR/auxetic_max_map.png and auxetic_max_solid.png.
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.collections import PolyCollection  # noqa: E402
from matplotlib.tri import Triangulation  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plot_auxetic import (read_history, read_model, read_vtk,  # noqa: E402
                          force_per_corner)


def element_data(xy, elems, pts, disp, scale):
    """for every element: deformed corner positions and displacement
    magnitudes (bottom face)"""
    npe = len(pts) // len(elems)
    out = []
    for e, (corners, mat) in enumerate(elems):
        blk = slice(e * npe, (e + 1) * npe)
        p, u = pts[blk], disp[blk]
        zmin = p[:, 2].min()
        pos, mag = [], []
        for c in corners:
            d = np.hypot(p[:, 0] - xy[c, 0], p[:, 1] - xy[c, 1])
            d[np.abs(p[:, 2] - zmin) > 1e-9] = 1e9
            k = int(np.argmin(d))
            pos.append(xy[c] + scale * u[k, :2])
            mag.append(np.hypot(u[k, 0], u[k, 1]))
        out.append((np.array(pos), np.array(mag), mat))
    return out


def main(d, scale=1.0, nsteps=10):
    h = read_history(d)
    step = int(np.argmax(h[:nsteps, 0]))
    f = h[step, 0] * force_per_corner(d)
    xy, elems = read_model(d)
    pts, disp = read_vtk(os.path.join(d, 'DYNAMIC',
                                      'RESULTS_PARA_01_S%06d.vtk' % step))
    data = element_data(xy, elems, pts, disp, scale)
    allp = np.concatenate([p for p, _, _ in data])
    lim = 1.04 * np.abs(allp).max()
    area_ratio = h[step, 2] / h[0, 2]
    # ---- displacement map
    vx, vy, vv, tris = [], [], [], []
    for pos, mag, _ in data:
        base = len(vx)
        for q, m in zip(pos, mag):
            vx.append(q[0])
            vy.append(q[1])
            vv.append(m)
        tris.append([base, base + 1, base + 2])
        if len(pos) == 4:
            tris.append([base, base + 2, base + 3])
    tri = Triangulation(vx, vy, tris)
    fig, ax = plt.subplots(figsize=(7.2, 6.4))
    tc = ax.tripcolor(tri, vv, shading='gouraud', cmap='turbo')
    ax.triplot(tri, lw=0.0)
    cb = fig.colorbar(tc, ax=ax, shrink=0.8)
    cb.set_label('displacement magnitude [mm]')
    ax.set_aspect('equal')
    ax.set_xlim(-lim, lim)
    ax.set_ylim(-lim, lim)
    ax.axis('off')
    ax.set_title('Largest opening before the limit point: F = %.2f N per corner, '
                 'area x%.3f' % (f, area_ratio), fontsize=9)
    fig.tight_layout()
    fig.savefig(os.path.join(d, 'auxetic_max_map.png'), dpi=220)
    plt.close(fig)
    # ---- plain solid
    fig, ax = plt.subplots(figsize=(6.4, 6.4))
    polys = [p for p, _, _ in data]
    ax.add_collection(PolyCollection(polys, facecolors='#3a3f47',
                                     edgecolors='#3a3f47', linewidths=0.25))
    ax.set_aspect('equal')
    ax.set_xlim(-lim, lim)
    ax.set_ylim(-lim, lim)
    ax.axis('off')
    fig.tight_layout(pad=0.2)
    fig.savefig(os.path.join(d, 'auxetic_max_solid.png'), dpi=220,
                transparent=False, facecolor='white')
    print('step %d, load factor %.4f, F = %.3f N per corner, area x%.4f' % (
        step, h[step, 0], f, area_ratio))


if __name__ == '__main__':
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 1.0,
         int(sys.argv[3]) if len(sys.argv) > 3 else 10)
