"""Load - opening paths of several runs on one figure.

    python EXAMPLES/AUXETIC/plot_paths.py OUT.png label1=DIR1 label2=DIR2 ... [--steps N]

Every DIR is a run with TIME_HISTORY.dat; the force on a corner is
TIME x (reference force of BC.dat).  Only the first N steps are drawn
(arc length wanders after the limit point).
"""
import os
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plot_auxetic import read_history, force_per_corner  # noqa: E402


def main(out, runs, nmax):
    fig, ax = plt.subplots(figsize=(5.5, 3.8))
    for label, d in runs:
        h = read_history(d)[:nmax]
        f = h[:, 0] * force_per_corner(d)
        ax.plot(h[:, 1], f, 'o-', ms=2.5, label=label)
        k = int(f.argmax())
        print('%-22s limit load %.2f N at %.2f mm' % (label, f[k], h[k, 1]))
    ax.set_xlabel('radial displacement of the corners [mm]')
    ax.set_ylabel('force on each corner [N]')
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(out, dpi=150)


if __name__ == '__main__':
    args = sys.argv[1:]
    nmax = 10 ** 6
    if '--steps' in args:
        i = args.index('--steps')
        nmax = int(args[i + 1])
        del args[i:i + 2]
    main(args[0], [a.split('=', 1) for a in args[1:]], nmax)
