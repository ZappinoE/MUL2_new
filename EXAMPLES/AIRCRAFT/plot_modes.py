"""Pictures of the aircraft demonstrator from DYNAMIC/RESULTS_DYN_PARA.vtk.

    python EXAMPLES/AIRCRAFT/plot_modes.py CASE_DIR [mode ...]

writes CASE_DIR/aircraft_geometry.png and CASE_DIR/aircraft_mode_NN.png
(top and side views, colour = modulus of the modal displacement, the
points are moved by the mode scaled to a 2 m maximum), and prints a table
with the frequency, the fraction of the points that take part in the mode
(support) and the share of the modal energy in fuselage, wings and fin.
"""
import os
import re
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402


def read_vtk(path, wanted=None):
    text = open(path).read().split('\n')
    i, pts, modes = 0, None, {}
    while i < len(text):
        line = text[i]
        if line.startswith('POINTS'):
            n = int(line.split()[1])
            pts = np.array([[float(v) for v in text[i + 1 + k].split()]
                            for k in range(n)])
            i += n
        elif line.startswith('VECTORS'):
            m = re.search(r'Mode:(\d+)-Freq:([\d.E+-]+)Hz', line)
            k, f = int(m.group(1)), float(m.group(2))
            if wanted is None or k in wanted:
                modes[k] = (f, np.array(
                    [[float(v) for v in text[i + 1 + q].split()]
                     for q in range(n)]))
            i += n
        i += 1
    return pts, modes


def views(ax_top, ax_side, p, c, vmax):
    ax_top.scatter(p[:, 0], p[:, 1], c=c, s=0.6, cmap='turbo', vmin=0,
                   vmax=vmax, linewidths=0)
    ax_side.scatter(p[:, 0], p[:, 2], c=c, s=0.6, cmap='turbo', vmin=0,
                    vmax=vmax, linewidths=0)
    for ax, lab in ((ax_top, 'y'), (ax_side, 'z')):
        ax.set_aspect('equal')
        ax.set_xlabel('x [m]')
        ax.set_ylabel('%s [m]' % lab)


def main():
    case = sys.argv[1]
    want = [int(a) for a in sys.argv[2:]] or None
    pts, modes = read_vtk(os.path.join(case, 'DYNAMIC',
                                       'RESULTS_DYN_PARA.vtk'), want)
    fig, (a, b) = plt.subplots(2, 1, figsize=(11, 8.5))
    part = np.where(np.abs(pts[:, 1]) > 2.4, 1.0, 0.0)
    part = np.where((np.abs(pts[:, 1]) < 0.5) & (pts[:, 2] > 3.0), 2.0, part)
    views(a, b, pts, part, 2.0)
    a.set_title('MUL2_NEW aircraft demonstrator: %d points of the VTK '
                '(fuselage, wings, fin)' % len(pts))
    fig.tight_layout()
    fig.savefig(os.path.join(case, 'aircraft_geometry.png'), dpi=130)
    plt.close(fig)
    wing = (np.abs(pts[:, 1]) > 2.4) & (pts[:, 2] < 3.0)
    vtp = (np.abs(pts[:, 1]) < 0.5) & (pts[:, 2] > 3.0)
    print('mode  freq[Hz]  support   fuselage  wings   fin')
    for k in sorted(modes):
        f, u = modes[k]
        mag = np.linalg.norm(u, axis=1)
        e = mag ** 2
        sup = float((mag > 0.1 * mag.max()).mean())
        print('%3d %9.3f  %6.2f   %6.2f  %6.2f  %5.2f' % (
            k, f, sup, e[~wing & ~vtp].sum() / e.sum(),
            e[wing].sum() / e.sum(), e[vtp].sum() / e.sum()))
        if f < 1e-3:
            continue
        fig, (a, b) = plt.subplots(2, 1, figsize=(11, 8.5))
        views(a, b, pts + 2.0 * u / mag.max(), mag / mag.max(), 1.0)
        a.set_title('mode %d, %.2f Hz' % (k, f))
        fig.tight_layout()
        fig.savefig(os.path.join(case, 'aircraft_mode_%02d.png' % k), dpi=130)
        plt.close(fig)


if __name__ == '__main__':
    main()
