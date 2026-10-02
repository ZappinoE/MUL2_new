"""Figures of the HLE chapters (generated from the same formulas as the code)."""
import math
import os

import figs
from figs import Svg, BLUE, LBLUE, GREY, RED, LRED, GREEN, LGREEN, PURPLE, \
    LPURPLE, YEL, LYEL


# ---------------------------------------------------------------- formulas
def legendre(n, x):
    p0, p1 = 1.0, x
    if n == 0:
        return p0
    for k in range(2, n + 1):
        p0, p1 = p1, ((2 * k - 1) * x * p1 - (k - 1) * p0) / k
    return p1


def phi(k, x):
    return (legendre(k, x) - legendre(k - 2, x)) / math.sqrt(2 * (2 * k - 1))


def modes(p):
    """list of (kind, label, function(r, s)) in the order of the code."""
    rv = [-1, 1, 1, -1]
    sv = [-1, -1, 1, 1]
    out = []
    for i in range(4):
        out.append(('vertex', 'N%d' % (i + 1),
                    lambda r, s, i=i: 0.25 * (1 + rv[i] * r) * (1 + sv[i] * s)))
    for k in range(2, p + 1):
        out.append(('side', 'side 1, k=%d' % k,
                    lambda r, s, k=k: 0.5 * (1 - s) * phi(k, r)))
        out.append(('side', 'side 2, k=%d' % k,
                    lambda r, s, k=k: 0.5 * (1 + r) * phi(k, s)))
        out.append(('side', 'side 3, k=%d' % k,
                    lambda r, s, k=k: 0.5 * (1 + s) * phi(k, r)))
        out.append(('side', 'side 4, k=%d' % k,
                    lambda r, s, k=k: 0.5 * (1 - r) * phi(k, s)))
        if k < 4:
            continue
        for i in range(k - 2, 1, -1):
            j = k - i
            out.append(('internal', 'phi%d phi%d' % (i, j),
                        lambda r, s, i=i, j=j: phi(i, r) * phi(j, s)))
    return out


def heat(v):
    """diverging blue (negative) - white - red (positive), v in [-1, 1]."""
    v = max(-1.0, min(1.0, v))
    if v >= 0:
        return 'rgb(%d,%d,%d)' % (255, int(255 - 150 * v), int(255 - 175 * v))
    v = -v
    return 'rgb(%d,%d,%d)' % (int(255 - 175 * v), int(255 - 120 * v), 255)


# ---------------------------------------------------------------- figures
def fig_hle_modes():
    """Fig: functions of the HLE up to order 5 (as the paper's Fig. 1)."""
    cell, n, gap = 62, 10, 8
    rows = [(1, 'p = 1'), (2, 'p = 2'), (3, 'p = 3'), (4, 'p = 4'),
            (5, 'p = 5')]
    full = modes(5)
    per_row = {1: 4, 2: 4, 3: 4, 4: 5, 5: 6}
    s = Svg(40 + 7 * (cell + gap) + 120, 30 + len(rows) * (cell + 34))
    idx = 0
    colors = {'vertex': BLUE, 'side': GREEN, 'internal': RED}
    for r_i, (p, name) in enumerate(rows):
        y0 = 30 + r_i * (cell + 34)
        s.text(8, y0 + cell / 2 + 4, name, 12, 'start', BLUE, 'bold')
        for c in range(per_row[p]):
            kind, lab, f = full[idx]
            idx += 1
            x0 = 62 + c * (cell + gap)
            vals = []
            for a in range(n):
                for b in range(n):
                    r = -1 + 2 * (a + 0.5) / n
                    sc = -1 + 2 * (b + 0.5) / n
                    vals.append((a, b, f(r, sc)))
            m = max(abs(v) for _, _, v in vals) or 1.0
            for a, b, v in vals:
                s.rect(x0 + a * cell / n, y0 + (n - 1 - b) * cell / n,
                       cell / n + 0.3, cell / n + 0.3, heat(v / m), 'none',
                       0, rx=0)
            s.rect(x0, y0, cell, cell, 'none', colors[kind], 1.4, rx=0)
            s.text(x0 + cell / 2, y0 + cell + 12, '%d' % idx, 10, 'middle',
                   colors[kind], 'bold')
            s.text(x0 + cell / 2, y0 + cell + 23, lab, 7.5, 'middle', GREY)
    lx = 62 + 6 * (cell + gap) + 18
    s.text(lx, 40, 'blue = vertex\ngreen = side\nred = internal', 10, 'start',
           '#222')
    s.text(lx, 100, 'colour: value of the\nfunction, normalised;\nred +, blue -', 9.5,
           'start', GREY)
    s.save('hle_modes')


def fig_hle_interface():
    """Fig: shared side of two sub-elements of different order."""
    s = Svg(740, 330)
    # left element p = 4, right element p = 2
    def square(x, y, size, fill, stroke, label):
        s.rect(x, y, size, size, fill, stroke, 1.6, rx=0)
        s.text(x + size / 2, y + size + 16, label, 11, 'middle', stroke, 'bold')
    square(40, 40, 130, LBLUE, BLUE, 'element A: p = 4')
    square(170, 40, 130, LGREEN, GREEN, 'element B: p = 2')
    s.line(170, 40, 170, 170, RED, 3)
    s.text(105, 20, 'side modes k = 2, 3, 4', 10, 'middle', BLUE)
    s.text(235, 20, 'side modes k = 2', 10, 'middle', GREEN)
    s.text(170, 195, 'shared side keeps\nk = 2 .. min(4, 2) = 2\n(modes k = 3, 4 of A\nare omitted)',
           9.5, 'middle', RED)
    # direction arrows
    s.arrow(150, 165, 150, 50, None, BLUE)
    s.text(140, 110, 'local\ns of A', 9, 'end', BLUE)
    s.arrow(190, 165, 190, 50, None, GREEN)
    s.text(200, 110, 'local\ns of B', 9, 'start', GREEN)
    s.text(170, 252, 'both local directions agree with the global one\n(lower node id -> higher node id): no sign change',
           9.5, 'middle', GREY)
    # right panel: reversed direction
    square(430, 40, 130, LBLUE, BLUE, 'element A')
    square(560, 40, 130, LGREEN, GREEN, 'element B (numbering rotated by 2)')
    s.line(560, 40, 560, 170, RED, 3)
    s.arrow(540, 165, 540, 50, None, BLUE)
    s.arrow(580, 50, 580, 165, None, GREEN)
    s.text(625, 110, 'local s of B\nopposite to A', 9, 'start', GREEN)
    s.text(560, 195, 'phi_k(-s) = (-1)^k phi_k(s)\nB uses the sign (-1)^k', 9.5, 'middle', RED)
    # mini plots of phi_k
    ox, oy, w, h = 440, 262, 240, 54
    s.line(ox, oy + h / 2, ox + w, oy + h / 2, '#999', 0.8)
    s.line(ox + w / 2, oy, ox + w / 2, oy + h, '#999', 0.8)
    for k, col in ((2, BLUE), (3, RED), (4, GREEN)):
        pts = []
        for i in range(61):
            x = -1 + 2 * i / 60
            pts.append((ox + (x + 1) / 2 * w, oy + h / 2 - phi(k, x) * 80))
        s.poly(pts, 'none', col, 1.6, close=False)
        s.text(ox + w + 6, oy + h / 2 - phi(k, 0.8) * 80 + 3,
               'k=%d' % k, 9, 'start', col)
    s.text(ox + w / 2, oy - 4, 'phi_k(s), s from -1 to 1', 9.5, 'middle', GREY)
    s.save('hle_interface')


def blending(v, mid, r, s):
    """Python twin of HLE_MAP_EVALUATE (quarter annulus)."""
    rv = [-1, 1, 1, -1]
    sv = [-1, -1, 1, 1]
    x = [0.0, 0.0]
    for i in range(4):
        n = 0.25 * (1 + rv[i] * r) * (1 + sv[i] * s)
        x[0] += n * v[i][0]
        x[1] += n * v[i][1]
    sides = {2: (1, 2, 0.5 * (1 + r), s), 4: (0, 3, 0.5 * (1 - r), s)}
    for side, (a, b, beta, t) in sides.items():
        m = mid[side]
        if m is None:
            continue
        A, B = v[a], v[b]
        # circle through A, m, B
        d = 2 * (A[0] * (m[1] - B[1]) + m[0] * (B[1] - A[1]) + B[0] * (A[1] - m[1]))
        a2, m2, b2 = sum(c * c for c in A), sum(c * c for c in m), sum(c * c for c in B)
        cx = (a2 * (m[1] - B[1]) + m2 * (B[1] - A[1]) + b2 * (A[1] - m[1])) / d
        cz = (a2 * (B[0] - m[0]) + m2 * (A[0] - B[0]) + b2 * (m[0] - A[0])) / d
        ta = math.atan2(A[1] - cz, A[0] - cx)
        tm = math.atan2(m[1] - cz, m[0] - cx)
        tb = math.atan2(B[1] - cz, B[0] - cx)
        am = (tm - ta) % (2 * math.pi)
        ab = (tb - ta) % (2 * math.pi)
        dth = ab if am < ab else ab - 2 * math.pi
        rad = math.hypot(A[0] - cx, A[1] - cz)
        th = ta + dth * 0.5 * (t + 1)
        cur = (cx + rad * math.cos(th), cz + rad * math.sin(th))
        lin = (0.5 * (1 - t) * A[0] + 0.5 * (1 + t) * B[0],
               0.5 * (1 - t) * A[1] + 0.5 * (1 + t) * B[1])
        x[0] += beta * (cur[0] - lin[0])
        x[1] += beta * (cur[1] - lin[1])
    return x


def fig_hle_map():
    """Fig: natural square and blending map of a quarter annulus."""
    s = Svg(740, 300)
    ri, ro = 0.6, 1.0
    v = [(ri, 0.0), (ro, 0.0), (0.0, ro), (0.0, ri)]
    mid = {2: (ro * math.cos(math.pi / 4), ro * math.sin(math.pi / 4)),
           4: (ri * math.cos(math.pi / 4), ri * math.sin(math.pi / 4))}
    # natural square
    ox, oy, sz = 40, 60, 150
    s.rect(ox, oy, sz, sz, '#f6f9fd', BLUE, 1.6, rx=0)
    for i in range(1, 8):
        t = i / 8
        s.line(ox + t * sz, oy, ox + t * sz, oy + sz, '#c9d6e8', 0.8)
        s.line(ox, oy + t * sz, ox + sz, oy + t * sz, '#c9d6e8', 0.8)
    for lab, (a, b) in zip('1234', [(0, 1), (1, 1), (1, 0), (0, 0)]):
        pass
    s.text(ox + sz / 2, oy + sz + 18, 'natural square (r, s)', 11, 'middle', BLUE,
           'bold')
    for (px, py), lab in (((0, 1), 1), ((1, 1), 2), ((1, 0), 3), ((0, 0), 4)):
        s.circle(ox + px * sz, oy + py * sz, 4, BLUE)
        s.text(ox + px * sz + (8 if px else -8), oy + py * sz + (14 if py else -6),
               str(lab), 10, 'start' if px else 'end')
    s.arrow(215, 135, 285, 135, None, '#333')
    s.text(250, 125, 'Q(r, s)', 11, 'middle', '#333')
    # mapped annulus sector: plain bilinear vs blending
    def draw(ox2, oy2, scale, use_mid, title):
        n = 8
        for i in range(n + 1):
            t = -1 + 2 * i / n
            for fixed in ('r', 's'):
                pts = []
                for j in range(41):
                    u = -1 + 2 * j / 40
                    r_, s_ = (t, u) if fixed == 'r' else (u, t)
                    x, z = blending(v, mid if use_mid else {2: None, 4: None},
                                    r_, s_)
                    pts.append((ox2 + x * scale, oy2 - z * scale))
                edge = (i in (0, n))
                s.poly(pts, 'none', RED if edge else '#8aa6cf',
                       2.0 if edge else 0.9, close=False)
        s.text(ox2 + scale * 0.5, oy2 + 22, title, 11, 'middle', BLUE, 'bold')
    draw(310, 250, 170, True, 'blending map: exact circles')
    draw(530, 250, 170, False, 'bilinear map: straight sides')
    s.save('hle_map')


def fig_hle_flow():
    s = Svg(740, 470)
    bx, w, h = 40, 330, 40
    steps = [
        ('EXP_CONN_nn.dat: "HQ4 id lam n1 n2 n3 n4 p [m1 m2 m3 m4]"', LBLUE, BLUE),
        ('READ_EXPANSION_ELEMENTS: topology = TOPOLOGY_HQ_BASE + p, mid nodes', LBLUE, BLUE),
        ('BUILD_HLE_MESH: vertex terms, side table (min order, id order),\ninternal modes, MODE_TERM / MODE_SIGN, NODE_TERM', LGREEN, GREEN),
        ('BUILD_DOF_LAYOUT: terms per (node, field) = mesh N_TERM', LGREEN, GREEN),
        ('BUILD_REFERENCE_RULE: N_FUNC shapes (EVALUATE_HLE_SHAPE), p+2 points', LPURPLE, PURPLE),
        ('BUILD_EXPANSION_GEOMETRY_CACHE: blending map, N_FUNC gradients', LPURPLE, PURPLE),
        ('EVALUATE_EXPANSION_FACTOR (HLE): MODE_SIGN * shape of local mode\nwith MODE_TERM = term, 0 elsewhere', LPURPLE, PURPLE),
        ('assembly: COUPLED(t, s) = terms in a common sub-element', LYEL, YEL),
        ('boundary: HLE_TERM_ON_PLANE, NODE_TERM for point loads', LYEL, YEL),
        ('recovery: PLACE with the same map and the same factor', LRED, RED),
    ]
    y = 14
    for i, (t, f, st) in enumerate(steps):
        hh = 46 if '\n' in t else h
        s.box(bx, y, 660, hh, t, f, st, 10)
        if i < len(steps) - 1:
            s.arrow(bx + 330, y + hh, bx + 330, y + hh + 8, None, '#333')
        y += hh + 8
    s.save('hle_flow')


def make_all():
    fig_hle_modes()
    fig_hle_interface()
    fig_hle_map()
    fig_hle_flow()


if __name__ == '__main__':
    make_all()
