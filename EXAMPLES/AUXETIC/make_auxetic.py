"""Hexagonal auxetic cell (six triangular blocks, theta = 0) with the exact
shape of the parts, extruded plates (analysis 108, geometric nonlinearity).

    python EXAMPLES/AUXETIC/make_auxetic.py --out RUN --force 15 --steps 150 \
        --load-control [--refine 1]
    cd RUN ; MUL2_V3.exe INPUT
    python EXAMPLES/AUXETIC/plot_auxetic.py RUN

Units: mm, N, MPa.  Every rigid part (the six rotating triangles and the
lateral pieces, merged where adjacent blocks share a side) is meshed with its
exact polygon (`T6` plates, thickness S); the cuts are zero-width cracks
(separate nodes) between the lateral pieces and a gap KERF between a
triangle and the pieces around it.  The hinges are TPU strips (`Q9` plates,
width HW along the cut, length KERF across it) that bridge the gap at the
end of each triangle edge, as in the print.  All the parts are joined by
shared nodes; the model is planar (out-of-plane displacement of the top face
fixed, in-plane rigid motions removed with a pin and a roller at the
hub).  Loads: radial forces at the six corners of the hexagon.
"""
import argparse
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'TESTS', 'VALIDATION'))
sys.path.insert(0, HERE)
import vlib as V  # noqa: E402
from auxetic_geometry import hex_cell  # noqa: E402

# ------------------------------------------------------------ parameters
SIDE, T_OFF, THETA = 20.0, 3.0, 0.0      # block side, cut offset, cut angle
S = 2.0                                  # thickness of the print [mm]
HW = 1.0                                 # width of the TPU hinge (along the cut)
KERF = 0.6                               # gap crossed by the hinge (its length)
NB = 2                                   # hinge elements along its width
E_RIGID, E_TPU, NU = 2000.0, 30.0, 0.38  # MPa (PLA-like, TPU 95A-like)
RHO = 1.2e-9                             # t/mm^3
REFINE = 1                               # red refinements of the base mesh


def unit(v):
    return v / np.linalg.norm(v)


def signed_area(p):
    p = np.asarray(p)
    return 0.5 * (np.dot(p[:, 0], np.roll(p[:, 1], -1)) -
                  np.dot(p[:, 1], np.roll(p[:, 0], -1)))


class Mesh:
    """nodes are unique per (group, position): parts of the same rigid part
    share their nodes, different parts keep their own (zero-width cracks)"""

    def __init__(self):
        self.xy, self.grp, self.index = [], [], {}
        self.elems = []              # [kind, [nodes], material]

    def node(self, group, p):
        key = (group, round(float(p[0]), 6) + 0.0, round(float(p[1]), 6) + 0.0)
        if key not in self.index:
            self.index[key] = len(self.xy)
            self.xy.append((key[1], key[2]))
            self.grp.append(group)
        return self.index[key]

    def new_node(self, group, p):
        self.xy.append((float(p[0]), float(p[1])))
        self.grp.append(group)
        return len(self.xy) - 1


def ccw(m, ids):
    pts = [m.xy[i] for i in ids]
    return ids if signed_area(pts) > 0 else ids[::-1]


def fan_triangles(m, ids, on_edge):
    """triangulate the polygon with vertices `ids` (CCW) where `on_edge`
    maps frozenset({u, v}) -> sorted list of extra nodes on that edge"""
    n = len(ids)
    tris = []
    if n == 3:
        tris = [list(ids)]
    else:
        for diag in (0, 1):
            a, b, c, d = ids[diag:] + ids[:diag]
            t1, t2 = [a, b, c], [a, c, d]
            if all(signed_area([m.xy[i] for i in t]) > 1e-9 for t in (t1, t2)):
                tris = [t1, t2]
                break
        assert tris, 'cannot triangulate a piece'
    out = []
    while tris:
        t = tris.pop()
        for k in range(3):
            u, v, w = t[k], t[(k + 1) % 3], t[(k + 2) % 3]
            ex = on_edge.get(frozenset((u, v)))
            if ex:
                # extras in the order u -> v
                du = lambda i: np.hypot(m.xy[i][0] - m.xy[u][0], m.xy[i][1] - m.xy[u][1])
                ex = sorted(ex, key=du)
                chain = [u] + ex + [v]
                for a, b in zip(chain[:-1], chain[1:]):
                    tris.append([w, a, b] if signed_area(
                        [m.xy[w], m.xy[a], m.xy[b]]) > 0 else [w, b, a])
                break
        else:
            out.append(t)
    return out


def build_base(m):
    cell = hex_cell(SIDE, T_OFF, THETA)
    parts, hinges = cell['parts'], cell['hinges']
    tri_of_block = {p['block']: p for p in parts if p['kind'] == 'ROT'}
    piece_extra = {}                       # part index -> (edge points)
    tri_poly = {}
    bridges = []
    for k, p in tri_of_block.items():
        hm = p['pts']
        cen = hm.mean(axis=0)
        e = [unit(hm[j] - hm[(j - 1) % 3]) for j in range(3)]     # edge j-1 -> j
        n = []
        for j in range(3):
            nn = np.array([-e[j][1], e[j][0]])
            if nn @ (cen - hm[j]) < 0:
                nn = -nn
            n.append(nn)
        # shifted lines: point hm[j-1] + g n_j, direction e_j
        sh = []
        for j in range(3):
            j2 = (j + 1) % 3                # vertex j is the end of edge j and
            # start of edge j+1 : intersection of the shifted edges j, j+1
            p1, d1 = hm[(j - 1) % 3] + KERF * n[j], e[j]
            p2, d2 = hm[j] + KERF * n[j2], e[j2]
            s = np.linalg.solve(np.array([d1, -d2]).T, p2 - p1)
            sh.append(p1 + s[0] * d1)
        sh = np.array(sh)
        tri_poly[k] = sh
        for h in [h for h in hinges if h['block'] == k]:
            j = h['corner']
            a_, b_ = sh[(j - 1) % 3], sh[j]
            ej = unit(b_ - a_)
            T = [b_ - HW * ej * m_ / NB for m_ in range(NB + 1)]
            Q = [t - KERF * n[j] for t in T]
            bridges.append(dict(block=k, corner=j, T=T, Q=Q, est=h['est']))
            piece_extra.setdefault(h['est'], []).append(Q)
    # --- triangles: fan from the centroid over the boundary with extras
    for k, sh in tri_poly.items():
        gk = 't%d' % k
        ring = []
        for j in range(3):
            ring.append(sh[j])
            br = [b for b in bridges if b['block'] == k and b['corner'] == (j + 1) % 3]
            if br:                            # edge j -> j+1 ends at vertex j+1
                T = br[0]['T']
                ring.extend(T[m_] for m_ in range(NB, 0, -1))
        ids = [m.node(gk, q) for q in ring]
        ids = ccw(m, ids)
        c = m.node(gk, np.mean(sh, axis=0))
        for a, b in zip(ids, ids[1:] + ids[:1]):
            m.elems.append(['T', [c, a, b] if signed_area(
                [m.xy[c], m.xy[a], m.xy[b]]) > 0 else [c, b, a], 1])
    # --- lateral pieces
    for pi, p in enumerate(parts):
        if p['kind'] != 'EST':
            continue
        gk = 'g%d' % p['group']
        v, a_prev, hpt, a_next = p['pts']
        ids4 = [m.node(gk, q) for q in (v, a_prev, hpt, a_next)]
        on_edge = {}
        for Q in piece_extra.get(pi, []):
            # edge a_prev -> h : extras Q[NB] ... Q[0] (Q[0] nearest to h)
            ex = [m.node(gk, Q[mm]) for mm in range(NB, -1, -1)]
            on_edge[frozenset((ids4[1], ids4[2]))] = ex
        ids4c = ccw(m, ids4)
        for t in fan_triangles(m, ids4c, on_edge):
            m.elems.append(['T', t, 1])
    # --- hinges (TPU)
    for b in bridges:
        gk_t, gk_p = 't%d' % b['block'], 'g%d' % parts[b['est']]['group']
        for mm in range(NB):
            ids = [m.node(gk_t, b['T'][mm]), m.node(gk_t, b['T'][mm + 1]),
                   m.node(gk_p, b['Q'][mm + 1]), m.node(gk_p, b['Q'][mm])]
            m.elems.append(['Q', ccw(m, ids), 2])
    return cell, parts


def refine(m, times):
    for _ in range(times):
        mid = {}

        def midpoint(u, v):
            key = frozenset((u, v))
            if key not in mid:
                g = m.grp[u] if m.grp[u] == m.grp[v] else 'b%d' % len(m.xy)
                p = (np.array(m.xy[u]) + np.array(m.xy[v])) / 2
                mid[key] = m.new_node(g, p)
            return mid[key]

        new = []
        for kind, n, mat in m.elems:
            if kind == 'T':
                a, b, c = n
                ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
                new += [['T', [a, ab, ca], mat], ['T', [ab, b, bc], mat],
                        ['T', [ca, bc, c], mat], ['T', [ab, bc, ca], mat]]
            else:
                a, b, c, d = n
                ab, bc, cd, da = (midpoint(a, b), midpoint(b, c),
                                  midpoint(c, d), midpoint(d, a))
                g = m.grp[a] if len({m.grp[i] for i in n}) == 1 else 'b%d' % len(m.xy)
                ctr = m.new_node(g, np.mean([m.xy[i] for i in n], axis=0))
                new += [['Q', [a, ab, ctr, da], mat], ['Q', [ab, b, bc, ctr], mat],
                        ['Q', [ctr, bc, c, cd], mat], ['Q', [da, ctr, cd, d], mat]]
        m.elems = new


def quadratic(m):
    """T3 -> T6, Q4 -> Q9 (nodes: corners, midsides, centre)"""
    mid = {}

    def midpoint(u, v):
        key = frozenset((u, v))
        if key not in mid:
            g = m.grp[u] if m.grp[u] == m.grp[v] else 'b%d' % len(m.xy)
            mid[key] = m.new_node(g, (np.array(m.xy[u]) + np.array(m.xy[v])) / 2)
        return mid[key]

    out = []
    for kind, n, mat in m.elems:
        if kind == 'T':
            a, b, c = n
            out.append(['T6', [a, b, c, midpoint(a, b), midpoint(b, c),
                               midpoint(c, a)], mat])
        else:
            a, b, c, d = n
            ctr = m.new_node('b%d' % len(m.xy), np.mean([m.xy[i] for i in n], axis=0))
            out.append(['Q9', [a, midpoint(a, b), b, midpoint(b, c), c,
                               midpoint(c, d), d, midpoint(d, a), ctr], mat])
    m.elems = out


def free_plane(m, node, other):
    """exact decimal normals; returns (nx, ny, D) of a plane through `node`
    that contains no other node position"""
    q = np.array(m.xy[node])
    arr = np.array(m.xy)
    arr = arr[np.hypot(arr[:, 0] - q[0], arr[:, 1] - q[1]) > 1e-5]
    for a in range(1, 180):
        nx, ny = round(math.cos(math.radians(a + 0.37)), 4), \
            round(math.sin(math.radians(a + 0.37)), 4)
        norm = math.hypot(nx, ny)
        d = np.abs((arr[:, 0] - q[0]) * nx + (arr[:, 1] - q[1]) * ny) / norm
        if d.min() > 1e-5:
            return nx, ny, -(nx * q[0] + ny * q[1])
    raise RuntimeError('no free plane through the node at %s' % (tuple(q),))


def write(m, out, force, steps, lmax, tech, stress_points=False):
    os.makedirs(os.path.join(out, 'INPUT'), exist_ok=True)
    for d in ('REPORT', 'STATIC', 'DYNAMIC', 'WORK'):
        os.makedirs(os.path.join(out, d), exist_ok=True)

    def put(name, text):
        with open(os.path.join(out, 'INPUT', name), 'w', newline='\n') as f:
            f.write(text)

    lines = ['%d' % len(m.xy), '']
    for i, (x, y) in enumerate(m.xy):
        lines.append('%d  %s  %s  0.0D0  TE 1' % (i + 1, V.fmt(x), V.fmt(y)))
    put('NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % len(m.elems), '']
    for k, (kind, n, mat) in enumerate(m.elems):
        el.append('%s %d  %s  1  %d' % (kind, k + 1, ' '.join(str(i + 1) for i in n), mat))
    put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    put('MATERIAL.dat', '2 2\n\nISO-M 1  %s %s %s\nISO-M 2  %s %s %s\n' % (
        V.fmt(E_RIGID), V.fmt(NU), V.fmt(RHO), V.fmt(E_TPU), V.fmt(NU), V.fmt(RHO)))
    put('LAMINATION.dat', '2\n\nLAM2 1 1 0.0 0.0\nLAM2 2 2 0.0 0.0\n')
    for k in (1, 2):
        tm = V.line_mesh('B3', 1, S, lam=k)
        put('EXP_MESH_%02d.dat' % k, tm.mesh_text(False))
        put('EXP_CONN_%02d.dat' % k, tm.conn_text())
    put('ANALYSIS.dat', V.analysis_text(108, 4, plate='MITC'))
    # constraints: top face w = 0; pin at the centre; roller on the x axis
    at_o = [i for i in range(len(m.xy)) if m.xy[i] == (0.0, 0.0)]
    centre = at_o[0]
    hub = [i for i in range(len(m.xy)) if m.grp[i] == m.grp[centre]]
    axis = [i for i in hub if abs(m.xy[i][1]) < 1e-9 and 4.0 < m.xy[i][0] < 15.0]
    roller = min(axis, key=lambda i: abs(m.xy[i][0] - 10.0))
    count = {}
    for xy_ in m.xy:
        k_ = (round(xy_[0], 6), round(xy_[1], 6))
        count[k_] = count.get(k_, 0) + 1
    single = lambda i: count[(round(m.xy[i][0], 6), round(m.xy[i][1], 6))] == 1
    third = min([i for i in hub if i != centre and single(i) and
                 abs(m.xy[i][0]) < 6.0 and m.xy[i][1] > 4.0],
                key=lambda i: abs(m.xy[i][1] - 8.0))
    n1 = free_plane(m, centre, None)
    n2 = free_plane(m, roller, None)
    n3 = free_plane(m, third, None)
    # vertical planes contain the whole thickness of a node (Taylor):
    # pin at the centre, roller on the x axis, one more node out of plane
    recs = [V.dplane(1, n1[0], n1[1], 0, n1[2], 0.0, 0.0, 0.0),
            V.dplane(2, n2[0], n2[1], 0, n2[2], None, 0.0, 0.0),
            V.dplane(3, n3[0], n3[1], 0, n3[2], None, None, 0.0)]
    tips = []
    for i, (x, y) in enumerate(m.xy):
        if abs(math.hypot(x, y) - SIDE) < 1e-6 and m.grp[i].startswith('g'):
            tips.append((math.atan2(y, x), x, y))
    tips = sorted(set((round(a, 6), x, y) for a, x, y in tips))
    for _, x, y in tips:
        e = np.array([x, y]) / math.hypot(x, y)
        for z in (-S / 2, S / 2):
            recs.append(V.fpoint(len(recs) + 1, x, y, z, 0.5 * force * e[0],
                                 0.5 * force * e[1], 0.0))
    put('BC.dat', V.bc_text(recs))
    pts = [(0.99999 * x, 0.99999 * y, 0.0) for _, x, y in tips]
    if stress_points:
        # results (stress) at points of every element, 10 % inside the corners
        for kind, n, _ in m.elems:
            c = n[:3] if kind == 'T6' else [n[0], n[2], n[4], n[6]]
            q = np.array([m.xy[i] for i in c])
            g = q.mean(axis=0)
            pts += [(float(g[0] + 0.9 * (p[0] - g[0])),
                     float(g[1] + 0.9 * (p[1] - g[1])), 0.0) for p in q]
    put('POSTPROCESSING.dat', V.post_text(pts, para=True))
    put('NL_INFO.dat', ('2\n%d\n40\n1.0D-8\n1\n0 0 0 %s\n' % (steps, V.fmt(lmax))
                        if tech == 2 else '1\n%d\n40\n1.0D-8\n1\n' % steps))
    return tips


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(HERE, 'CASE'))
    ap.add_argument('--force', type=float, default=1.0,
                    help='radial force on every corner [N] (load factor 1)')
    ap.add_argument('--steps', type=int, default=100)
    ap.add_argument('--lmax', type=float, default=20.0)
    ap.add_argument('--load-control', action='store_true')
    ap.add_argument('--refine', type=int, default=REFINE)
    ap.add_argument('--stress-points', action='store_true',
                    help='PNT records inside every element (stress maps)')
    a = ap.parse_args()
    mesh = Mesh()
    cell, parts = build_base(mesh)
    refine(mesh, a.refine)
    quadratic(mesh)
    tips = write(mesh, a.out, a.force, a.steps, a.lmax,
                 1 if a.load_control else 2, a.stress_points)
    kinds = {}
    for k, _, _ in mesh.elems:
        kinds[k] = kinds.get(k, 0) + 1
    print('%d nodes, elements %s, %d corners' % (len(mesh.xy), kinds, len(tips)))
    print('written to', a.out)
