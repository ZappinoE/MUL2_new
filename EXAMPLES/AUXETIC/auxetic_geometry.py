"""Geometry of the bistable auxetic block and of the hexagonal cell.

Same construction as AUXETIC/auxetic_cell_geometry.m (method 'general'): a
regular N-gon block of side L; on every side a cut starts at the offset t
from the arrival vertex and is rotated by (360/N + theta); the intersections
of the cut lines of consecutive sides are the vertices H_i of the central
(rotating) polygon; the lateral pieces are [V_i, A_(i-1), H_i, A_i].

A hexagonal cell is six triangular blocks (N = 3) around the origin, every
block the mirror image of the previous one across the shared radial side, so
that the cuts of adjacent blocks continue each other.  The lateral pieces of
adjacent blocks that share a stretch of side form one rigid part (as in the
Adams model of the thesis).
"""
import math

import numpy as np


def rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])


def block(n, side, t, theta_deg):
    """vertices V, offset points A and central polygon H of one block."""
    th = math.radians(theta_deg)
    ext = 2 * math.pi / n
    v, a, rays = [], [], []
    pos, d = np.zeros(2), np.array([1.0, 0.0])
    for _ in range(n):
        v.append(pos.copy())
        pos = pos + side * d
        d = rot(d, ext)
    v = np.array(v)
    for i in range(n):
        p, q = v[i], v[(i + 1) % n]
        e = (q - p) / np.linalg.norm(q - p)
        a.append(q - t * e)
        rays.append(rot(e, ext + th))
    h = []
    for i in range(n):
        j = (i - 1) % n
        m = np.array([rays[i], -rays[j]]).T
        s = np.linalg.solve(m, a[j] - a[i])
        h.append(a[i] + s[0] * rays[i])
    return v, np.array(a), np.array(h)


def reflection(angle):
    """reflection across the line through the origin at `angle` [rad]"""
    c, s = math.cos(2 * angle), math.sin(2 * angle)
    return np.array([[c, s], [s, -c]])


def hex_cell(side=20.0, t=3.0, theta=0.0):
    """six mirrored triangular blocks.  Returns a dict with the rotating
    triangles, the rigid parts (merged lateral pieces) and the hinges."""
    v0, a0, h0 = block(3, side, t, theta)
    maps, m = [], np.eye(2)
    for k in range(6):
        if k > 0:
            m = reflection(math.radians(60 * k)) @ m
        maps.append(m.copy())
    parts, segs, parent = [], {}, []

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def unite(x, y):
        x, y = find(x), find(y)
        if x != y:
            parent[x] = y

    def key(p):
        return (round(float(p[0]), 4) + 0.0, round(float(p[1]), 4) + 0.0)

    def reg(p, q, pid):
        k = tuple(sorted((key(p), key(q))))
        if k in segs:
            unite(segs[k], pid)
        else:
            segs[k] = pid

    hinges = []
    for k in range(6):
        mk = maps[k]
        hm = [mk @ h for h in h0]
        rid = len(parts)
        parts.append(dict(kind='ROT', block=k, pts=np.array(hm)))
        parent.append(rid)
        lat = []
        for i in range(3):
            im = (i - 1) % 3
            pts = np.array([mk @ v0[i], mk @ a0[im], hm[i], mk @ a0[i]])
            pid = len(parts)
            parts.append(dict(kind='EST', block=k, pts=pts))
            parent.append(pid)
            lat.append(pid)
            reg(pts[1], pts[0], pid)
            reg(pts[0], pts[3], pid)
        for i in range(3):
            hinges.append(dict(p=hm[i], rot=rid, est=lat[i], block=k,
                               corner=i))
    groups = {}
    for i, p in enumerate(parts):
        if p['kind'] == 'EST':
            groups.setdefault(find(i), len(groups) + 1)
            p['group'] = groups[find(i)]
        else:
            p['group'] = 0
    return dict(parts=parts, hinges=hinges, n_groups=len(groups),
                side=side, t=t, theta=theta)
