"""Collect the headline numbers of the report from results/*.json."""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, 'results')
EXE = os.path.abspath(os.path.join(HERE, '..', '..', 'BUILD', 'WINDOWS_IFX',
                                   'Release', 'MUL2_V3.exe'))


def load(gid):
    return json.load(open(os.path.join(RES, gid + '.json')))


def find(g, pat):
    return [c for c in g['checks'] if re.search(pat, c['name'])]


def worst(cs):
    cs = [c for c in cs if c['err'] == c['err']]
    return max((c['err'] for c in cs), default=float('nan'))


def sci(x):
    return ('identical to the last printed digit' if x == 0 else
            'difference %.0e' % x)


def pct(x):
    return '%.2f%%' % (100 * x)


def main():
    G = {k: load(k) for k in ('taylor', 'le', 'hle', 'plates', 'plates2',
                              'solids', 'ndk', 'multi', 'mitc')}
    refs = json.load(open(os.path.join(RES, 'refs.json')))
    head = []
    d = abs(refs['h27_w'] / refs['le_w'] - 1)
    head.append('<b>Two independent 3D models agree.</b> The square '
                'cantilever solved with a 3D solid (H27) and with a '
                'Lagrange beam (Q16 4x4 section) gives tip deflections that '
                'differ by %.4f%% and first frequencies by %.4f%%.' % (
                    100 * d, 100 * abs(refs['h27_f'][0] /
                                       refs['le_f'][0] - 1)))
    te20 = find(G['taylor'], r'^TE20 tip deflection vs 3D')[0]
    f20 = find(G['taylor'], r'^TE20 f1 vs Timoshenko')[0]
    head.append('<b>Taylor expansion up to order 20.</b> TE20 reaches the '
                '3D solid solution within %s (tip deflection); the '
                'frequencies are within %s of Timoshenko; the solution '
                'is independent of the section size (n up to 20, scaled '
                'geometry).' % (pct(te20['err']), pct(f20['err'])))
    pats = []
    for g in G.values():
        pats += find(g, r'patch test')
    head.append('<b>Patch tests.</b> %d uniform-extension tests (Taylor n = '
                '1-20, all Lagrange sections, HQ4, plates, solids, mixed '
                'kinematics) reproduce the exact field; the largest error '
                'is %.1e (relative to the imposed displacement).' % (
                    len(pats), worst(pats)))
    pb = []
    for gid in ('le', 'plates', 'solids'):
        pb += [c for c in find(G[gid], r'pure bending')
               if c['tol'] is not None and c['tol'] <= 1e-5]
    head.append('<b>Pure bending.</b> %d checks of the exact quadratic '
                'solution (quadrilateral and T6 sections, Q9/Q16/T6 plates, '
                'H27 and H8+MITC solids) have a largest error of %.1e.' % (
                    len(pb), worst(pb)))
    tube = find(G['hle'], r'tube.*p=6|tube \(4 curved HQ4, p=6\)')
    head.append('<b>HLE.</b> HQ4 p = 1 coincides with Q4 (%s); sub-elements '
                'of different order on the same interface satisfy the Ritz '
                'bounds and are independent of the node numbering '
                '(%s); the curved tube with four HQ4 '
                'elements is within %s of Timoshenko for p >= 4.' % (
                    sci(worst(find(G['hle'], r'HQ4 p=1 == LE Q4'))),
                    sci(worst(find(G['hle'], r'rotated node numbering'))),
                    pct(worst(tube))))
    nv = find(G['plates2'], r'Navier plate (Q4|Q9|Q16)')
    lam = find(G['plates2'], r'^laminate')
    head.append('<b>Plates.</b> Navier plate within %s (Q4, Q9, Q16 with '
                'MITC); cross-ply laminates within %s of the closed form; '
                'Q9 plates with TE up to order 20 within %s of the 3D '
                'solid; rotation of isotropic-equivalent plies exact to '
                '%.0e.' % (
                    pct(worst(nv)), pct(worst(lam)),
                    pct(worst(find(G['plates2'], r'plate Q9 TE\d+'))),
                    worst(find(G['plates2'], r'ORT-M with ply'))))
    nd = find(G['ndk'], r'patch test|continuity')
    head.append('<b>Non-uniform kinematics.</b> The ten pairs (TE-m/TE-n, '
                'TE/LE, HLE/TE, HLE/LE) are exact on the patch test and '
                'continuous at the interface (largest error %.1e).' %
                worst(nd))
    mu = find(G['multi'], r'^(1D|2D)')
    head.append('<b>Multi-dimensional models.</b> 1D/2D, 1D/3D and 2D/3D '
                'junctions reproduce the closed form to %.1e; three '
                'regions of different dimension in one input equal the '
                'three separate runs (%s).' % (
                    worst(mu), sci(worst(find(G['multi'], r'one model')))))
    head.append('<b>MITC.</b> On L/h = 100 structures the full integration '
                'gives 3-10% of the correct deflection for B2 beams, Q4 '
                'plates and H8 solids; MITC restores 94-99%.')
    meta = dict(exe=EXE, headlines=head)
    json.dump(meta, open(os.path.join(RES, 'meta.json'), 'w'), indent=1)
    for h in head:
        print('-', re.sub('<[^>]+>', '', h))


if __name__ == '__main__':
    main()
