"""Von Mises stress map of the largest opening before the limit point.

    python EXAMPLES/AUXETIC/plot_stress.py CASE_DIR [nsteps]

CASE_DIR is a run made with `make_auxetic.py --stress-points`: TIME_HISTORY.dat
holds, after the six corners, three (triangle) or four (quad) points inside
every element.  The step with the largest load factor among the first
`nsteps` (default 10) is drawn in the deformed shape (scale 1).  Writes
CASE_DIR/auxetic_max_stress.png and auxetic_max_stress_hinge.png (stress of
the TPU hinges only, own scale) and prints the extremes.
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
from plot_max_opening import element_data  # noqa: E402


def read_points(d, step, npoint_corner=6):
    rows = open(os.path.join(d, 'DYNAMIC', 'TIME_HISTORY.dat')).read().split('\n')
    head = rows[0].split()
    ix = {h: i for i, h in enumerate(head)}
    recs = np.array([[float(v.replace('D', 'E')) for v in l.split()[:len(head)]]
                     for l in rows[1:] if len(l.split()) >= 14])
    npt = int(recs[:, ix['ID']].max())
    b = recs[step * npt:(step + 1) * npt][npoint_corner:]
    pos = b[:, [ix['X_REQ'], ix['Y_REQ']]] + b[:, [ix['U_X'], ix['U_Y']]]
    s = {k: b[:, ix['SIG_%s(GLB)' % k]] for k in ('XX', 'YY', 'ZZ', 'XZ', 'YZ', 'XY')}
    vm = np.sqrt(0.5 * ((s['XX'] - s['YY']) ** 2 + (s['YY'] - s['ZZ']) ** 2 +
                        (s['ZZ'] - s['XX']) ** 2) +
                 3.0 * (s['XY'] ** 2 + s['YZ'] ** 2 + s['XZ'] ** 2))
    return pos, vm


def main(d, nsteps=10):
    h = read_history(d)
    step = int(np.argmax(h[:nsteps, 0]))
    f = h[step, 0] * force_per_corner(d)
    xy, elems = read_model(d)
    pts, disp = read_vtk(os.path.join(d, 'DYNAMIC', 'RESULTS_PARA_01_S%06d.vtk' % step))
    data = element_data(xy, elems, pts, disp, 1.0)
    pos, vm = read_points(d, step)
    k = 0
    vx, vy, vv, tris, mean, mats = [], [], [], [], [], []
    for polygon, _, mat in data:
        nv = len(polygon)
        pp, vv_e = pos[k:k + nv], vm[k:k + nv]
        k += nv
        base = len(vx)
        vx += list(pp[:, 0])
        vy += list(pp[:, 1])
        vv += list(vv_e)
        tris.append([base, base + 1, base + 2])
        if nv == 4:
            tris.append([base, base + 2, base + 3])
        mean.append(vv_e.mean())
        mats.append(mat)
    mean, mats, vv = np.array(mean), np.array(mats), np.array(vv)
    print('step %d, F = %.2f N per corner' % (step, f))
    for m, name in ((1, 'rigid parts'), (2, 'TPU hinges')):
        sel = mats == m
        print('  %-12s von Mises: max %.2f MPa, mean %.2f MPa' % (
            name, mean[sel].max(), mean[sel].mean()))
    polys = [p for p, _, _ in data]
    allp = np.concatenate(polys)
    lim = 1.04 * np.abs(allp).max()

    def draw(ax, sel_mask, vmax, title):
        keep = [i for i in range(len(polys)) if sel_mask[i]]
        ax.add_collection(PolyCollection([polys[i] for i in keep],
                                         array=mean[keep], cmap='turbo',
                                         clim=(0, vmax), edgecolors='none'))
        tri_all = np.array(tris)
        ek = np.repeat(np.arange(len(polys)), [2 if len(p) == 4 else 1 for p in polys])
        tsel = tri_all[np.isin(ek, keep)]
        if len(tsel):
            tc = ax.tripcolor(Triangulation(vx, vy, tsel), vv, shading='gouraud',
                              cmap='turbo', vmin=0, vmax=vmax)
        ax.set_aspect('equal')
        ax.set_xlim(-lim, lim)
        ax.set_ylim(-lim, lim)
        ax.axis('off')
        ax.set_title(title, fontsize=9)
        return tc

    vmax = float(np.percentile(mean[mats == 1], 98))
    fig, ax = plt.subplots(figsize=(7.2, 6.4))
    tc = draw(ax, np.ones(len(polys), bool), vmax,
              'von Mises stress, F = %.2f N per corner' % f)
    cb = fig.colorbar(tc, ax=ax, shrink=0.8)
    cb.set_label('von Mises stress [MPa]')
    fig.tight_layout()
    fig.savefig(os.path.join(d, 'auxetic_max_stress.png'), dpi=220)
    plt.close(fig)
    fig, ax = plt.subplots(figsize=(7.2, 6.4))
    tc = draw(ax, mats == 2, float(mean[mats == 2].max()),
              'TPU hinges only: von Mises stress [MPa], own scale')
    ax.add_collection(PolyCollection([p for p, m in zip(polys, mats) if m == 1],
                                     facecolors='#e6e8ec', edgecolors='none',
                                     zorder=0))
    cb = fig.colorbar(tc, ax=ax, shrink=0.8)
    cb.set_label('von Mises stress [MPa]')
    fig.tight_layout()
    fig.savefig(os.path.join(d, 'auxetic_max_stress_hinge.png'), dpi=220)


if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 10)
