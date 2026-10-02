"""SVG figure generator for the three guides (no dependencies)."""
import html
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'figures')
BUILD = os.path.join(HERE, '..', 'build')

BLUE = '#1d4f91'
LBLUE = '#dbe7f6'
GREY = '#6b7280'
LGREY = '#eef0f3'
RED = '#b9461b'
LRED = '#fbe5dc'
GREEN = '#2f8f4e'
LGREEN = '#dff1e5'
PURPLE = '#6b4a9a'
LPURPLE = '#ece4f6'
YEL = '#8a6d12'
LYEL = '#fbf1cc'


def esc(s):
    return html.escape(str(s), quote=False)


class Svg:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.e = []

    def raw(self, s):
        self.e.append(s)

    def rect(self, x, y, w, h, fill='#fff', stroke=BLUE, sw=1.2, rx=4,
             dash=None):
        d = ' stroke-dasharray="%s"' % dash if dash else ''
        self.e.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" '
                      'rx="%s" fill="%s" stroke="%s" stroke-width="%s"%s/>'
                      % (x, y, w, h, rx, fill, stroke, sw, d))

    def line(self, x1, y1, x2, y2, stroke='#333', sw=1.2, dash=None,
             arrow=False, marker=None):
        d = ' stroke-dasharray="%s"' % dash if dash else ''
        m = ' marker-end="url(#arr)"' if arrow else ''
        self.e.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" '
                      'stroke="%s" stroke-width="%s"%s%s/>' % (
                          x1, y1, x2, y2, stroke, sw, d, m))

    def poly(self, pts, fill='none', stroke='#333', sw=1.2, close=True,
             dash=None, opacity=None):
        d = ' stroke-dasharray="%s"' % dash if dash else ''
        o = ' fill-opacity="%s"' % opacity if opacity else ''
        tag = 'polygon' if close else 'polyline'
        self.e.append('<%s points="%s" fill="%s" stroke="%s" '
                      'stroke-width="%s"%s%s/>' % (
                          tag, ' '.join('%.1f,%.1f' % p for p in pts), fill,
                          stroke, sw, d, o))

    def path(self, d, fill='none', stroke='#333', sw=1.2, arrow=False,
             dash=None):
        m = ' marker-end="url(#arr)"' if arrow else ''
        da = ' stroke-dasharray="%s"' % dash if dash else ''
        self.e.append('<path d="%s" fill="%s" stroke="%s" stroke-width="%s"'
                      '%s%s/>' % (d, fill, stroke, sw, m, da))

    def circle(self, x, y, r=3.5, fill=BLUE, stroke='#fff', sw=1):
        self.e.append('<circle cx="%.1f" cy="%.1f" r="%s" fill="%s" '
                      'stroke="%s" stroke-width="%s"/>' % (x, y, r, fill,
                                                          stroke, sw))

    def text(self, x, y, s, size=11, anchor='middle', fill='#222',
             weight='normal', italic=False, family=None):
        lines = str(s).split('\n')
        st = ' font-style="italic"' if italic else ''
        fam = ' font-family="%s"' % family if family else ''
        out = []
        for i, ln in enumerate(lines):
            out.append('<text x="%.1f" y="%.1f" font-size="%s" '
                       'text-anchor="%s" fill="%s" font-weight="%s"%s%s>%s'
                       '</text>' % (x, y + i * size * 1.25, size, anchor,
                                    fill, weight, st, fam, esc(ln)))
        self.e.append(''.join(out))

    def box(self, x, y, w, h, label, fill=LBLUE, stroke=BLUE, size=11,
            weight='normal', color='#12355f', rx=5, dash=None):
        self.rect(x, y, w, h, fill, stroke, rx=rx, dash=dash)
        n = len(str(label).split('\n'))
        self.text(x + w / 2, y + h / 2 - (n - 1) * size * 0.62 + size * 0.35,
                  label, size, 'middle', color, weight)

    def diamond(self, cx, cy, w, h, label, fill=LYEL, stroke=YEL, size=10):
        self.poly([(cx, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2),
                   (cx - w / 2, cy)], fill, stroke, 1.2)
        n = len(label.split('\n'))
        self.text(cx, cy - (n - 1) * size * 0.62 + size * 0.35, label, size,
                  'middle', '#4a3a05')

    def arrow(self, x1, y1, x2, y2, label=None, stroke='#333', dash=None,
              lx=None, ly=None, size=9.5):
        self.line(x1, y1, x2, y2, stroke, 1.3, dash, True)
        if label:
            self.text(lx if lx is not None else (x1 + x2) / 2 + 4,
                      ly if ly is not None else (y1 + y2) / 2 - 3, label,
                      size, 'start' if lx is None else 'middle', GREY)

    def elbow(self, pts, label=None, stroke='#333', dash=None,
              lpos=None, size=9.5):
        d = 'M ' + ' L '.join('%.1f,%.1f' % p for p in pts)
        self.path(d, 'none', stroke, 1.3, True, dash)
        if label and lpos:
            self.text(lpos[0], lpos[1], label, size, 'middle', GREY)

    def render(self):
        defs = ('<defs><marker id="arr" viewBox="0 0 10 10" refX="9" '
                'refY="5" markerWidth="7" markerHeight="7" '
                'orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" '
                'fill="#333"/></marker></defs>')
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" '
                'width="%d" height="%d" style="max-width:100%%;height:auto">'
                '%s%s</svg>' % (self.w, self.h, self.w, self.h, defs,
                                ''.join(self.e)))

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, name + '.svg'), 'w',
                  encoding='utf-8') as f:
            f.write(self.render())


# ---------------------------------------------------------------------
# element sketches
# ---------------------------------------------------------------------
def node(s, x, y, label, r=4.5, fill=BLUE, dx=8, dy=-8, size=10):
    s.circle(x, y, r, fill)
    s.text(x + dx, y + dy, label, size, 'start', '#222')


def fig_elements_1d():
    s = Svg(720, 190)
    xs = {'B2': [60, 260], 'B3': [60, 160, 260], 'B4': [60, 126.7, 193.3, 260]}
    y0 = 40
    for k, name in enumerate(['B2', 'B3', 'B4']):
        y = y0 + k * 55
        s.text(14, y + 4, name, 12, 'start', BLUE, 'bold')
        pts = xs[name]
        x_off = 60
        s.line(x_off + 40, y, x_off + 280, y, BLUE, 2)
        order = {'B2': [0, 1], 'B3': [0, 2, 1], 'B4': [0, 3, 1, 2]}[name]
        n = len(pts)
        # node numbers follow the corner nodes first then interior
        coords = [x_off + 40 + 240 * i / (n - 1) for i in range(n)]
        num = list(range(1, n + 1))   # nodes are numbered along the axis
        for c, nn in zip(coords, num):
            node(s, c, y, str(nn), dy=-9, dx=0, size=10)
        s.text(x_off + 300, y + 4, 'xi = -1 ... +1, nodes equally spaced along the axis (local y)',
               9.5, 'start', GREY)
    s.save('elements_1d')


def fig_elements_2d():
    s = Svg(740, 300)
    # Q4
    def quad(ox, oy, size, n, labelpos, name):
        s.rect(ox, oy, size, size, '#f6f9fd', BLUE, 1.6, rx=0)
        for (px, py), lab in labelpos:
            node(s, ox + px * size, oy + (1 - py) * size, str(lab), dx=6,
                 dy=-6, size=9.5)
        s.text(ox + size / 2, oy + size + 18, name, 11, 'middle', BLUE,
               'bold')
    quad(40, 30, 130, 4, [((0, 0), 1), ((1, 0), 2), ((1, 1), 3),
                          ((0, 1), 4)], 'Q4')
    quad(230, 30, 130, 9, [((0, 0), 1), ((.5, 0), 2), ((1, 0), 3),
                           ((1, .5), 4), ((1, 1), 5), ((.5, 1), 6),
                           ((0, 1), 7), ((0, .5), 8), ((.5, .5), 9)], 'Q9')
    quad(430, 30, 130, 16, [((0, 0), 1), ((1 / 3, 0), 2), ((2 / 3, 0), 3),
                            ((1, 0), 4), ((1, 1 / 3), 5), ((1, 2 / 3), 6),
                            ((1, 1), 7), ((2 / 3, 1), 8), ((1 / 3, 1), 9),
                            ((0, 1), 10), ((0, 2 / 3), 11), ((0, 1 / 3), 12),
                            ((1 / 3, 1 / 3), 13), ((2 / 3, 1 / 3), 14),
                            ((2 / 3, 2 / 3), 15), ((1 / 3, 2 / 3), 16)],
         'Q16')
    # T3, T6
    def tri(ox, oy, size, pts, name):
        s.poly([(ox, oy + size), (ox + size, oy + size), (ox, oy)],
               '#f6f9fd', BLUE, 1.6)
        for (px, py), lab in pts:
            node(s, ox + px * size, oy + (1 - py) * size, str(lab), dx=6,
                 dy=-6, size=9.5)
        s.text(ox + size / 2, oy + size + 18, name, 11, 'middle', BLUE,
               'bold')
    tri(40, 190 - 40 + 50 - 50, 0, [], '') if False else None
    s.save('elements_2d')
    # quadrilaterals only in this figure; triangles in a second row
    s2 = Svg(740, 200)
    tri2(s2, 90, 20, 120, [((0, 0), 1), ((1, 0), 2), ((0, 1), 3)], 'T3')
    tri2(s2, 330, 20, 120, [((0, 0), 1), ((1, 0), 2), ((0, 1), 3),
                            ((.5, 0), 4), ((.5, .5), 5), ((0, .5), 6)],
         'T6')
    s2.save('elements_tri')


def tri2(s, ox, oy, size, pts, name):
    s.poly([(ox, oy + size), (ox + size, oy + size), (ox, oy)], '#f6f9fd',
           BLUE, 1.6)
    for (px, py), lab in pts:
        node(s, ox + px * size, oy + (1 - py) * size, str(lab), dx=6, dy=-6,
             size=9.5)
    s.text(ox + size / 2, oy + size + 22, name, 11, 'middle', BLUE, 'bold')


def iso(x, y, z, o=(0, 0), k=60):
    """oblique projection of a cube point."""
    return (o[0] + k * (x + 0.45 * y), o[1] - k * (z + 0.32 * y))


def fig_elements_3d():
    s = Svg(740, 300)
    k = 100
    o = (70, 250)

    def cube(o, labels, name, extra=None):
        c = {}
        for i, (x, y, z) in enumerate([(0, 0, 0), (1, 0, 0), (1, 1, 0),
                                       (0, 1, 0), (0, 0, 1), (1, 0, 1),
                                       (1, 1, 1), (0, 1, 1)]):
            c[i + 1] = iso(x, y, z, o, k)
        faces = [[1, 2, 3, 4], [5, 6, 7, 8], [1, 2, 6, 5], [2, 3, 7, 6],
                 [3, 4, 8, 7], [4, 1, 5, 8]]
        for f in faces:
            s.poly([c[i] for i in f], '#f3f7fc', BLUE, 1.3, opacity='0.5')
        for i in range(1, 9):
            node(s, c[i][0], c[i][1], str(i), dx=6, dy=-5, size=9.5)
        s.text(o[0] + 70, o[1] + 22, name, 11, 'middle', BLUE, 'bold')
    cube(o, None, 'H8: corners 1-4 bottom (z=-1), 5-8 top (z=+1)')
    # H27 ordering sketch: just a table of node classes
    s.text(430, 40, 'H27 node classes', 12, 'start', BLUE, 'bold')
    items = ['1-8   corners (same order as H8)',
             '9-20  mid-edge nodes',
             '21-26 mid-face nodes',
             '27    centre node']
    for i, t in enumerate(items):
        s.text(430, 68 + 22 * i, t, 11, 'start')
    s.text(430, 170, 'Natural coordinates (xi, eta, nu) in [-1, 1]^3.', 10.5,
           'start', GREY)
    s.text(430, 190, 'H20 has corners and mid-edge nodes only.', 10.5,
           'start', GREY)
    s.text(430, 210, 'P6: two triangles (1-3 and 4-6); T4/T10: tetrahedra.',
           10.5, 'start', GREY)
    s.save('elements_3d')


# ---------------------------------------------------------------------
# CUF concept
# ---------------------------------------------------------------------
def fig_cuf_concept():
    s = Svg(740, 300)
    # beam in oblique projection along y
    L = 330
    ox, oy = 60, 220
    a = (ox, oy)
    sec = [(0, 0), (60, 0), (60, -45), (0, -45)]
    dx, dy = L, -55
    for x0, y0 in sec:
        pass

    def box_beam():
        p0 = [(ox + x, oy + y) for x, y in sec]
        p1 = [(ox + x + dx, oy + y + dy) for x, y in sec]
        s.poly([p0[3], p0[2], p1[2], p1[3]], '#e7eef8', BLUE, 1.2)
        s.poly([p0[1], p0[2], p1[2], p1[1]], '#d4e1f3', BLUE, 1.2)
        s.poly(p0, '#f5f8fc', BLUE, 1.6)
        s.poly(p1, '#f5f8fc', BLUE, 1.6)
    box_beam()
    # axis and 1D nodes
    cx0, cy0 = ox + 30, oy - 22
    s.line(cx0, cy0, cx0 + dx, cy0 + dy, RED, 2)
    for i in range(4):
        t = i / 3
        node(s, cx0 + dx * t, cy0 + dy * t, '', 4.5, RED)
    s.text(cx0 + dx / 2 - 10, cy0 + dy / 2 + 30, 'structural 1D mesh (B4)\nN_i(y)', 11,
           'middle', RED)
    # section expansion at right
    sx, sy = 520, 80
    s.text(sx + 70, sy - 20, 'Section expansion F_tau(x, z)', 12, 'middle',
           BLUE, 'bold')
    s.rect(sx, sy, 140, 110, '#f6f9fd', BLUE, 1.6, rx=0)
    for i in range(3):
        for j in range(3):
            node(s, sx + i * 70, sy + j * 55, '', 4, BLUE)
    s.line(sx + 70, sy, sx + 70, sy + 110, BLUE, 0.8, '3 3')
    s.line(sx, sy + 55, sx + 140, sy + 55, BLUE, 0.8, '3 3')
    s.text(sx + 70, sy + 135, 'LE: nodal Lagrange functions (Q9)\nTE: monomials x^a z^b', 10.5,
           'middle', GREY)
    s.arrow(cx0 + dx + 10, cy0 + dy - 10, sx - 10, sy + 40)
    s.text(cx0 + dx + 62, cy0 + dy - 28, 'expansion at every node', 10, 'middle', GREY)
    s.text(375, 280, 'u(x,y,z) = sum_i sum_tau  N_i(y) F_tau(x,z) u_tau,i', 13,
           'middle', '#111', 'bold')
    s.save('cuf_concept')


def fig_taylor_pyramid():
    s = Svg(560, 270)
    s.text(280, 20, 'Taylor monomials x^a z^b of a section, order N = 0..4',
           12, 'middle', BLUE, 'bold')
    for n in range(5):
        y = 55 + n * 42
        s.text(30, y + 4, 'N = %d' % n, 10.5, 'start', GREY)
        for b in range(n + 1):
            a = n - b
            x = 280 + (b - n / 2) * 70
            lab = '1' if n == 0 else ('x' * (1 if a else 0) + ('^%d' % a if a > 1 else '') +
                                       ('z' if b else '') + ('^%d' % b if b > 1 else ''))
            s.box(x - 28, y - 14, 56, 28, lab, LBLUE if n < 4 else LPURPLE,
                  BLUE if n < 4 else PURPLE, 11)
    s.text(280, 260, 'terms: (N+1)(N+2)/2 = 1, 3, 6, 10, 15 ...  (136 for N = 15)', 10.5,
           'middle', GREY)
    s.save('taylor_pyramid')


def fig_quadrature():
    s = Svg(640, 220)
    def square(ox, oy, n, name, pts, w):
        s.rect(ox, oy, 150, 150, '#f6f9fd', BLUE, 1.5, rx=0)
        for (x, y), wt in pts:
            s.circle(ox + 75 + x * 75, oy + 75 - y * 75, 4.5, RED)
        s.text(ox + 75, oy + 172, name, 11, 'middle', BLUE, 'bold')
        s.text(ox + 75, oy + 188, w, 9.5, 'middle', GREY)
    a = 1 / math.sqrt(3)
    square(30, 20, 2, '2 x 2 (Q4, B2 section)',
           [((-a, -a), 1), ((a, -a), 1), ((a, a), 1), ((-a, a), 1)],
           'a = 0.57735, w = 1')
    b = math.sqrt(3 / 5)
    pts = [((x, y), 0) for x in (-b, 0, b) for y in (-b, 0, b)]
    square(240, 20, 3, '3 x 3 (Q9)', pts,
           '0.7746; w = 5/9, 8/9, 5/9')
    c1, c2 = 0.8611363115940526, 0.3399810435848563
    pts = [((x, y), 0) for x in (-c1, -c2, c2, c1) for y in (-c1, -c2, c2, c1)]
    square(450, 20, 4, '4 x 4 (Q16)', pts, '0.8611, 0.3400')
    s.save('quadrature')


# ---------------------------------------------------------------------
# frames
# ---------------------------------------------------------------------
def axes3(s, ox, oy, size=70, labels=('X', 'Y', 'Z'), color='#333', sw=1.6):
    # screen projection: X right-down, Y right-up, Z up
    vx = (size * 0.85, size * 0.35)
    vy = (size * 0.95, -size * 0.30)
    vz = (0, -size)
    for v, lab in zip([vx, vy, vz], labels):
        s.line(ox, oy, ox + v[0], oy + v[1], color, sw, arrow=True)
        s.text(ox + v[0] * 1.12, oy + v[1] * 1.12 + 4, lab, 11, 'middle',
               color, 'bold')
    return vx, vy, vz


def fig_frames_beam():
    s = Svg(720, 330)
    # global axes
    axes3(s, 70, 280, 60, ('X', 'Y', 'Z'))
    s.text(70, 308, 'global frame', 10.5, 'middle', GREY)
    # beam along some direction and local frame
    p0 = (230, 230)
    p1 = (560, 130)
    s.line(p0[0], p0[1], p1[0], p1[1], BLUE, 5)
    node(s, p0[0], p0[1], '', 5, BLUE)
    node(s, p1[0], p1[1], '', 5, BLUE)
    s.text(p0[0] - 4, p0[1] + 20, 'node 1', 10, 'middle')
    s.text(p1[0] + 4, p1[1] + 20, 'node 2 / 4', 10, 'middle')
    # local axes at midpoint
    m = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
    ey = (p1[0] - p0[0], p1[1] - p0[1])
    n = math.hypot(*ey)
    ey = (ey[0] / n, ey[1] / n)
    s.line(m[0], m[1], m[0] + 85 * ey[0], m[1] + 85 * ey[1], RED, 2, arrow=True)
    s.text(m[0] + 100 * ey[0], m[1] + 100 * ey[1], 'y (axis)', 11, 'middle', RED, 'bold')
    s.line(m[0], m[1], m[0], m[1] - 85, GREEN, 2, arrow=True)
    s.text(m[0] + 22, m[1] - 80, 'z  (from the versor)', 11, 'start', GREEN, 'bold')
    s.line(m[0], m[1], m[0] + 60, m[1] + 36, PURPLE, 2, arrow=True)
    s.text(m[0] + 70, m[1] + 52, 'x = y × z', 11, 'start', PURPLE, 'bold')
    # versor
    s.line(110, 130, 110, 60, GREEN, 1.6, '5 3', True)
    s.text(110, 48, 'VERSOR v = (vx, vy, vz)', 10.5, 'middle', GREEN)
    s.text(380, 310, 'e_y = (x_end − x_1)/|…|,  e_z = (v − (v·e_y)e_y)/|…|,  e_x = e_y × e_z', 11.5, 'middle', '#222')
    s.save('frames_beam')


def fig_frames_plate():
    s = Svg(720, 330)
    axes3(s, 70, 285, 60, ('X', 'Y', 'Z'))
    pts = [(240, 250), (520, 250), (600, 170), (320, 170)]
    s.poly(pts, '#e7eef8', BLUE, 1.6)
    labels = ['1', '2 (corner 2)', '3', '4 (corner 3)']
    node(s, *pts[0], '1', dx=-14, dy=16)
    node(s, *pts[1], '', 4.5)
    node(s, *pts[3], '', 4.5)
    s.text(pts[1][0] + 4, pts[1][1] + 18, 'corner 2', 10)
    s.text(pts[3][0] - 8, pts[3][1] - 8, 'corner 3', 10, 'end')
    c = (440, 215)
    s.line(c[0], c[1], c[0], c[1] - 95, GREEN, 2, arrow=True)
    s.text(c[0] + 8, c[1] - 90, 'z = n = (P2 − P1) × (P3 − P1)', 11, 'start', GREEN, 'bold')
    s.line(c[0], c[1], c[0] + 95, c[1] - 10, RED, 2, arrow=True)
    s.text(c[0] + 100, c[1] - 6, 'x  (versor projected\non the plane)', 10.5, 'start', RED, 'bold')
    s.line(c[0], c[1], c[0] + 45, c[1] - 50, PURPLE, 2, arrow=True)
    s.text(c[0] + 52, c[1] - 52, 'y = z × x', 11, 'start', PURPLE, 'bold')
    s.text(380, 318, 'Thickness (section expansion) runs along the local z axis', 11.5, 'middle', GREY)
    s.save('frames_plate')


def fig_material_frame():
    s = Svg(720, 300)
    # local frame x-y rotated by angle about z
    ox, oy = 180, 170
    for ang, col, lab in [(0, '#555', ''), ]:
        pass
    s.line(ox - 110, oy, ox + 130, oy, '#555', 1.6, arrow=True)
    s.line(ox, oy + 100, ox, oy - 120, '#555', 1.6, arrow=True)
    s.text(ox + 142, oy + 4, 'x (element)', 11, 'start', '#555')
    s.text(ox + 8, oy - 126, 'y (element)', 11, 'start', '#555')
    a = math.radians(30)
    L = 120
    s.line(ox, oy, ox + L * math.cos(a), oy - L * math.sin(a), RED, 2.2, arrow=True)
    s.text(ox + L * math.cos(a) + 8, oy - L * math.sin(a), 'T  (material)', 11, 'start', RED, 'bold')
    s.line(ox, oy, ox - L * math.sin(a), oy - L * math.cos(a), GREEN, 2.2, arrow=True)
    s.text(ox - L * math.sin(a) - 6, oy - L * math.cos(a) - 6, 'L  (fibre)', 11, 'end', GREEN, 'bold')
    s.path('M %.1f %.1f A 60 60 0 0 0 %.1f %.1f' % (ox + 60, oy, ox + 60 * math.cos(a), oy - 60 * math.sin(a)), 'none', '#555', 1.2)
    s.text(ox + 78, oy - 14, 'θz', 12, 'start', '#222')
    s.text(480, 70, 'Material axes (T, L, Z)', 12.5, 'start', BLUE, 'bold')
    for i, t in enumerate(['LAMINATION.dat gives two angles per lamination:',
                           'ANGLE_Y: rotation about the element y axis',
                           'ANGLE_Z: rotation about the element z axis',
                           'A = Rz(θz) · Ry(θy) maps element-frame components',
                           'to material-frame components.',
                           'With θy = 0 and θz = 0 the material axes',
                           'T, L, Z coincide with the element x, y, z.']):
        s.text(480, 100 + 20 * i, t, 11, 'start', '#222')
    s.save('material_frame')


def fig_expansion_mesh_layers():
    s = Svg(720, 260)
    # laminated section made of 3 Q9 elements stacked in z
    ox, oy, w, h = 90, 30, 150, 60
    cols = [LBLUE, LGREEN, LBLUE]
    labs = ['lamination 1 (material 1)', 'lamination 2 (material 2)', 'lamination 1 (material 1)']
    for i in range(3):
        y = oy + (2 - i) * h
        s.rect(ox, y, w, h, cols[i], BLUE, 1.4, rx=0)
        for a in range(3):
            for b in range(3):
                s.circle(ox + a * w / 2, y + b * h / 2, 3.2, BLUE)
        s.text(ox + w + 14, y + h / 2 + 4, 'EXP_CONN element %d → %s' % (i + 1, labs[i]), 11, 'start')
    s.line(ox - 30, oy + 3 * h + 5, ox - 30, oy - 10, '#333', 1.3, arrow=True)
    s.text(ox - 40, oy + 20, 'z', 11, 'end', '#333', 'bold')
    s.line(ox - 10, oy + 3 * h + 22, ox + w + 10, oy + 3 * h + 22, '#333', 1.3, arrow=True)
    s.text(ox + w + 16, oy + 3 * h + 26, 'x', 11, 'start', '#333', 'bold')
    s.text(ox + w / 2, oy + 3 * h + 46, 'section expansion mesh (EXP_MESH_01 / EXP_CONN_01)', 10.5, 'middle', GREY)
    s.save('expansion_layers')


# ---------------------------------------------------------------------
# MITC, DOF layout, CSR
# ---------------------------------------------------------------------
def fig_mitc_q9():
    s = Svg(720, 250)
    a = 1 / math.sqrt(3)
    b = math.sqrt(3 / 5)

    def panel(ox, title, pts):
        s.rect(ox, 40, 150, 150, '#f6f9fd', BLUE, 1.4, rx=0)
        s.line(ox + 75, 40, ox + 75, 190, '#bbb', 0.8, '3 3')
        s.line(ox, 115, ox + 150, 115, '#bbb', 0.8, '3 3')
        for (x, y) in pts:
            s.circle(ox + 75 + x * 75, 115 - y * 75, 4.5, RED)
        s.text(ox + 75, 213, title, 10.5, 'middle', '#222')
    panel(30, 'rows 1, 4: {±a} × {−b, 0, b}', [(x, y) for x in (-a, a) for y in (-b, 0, b)])
    panel(210, 'rows 2, 5: {−b, 0, b} × {±a}', [(x, y) for x in (-b, 0, b) for y in (-a, a)])
    panel(390, 'row 6: {±a} × {±a}', [(x, y) for x in (-a, a) for y in (-a, a)])
    s.text(600, 100, 'a = 1/√3\nb = √(3/5)', 11, 'start', GREY)
    s.text(375, 20, 'Q9 tying points for the tied strain rows (xi horizontal, eta vertical)', 11.5, 'middle', BLUE, 'bold')
    s.save('mitc_q9')


def fig_dof_layout():
    s = Svg(720, 250)
    s.text(360, 22, 'Field-major numbering: all U terms, then all V terms, then all W terms', 12, 'middle', BLUE, 'bold')
    fx = 40
    widths = [190, 190, 190]
    names = ['field U (1)', 'field V (2)', 'field W (3)']
    cols = [LBLUE, LGREEN, LRED]
    for k in range(3):
        x = fx + k * 215
        s.rect(x, 50, widths[k], 36, cols[k], BLUE, 1.2, rx=2)
        s.text(x + widths[k] / 2, 40, names[k], 11, 'middle', BLUE, 'bold')
        for n in range(3):
            xn = x + n * widths[k] / 3
            s.line(xn, 50, xn, 86, BLUE, 1)
            s.text(xn + widths[k] / 6, 72, 'node %d' % (n + 1), 10, 'middle', '#222')
        s.text(x + widths[k] / 2, 104, 'node-major, then term', 10, 'middle', GREY)
    s.text(360, 150, 'global DOF = FIRST(node, field) + term − 1', 12, 'middle', '#111', 'bold')
    s.text(360, 175, 'TERM_COUNT(node, field): TE order N → (N+1)(N+2)/2 (beam), N+1 (plate), 1 (solid)', 10.5, 'middle', GREY)
    s.text(360, 193, 'LE → number of nodes of the expansion mesh', 10.5, 'middle', GREY)
    s.text(360, 225, 'Example: 3 nodes, TE1 beam (3 terms): 9 DOF per field, 27 DOF in total', 11, 'middle', '#222')
    s.save('dof_layout')


def fig_csr():
    s = Svg(720, 250)
    M = [[4, 1, 0, 0, 2], [1, 5, 2, 0, 0], [0, 2, 6, 3, 0], [0, 0, 3, 7, 1], [2, 0, 0, 1, 8]]
    ox, oy, c = 40, 40, 34
    for i in range(5):
        for j in range(5):
            v = M[i][j]
            s.rect(ox + j * c, oy + i * c, c, c, LBLUE if v else '#fff', '#9db3d1', 1, rx=0)
            s.text(ox + j * c + c / 2, oy + i * c + c / 2 + 4, str(v) if v else '', 12, 'middle', '#12355f')
    s.text(ox + 2.5 * c, oy - 12, 'full symmetric matrix (5 × 5)', 11, 'middle', BLUE, 'bold')
    vals = []
    cols = []
    ptr = [1]
    for i in range(5):
        for j in range(5):
            if M[i][j]:
                vals.append(M[i][j])
                cols.append(j + 1)
        ptr.append(len(vals) + 1)

    def row(y, name, data, color):
        s.text(300, y + 16, name, 10.5, 'end', BLUE, 'bold')
        for k, v in enumerate(data):
            s.rect(306 + k * 25, y, 25, 24, color, '#9db3d1', 1, rx=0)
            s.text(306 + k * 25 + 12.5, y + 16, str(v), 10.5, 'middle')
    row(60, 'ROW_POINTER (N+1)', ptr, LGREEN)
    row(110, 'COLUMN_INDEX (nnz)', cols, LYEL)
    row(160, 'STIFFNESS (nnz)', vals, LRED)
    s.text(40, 225, 'rows stored contiguously, columns ascending, diagonal present, 1-based, 64-bit integers;\nK and M share ROW_POINTER and COLUMN_INDEX', 10, 'start', GREY)
    s.save('csr')


# ---------------------------------------------------------------------
# flowcharts
# ---------------------------------------------------------------------
def fig_flow_main():
    s = Svg(720, 520)
    X = 360
    steps = [('MUL2_V3.exe  (mul2_main)', LGREY, GREY),
             ('INITIALIZE_RUNTIME\nargument / PATH_input.dat / "INPUT"', LBLUE, BLUE),
             ('RUN_MUL2 (mul2_driver)', LBLUE, BLUE),
             ('PREPARE_OUTPUT_DIRECTORIES\nSTATIC  DYNAMIC  WORK  REPORT', LBLUE, BLUE),
             ('READ_MODEL  +  READ_POSTPROCESSING_FILE\nanalysis 101 or 103 only', LGREEN, GREEN),
             ('BUILD_MODEL_CACHE\nDOF, frames, rules, Gauss layout, geometry, materials', LYEL, YEL),
             ('RUN_STATIC_ANALYSIS (101)   |   RUN_MODAL_ANALYSIS (103)', LRED, RED),
             ('WRITE_STATIC_OUTPUT   |   WRITE_MODAL_OUTPUT\nWRITE_WARNING_FILE', LPURPLE, PURPLE),
             ('FINALIZE_RUNTIME  (times)   →  exit code 0 / 1', LGREY, GREY)]
    y = 12
    prev = None
    for i, (lab, f, st) in enumerate(steps):
        h = 46 if '\n' in lab else 34
        s.box(X - 190, y, 380, h, lab, f, st, 11)
        if prev is not None:
            s.arrow(X, prev, X, y)
        prev = y + h
        y += h + 24
    s.text(X + 205, 190, 'errors anywhere →\nSTATUS%CODE = 2\nmessage on stderr', 9.5, 'start', RED)
    s.save('flow_main')


def fig_flow_cache():
    s = Svg(720, 470)
    cols = [(40, 'inputs'), (270, 'caches'), (500, 'used by')]
    s.text(130, 18, 'MODEL', 12, 'middle', BLUE, 'bold')
    s.text(360, 18, 'BUILD_MODEL_CACHE', 12, 'middle', BLUE, 'bold')
    s.text(600, 18, 'consumers', 12, 'middle', BLUE, 'bold')
    rows = [('nodes, elements,\nkinematics, expansions', 'BUILD_DOF_LAYOUT\nTERM_COUNT, FIRST', 'assembly, BC, post'),
            ('nodes, elements,\nversors', 'BUILD_ELEMENT_FRAMES\nORIGIN, GLOBAL_TO_LOCAL', 'kernels, post'),
            ('elements, expansions,\nTE orders', 'BUILD_EXPANSION_POINT_ORDERS\nBUILD_REFERENCE_RULE_DATABASE', 'layout, geometry'),
            ('rules, expansion mesh', 'BUILD_GAUSS_LAYOUT\nelement/sub-element/point', 'kernels'),
            ('nodes, frames, rules', 'BUILD_STRUCTURAL_GEOMETRY_CACHE\nJ, det, grad N (local)', 'kernels'),
            ('expansion mesh, rules', 'BUILD_EXPANSION_GEOMETRY_CACHE\nJ, det, grad F (local)', 'kernels'),
            ('layout + both caches', 'BUILD_COMBINED_GAUSS_GEOMETRY\nweights, global coordinates', 'kernels'),
            ('materials, laminations', 'BUILD_GAUSS_MATERIAL_CACHE\nrotated C, density, map', 'kernels, post')]
    y = 34
    for a, b, c in rows:
        s.box(20, y, 190, 40, a, LGREEN, GREEN, 10)
        s.box(250, y, 220, 40, b, LYEL, YEL, 10)
        s.box(510, y, 190, 40, c, LGREY, GREY, 10)
        s.arrow(210, y + 20, 250, y + 20)
        s.arrow(470, y + 20, 510, y + 20)
        y += 52
    s.text(360, 458, 'every step returns a STATUS; the first error stops the pipeline', 10.5, 'middle', GREY)
    s.save('flow_cache')


def fig_flow_assembly():
    s = Svg(720, 560)
    X = 250
    s.box(X - 130, 10, 260, 36, 'ASSEMBLE_MODEL_SYSTEM(MODEL, CACHE)', LBLUE, BLUE, 11)
    s.box(X - 130, 66, 260, 46, 'for each element: BUILD_ELEMENT_DOF_LIST\n+ MARK_LAGRANGE_DOFS → DOF_LIST_TYPE', LGREEN, GREEN, 10.5)
    s.box(X - 130, 132, 260, 46, 'BUILD_COUPLING_TABLES (per expansion mesh)\nBUILD_PATTERN_FROM_DOF_LISTS → CSR', LGREEN, GREEN, 10.5)
    s.box(X - 130, 198, 260, 46, 'CHUNK_SIZE: multiple of the thread count,\nmemory budget CHUNK_BYTES = 1e9', LYEL, YEL, 10.5)
    for y0, y1 in [(46, 66), (112, 132), (178, 198)]:
        s.arrow(X, y0, X, y1)
    s.diamond(X, 296, 230, 64, 'more elements?')
    s.arrow(X, 244, X, 264)
    s.box(X - 135, 346, 270, 52, '!$OMP PARALLEL DO (dynamic)\nEVALUATE_ELEMENT → K_e, M_e of the chunk', LRED, RED, 10.5)
    s.arrow(X, 328, X, 346, 'yes', lx=X + 18, ly=340)
    s.box(X - 135, 418, 270, 52, 'serial loop in element order:\nSCATTER_ELEMENT into CSR (deterministic)', LRED, RED, 10.5)
    s.arrow(X, 398, X, 418)
    s.elbow([(X + 135, 444), (X + 190, 444), (X + 190, 296), (X + 115, 296)])
    s.arrow(X, 470, X, 500)
    s.box(X - 130, 500, 260, 38, 'K (and M) in SPARSE_SYSTEM_TYPE', LBLUE, BLUE, 11)
    s.text(X + 205, 316, 'no', 10.5, 'start', GREY)
    s.text(500, 120, 'Why a serial scatter?', 11.5, 'start', BLUE, 'bold')
    for i, t in enumerate(['Floating-point sums are not',
                           'associative. Scattering the chunk',
                           'in element order fixes the order',
                           'of every addition: the result is',
                           'bit-identical for any thread',
                           'count (tested with 1 and 4).']):
        s.text(500, 140 + 17 * i, t, 10.5, 'start', '#222')
    s.save('flow_assembly')


def fig_flow_kernel():
    s = Svg(720, 560)
    X = 230
    s.box(X - 150, 8, 300, 34, 'BUILD_LINEAR_ELEMENT_MATRICES', LBLUE, BLUE, 11)
    s.box(X - 150, 62, 300, 34, 'validate, DOF list, allocate K_e (and M_e)', LGREEN, GREEN, 10.5)
    s.diamond(X, 150, 300, 60, 'FORCE_GENERAL?  (MUL2_GENERAL_KERNEL=1)')
    s.arrow(X, 42, X, 62); s.arrow(X, 96, X, 120)
    s.box(X - 160, 202, 320, 70, 'BUILD_SEPARABLE_MATRICES\nSigma, Sm (structural)   Eps, Em (expansion)\nGamma = W^T C W    Lambda = Gamma · Sm\nK_block = sum Lambda · Em', LGREEN, GREEN, 10)
    s.arrow(X, 180, X, 202, 'no', lx=X + 14, ly=196)
    s.diamond(X, 326, 230, 52, 'APPLICABLE?')
    s.arrow(X, 272, X, 300)
    s.box(X - 160, 370, 320, 80, 'point-by-point kernel (reference)\nbatches of ≤ 128 Gauss points:\nB_P, C B_P → ACCUMULATE_UPPER_PRODUCT\nmass: ADD_MASS per displacement component', LRED, RED, 10)
    s.arrow(X, 352, X, 370, 'no', lx=X + 14, ly=366)
    s.box(X - 130, 480, 260, 36, 'MIRROR_UPPER_TRIANGLE  →  K_e, M_e', LBLUE, BLUE, 11)
    s.arrow(X, 450, X, 480)
    s.elbow([(X - 115, 326), (24, 326), (24, 498), (X - 130, 498)])
    s.text(40, 318, 'yes', 10, 'start', GREY)
    s.text(500, 130, 'Applicable when', 11.5, 'start', BLUE, 'bold')
    for i, tx in enumerate(['• C constant in each sub-element',
                            '• layout: sub-element → p → q',
                            '• DOF terms numbered 1..T',
                            '(always true for the supported',
                            'inputs)',
                            '',
                            'Both kernels give the same',
                            'matrices to round-off (1e-15,',
                            'checked on dumped K and M).']):
        s.text(500, 152 + 17 * i, tx, 10.5, 'start', '#222')
    s.save('flow_kernel')


def fig_flow_static():
    s = Svg(720, 560)
    X = 260
    items = [('ASSEMBLE_MODEL_SYSTEM(WITH_MASS = dump requested)', LBLUE, BLUE),
             ('BUILD_MECHANICAL_BOUNDARY_DATA\nconstraints (D-PLANE) + force vector (F-POINT)', LGREEN, GREEN),
             ('APPLY_STATIC_CONSTRAINTS\nF = F − K u_c ; zero rows/cols ; unit diagonal ; F_c = u_c', LYEL, YEL),
             ('SOLVE_SYMMETRIC_POSITIVE_DEFINITE\nPARDISO_SET_SYSTEM (copy upper triangle)', LRED, RED),
             ('free the full K (unless K_MAT/M_MAT requested)', LGREY, GREY),
             ('PARDISO_FACTOR_LOADED  (mtype 2, Cholesky)', LRED, RED),
             ('PARDISO_SOLVE (phase 33)  →  u', LRED, RED),
             ('check NaN/Inf, report max |u|', LBLUE, BLUE)]
    y = 10
    prev = None
    for lab, f, st in items:
        h = 46 if '\n' in lab else 34
        s.box(X - 200, y, 400, h, lab, f, st, 10.5)
        if prev is not None:
            s.arrow(X, prev, X, y)
        prev = y + h
        y += h + 22
    s.box(X + 230, 300, 230, 60, 'error −4 (zero pivot)\n→ retry with mtype −2\n(symmetric indefinite) + warning', LYEL, YEL, 10)
    s.arrow(X + 200, 342, X + 230, 330)
    s.save('flow_static')


def fig_flow_modal():
    s = Svg(720, 640)
    X = 250
    items = [('ASSEMBLE_MODEL_SYSTEM (K and M)', LBLUE, BLUE),
             ('BUILD_MECHANICAL_BOUNDARY_DATA\n(loads ignored, warning)', LGREEN, GREEN),
             ('BUILD_REDUCED_PATTERN / REDUCE_VALUES\nK_ff, M_ff on the free DOFs', LYEL, YEL),
             ('free full K, M and the reduction map', LGREY, GREY),
             ('SOLVE_MODAL_PROBLEM(K_ff, M_ff, nev, sigma = 0)', LRED, RED)]
    y = 10
    prev = None
    for lab, f, st in items:
        h = 46 if '\n' in lab else 34
        s.box(X - 190, y, 380, h, lab, f, st, 10.5)
        if prev is not None:
            s.arrow(X, prev, X, y)
        prev = y + h
        y += h + 22
    s.diamond(X, y + 24, 300, 48, 'N ≤ 400 or nev ≥ N−2 ?')
    s.arrow(X, prev, X, y)
    yy = y + 48
    s.box(X - 330 + 80, yy + 24, 220, 56, 'dense: dsygv\n(LAPACK, all eigenpairs)', LGREY, GREY, 10.5)
    s.box(X + 20, yy + 24, 220, 120, 'ARPACK mode 3 (dsaupd)\nPARDISO factor of K − σM\nrepeat: IDO = −1/1 → x ← (K−σM)⁻¹ M x\nIDO = 2 → y ← M x\ndseupd → λ, φ', LRED, RED, 10)
    s.arrow(X - 100, y + 48 - 6, X - 90, yy + 24, 'yes', lx=X - 130, ly=yy + 8)
    s.arrow(X + 100, y + 48 - 6, X + 110, yy + 24, 'no', lx=X + 130, ly=yy + 8)
    z = yy + 170
    s.box(X - 190, z, 380, 46, 'SORT_MODES ascending, M-normalise,\nCOMPUTE_RESIDUALS ‖Kφ − λMφ‖, f = √λ/2π', LYEL, YEL, 10.5)
    s.arrow(X - 100, yy + 24 + 56, X - 60, z)
    s.arrow(X + 130, yy + 24 + 120, X + 80, z)
    s.box(X - 190, z + 68, 380, 34, 'EXPAND_VECTOR → modes on the full numbering', LBLUE, BLUE, 10.5)
    s.arrow(X, z + 46, X, z + 68)
    s.save('flow_modal')


def fig_flow_post():
    s = Svg(720, 470)
    X = 220
    s.box(X - 170, 10, 340, 34, 'WRITE_STATIC_OUTPUT / WRITE_MODAL_OUTPUT', LBLUE, BLUE, 11)
    s.box(X - 170, 70, 340, 46, 'PNT: LOCATE_POINT(target)\nbounding box prefilter → NEWTON_LOCATE', LGREEN, GREEN, 10.5)
    s.box(X - 170, 140, 340, 46, 'PLACE_SETUP / PLACE_EVALUATE\nshapes and local gradients at (ξ_s, ξ_e)', LGREEN, GREEN, 10.5)
    s.box(X - 170, 210, 340, 46, 'STATE_FROM_PLACE\nu = Σ N F u ;  ε = B u (MITC rows) ;  σ = C ε', LYEL, YEL, 10.5)
    s.box(X - 170, 280, 340, 46, 'WRITE_POINT_ROW → POST_POINT.dat\n(or a NaN row + warning if outside)', LRED, RED, 10.5)
    for a, b in [(44, 70), (116, 140), (186, 210), (256, 280)]:
        s.arrow(X, a, X, b)
    s.box(X - 170, 352, 340, 46, 'PARA / GMSH: BUILD_POST_GRID (cells)\nEVALUATE_GRID_STATES (cells in parallel)', LPURPLE, PURPLE, 10.5)
    s.box(X - 170, 420, 340, 34, 'WRITE_STATIC_VTK / _GMSH, WRITE_MODAL_*', LRED, RED, 10.5)
    s.arrow(X, 398, X, 420)
    s.arrow(X, 326, X, 352, None)
    s.text(500, 100, 'Frames', 11.5, 'start', BLUE, 'bold')
    for i, t in enumerate(['LOC: element frame components', 'GLB: global components', 'strain/stress order:', 'xx, yy, zz, xz, yz, xy', 'engineering shear strains']):
        s.text(500, 122 + 17 * i, t, 10.5, 'start')
    s.save('flow_post')


def fig_layers():
    deps = json.load(open(os.path.join(BUILD, 'deps.json')))
    order = ['BASE', 'MODEL', 'IO', 'QUADRATURE', 'FEM', 'GEOMETRY', 'CUF',
             'KINEMATICS', 'MATERIALS', 'GAUSS', 'ELEMENTS', 'ASSEMBLY',
             'BOUNDARY', 'SOLVERS', 'ANALYSES', 'POST', 'APP']
    pos = {'APP': (0, 0), 'ANALYSES': (0, 1), 'POST': (1, 1),
           'SOLVERS': (2, 1), 'BOUNDARY': (3, 1), 'ASSEMBLY': (2, 2),
           'ELEMENTS': (1, 2), 'GAUSS': (0, 2), 'IO': (3, 2),
           'CUF': (1, 3), 'KINEMATICS': (0, 3), 'MATERIALS': (2, 3),
           'GEOMETRY': (3, 3), 'FEM': (0, 4), 'QUADRATURE': (1, 4),
           'MODEL': (2, 4), 'BASE': (3, 4)}
    W, H = 150, 40
    s = Svg(760, 470)
    cx = lambda c: 30 + c * 180
    cy = lambda r: 20 + r * 90
    for a, bs in deps.items():
        if a not in pos:
            continue
        for b in bs:
            if b not in pos:
                continue
            (ca, ra), (cb, rb) = pos[a], pos[b]
            x1, y1 = cx(ca) + W / 2, cy(ra) + H
            x2, y2 = cx(cb) + W / 2, cy(rb)
            if ra == rb:
                x1 = cx(ca) + (W if cb > ca else 0)
                y1 = cy(ra) + H / 2
                x2 = cx(cb) + (0 if cb > ca else W)
                y2 = y1
            elif ra > rb:
                y1, y2 = cy(ra), cy(rb) + H
            s.line(x1, y1, x2, y2, '#c3cad6', 0.9, arrow=False)
    for k, (c, r) in pos.items():
        fill = LBLUE
        if k in ('APP', 'ANALYSES'):
            fill = LRED
        elif k in ('BASE', 'MODEL'):
            fill = LGREEN
        elif k in ('IO', 'POST'):
            fill = LPURPLE
        elif k in ('SOLVERS', 'ASSEMBLY', 'BOUNDARY'):
            fill = LYEL
        s.box(cx(c), cy(r), W, H, k, fill, BLUE, 11, 'bold')
    s.text(380, 458, 'edges: a layer uses modules of the layers it points to (drawn from the USE statements; layers lower in the picture know nothing about upper ones)', 9.5, 'middle', GREY)
    s.save('layers')


def fig_gauss_layout():
    s = Svg(720, 250)
    s.text(360, 20, 'Contiguous Gauss points of one element (GAUSS_LAYOUT_TYPE)', 12, 'middle', BLUE, 'bold')
    x = 30
    for e in range(2):
        s.text(x + 150, 48, 'sub-element e = %d (lamination %d)' % (e + 1, e + 1), 10.5, 'middle', GREEN, 'bold')
        for p in range(2):
            px = x + p * 170
            s.rect(px, 58, 160, 40, LYEL, YEL, 1.2, rx=2)
            s.text(px + 80, 52 + 0, '', 9)
            s.text(px + 80, 76, 'structural point p = %d' % (p + 1), 10, 'middle', '#4a3a05')
            for q in range(4):
                s.rect(px + 6 + q * 38, 82, 34, 12, LRED, RED, 0.8, rx=1)
            s.text(px + 80, 112, 'expansion points q = 1 … Q_e', 9.5, 'middle', GREY)
        x += 350
    s.text(360, 150, 'point(e, p, q) = FIRST + Σ_{e\' < e} P·Q_e\' + (p − 1)·Q_e + (q − 1)', 12, 'middle', '#111', 'bold')
    for i, t in enumerate(['STRUCTURAL_RULE_INDEX / STRUCTURAL_POINT_INDEX → reference rule and point p',
                           'EXPANSION_ELEMENT_INDEX / EXPANSION_RULE_INDEX / EXPANSION_POINT_INDEX → sub-element e and point q',
                           'REFERENCE_WEIGHT = w_p · w_q ;  INTEGRATION_WEIGHT also contains det J_p · det J_q']):
        s.text(360, 180 + 18 * i, t, 10.5, 'middle', '#222')
    s.save('gauss_layout')


def fig_bc_elimination():
    s = Svg(720, 250)
    s.text(360, 20, 'Exact symmetric elimination of constrained DOFs (analysis 101)', 12, 'middle', BLUE, 'bold')
    # before
    s.text(150, 50, 'before', 11, 'middle', GREY)
    for i in range(4):
        for j in range(4):
            c = LRED if (i == 2 or j == 2) else LBLUE
            s.rect(60 + j * 32, 60 + i * 32, 32, 32, c, '#9db3d1', 1, rx=0)
            s.text(60 + j * 32 + 16, 60 + i * 32 + 21, 'k' if True else '', 11, 'middle', '#12355f')
    s.text(60 + 2.5 * 32, 205, 'DOF 3 prescribed = u_c', 10.5, 'middle', RED)
    s.arrow(215, 125, 285, 125)
    s.text(250, 112, 'F ← F − K[:,c] u_c', 10, 'middle', GREY)
    s.text(430, 50, 'after', 11, 'middle', GREY)
    for i in range(4):
        for j in range(4):
            if i == 2 and j == 2:
                s.rect(340 + j * 32, 60 + i * 32, 32, 32, LGREEN, GREEN, 1.4, rx=0)
                s.text(340 + j * 32 + 16, 60 + i * 32 + 21, '1', 11, 'middle', '#12355f', 'bold')
            elif i == 2 or j == 2:
                s.rect(340 + j * 32, 60 + i * 32, 32, 32, '#fff', '#9db3d1', 1, rx=0)
                s.text(340 + j * 32 + 16, 60 + i * 32 + 21, '0', 11, 'middle', '#999')
            else:
                s.rect(340 + j * 32, 60 + i * 32, 32, 32, LBLUE, '#9db3d1', 1, rx=0)
                s.text(340 + j * 32 + 16, 60 + i * 32 + 21, 'k', 11, 'middle', '#12355f')
    s.text(340 + 2.5 * 32, 205, 'row/column zeroed, diagonal 1, F_c = u_c', 10.5, 'middle', GREEN)
    s.text(600, 100, 'The matrix stays symmetric\nand positive definite;\nthe solution has u_c exactly.\nNo penalty parameter.', 10.5, 'start', '#222')
    s.save('bc_elimination')


def fig_separable_math():
    s = Svg(720, 360)
    s.text(360, 22, 'Separable kernel: cost adds instead of multiplying', 12.5, 'middle', BLUE, 'bold')
    s.box(30, 50, 300, 120, 'POINT-BY-POINT\nfor each of P·Q combined points\n  for each DOF pair (n² / 2)\n    B_i^T C B_j\ncost ≈ P · Q · n²', LRED, RED, 11)
    s.box(390, 50, 300, 120, 'SEPARABLE\nstructural: Sm(i,j) = Σ_p w σ σ   (P·N²)\nexpansion:  Em(t,s) = Σ_q w ε ε   (Q·T²)\ncombine:  K = Σ Λ · Em           (n²·#e·9)\ncost ≈ P·N² + Q·T² + n²', LGREEN, GREEN, 11)
    s.text(360, 215, 'Example: beam B4 (N = 4), Taylor order 15 (T = 136, n = 544·3 = 1632), P = 4, Q = 256 per sub-element', 10.5, 'middle', '#222')
    s.text(360, 238, 'point-by-point ≈ 4 · 256 · 1632² / 2 ≈ 1.4·10⁹ nucleus evaluations per element', 10.5, 'middle', RED)
    s.text(360, 258, 'separable ≈ 9·(4·16 + 256·136² + 1632²/2) ≈ 5·10⁷ products per element', 10.5, 'middle', GREEN)
    s.text(360, 300, 'Measured (100 776 DOF, Taylor 15): assembly 526 s → 12 s', 11.5, 'middle', '#111', 'bold')
    s.save('separable_cost')


def fig_gui_map():
    s = Svg(720, 360)
    s.text(360, 20, 'Which input file controls what', 12.5, 'middle', BLUE, 'bold')
    boxes = [
        (20, 40, 'ANALYSIS.dat', 'solution 101/103,\nnumber of modes,\nshear correction'),
        (200, 40, 'NODES.dat', 'structural nodes\n(x, y, z, model)'),
        (380, 40, 'CONNECTIVITY.dat', 'elements: type, nodes,\nversor id, section id'),
        (560, 40, 'VERSORS.dat', 'reference vectors\nfor element frames'),
        (20, 170, 'EXP_MESH_nn.dat', 'section/thickness nodes\n(local x, y=0, z)'),
        (200, 170, 'EXP_CONN_nn.dat', 'sub-elements of the\nsection + lamination id'),
        (380, 170, 'LAMINATION.dat', 'material id + angles\nof each lamination'),
        (560, 170, 'MATERIAL.dat', 'ISO-M, ORT-M, MAT-C'),
        (110, 290, 'BC.dat', 'D-PLANE constraints,\nF-POINT loads'),
        (320, 290, 'POSTPROCESSING.dat', 'PNT points, PARA/GMSH\ngrids, matrix dumps'),
        (530, 290, 'KINEMATICS.dat (optional)', 'field-dependent\nexpansions'),
    ]
    for x, y, t, d in boxes:
        s.box(x, y, 160, 28, t, LBLUE, BLUE, 10.5, 'bold')
        s.text(x + 80, y + 46, d, 9.5, 'middle', GREY)
    s.save('file_map')


def fig_workflow_user():
    s = Svg(720, 140)
    steps = ['1 geometry\nNODES, CONNECTIVITY', '2 section\nEXP_MESH, EXP_CONN', '3 materials\nMATERIAL, LAMINATION',
             '4 frames\nVERSORS', '5 loads/BC\nBC.dat', '6 run\nMUL2_V3.exe', '7 results\nSTATIC / DYNAMIC']
    for i, t in enumerate(steps):
        x = 10 + i * 102
        s.box(x, 40, 92, 56, t, LBLUE if i < 5 else LGREEN, BLUE if i < 5 else GREEN, 9.5)
        if i:
            s.arrow(x - 10, 68, x, 68)
    s.text(360, 20, 'Typical workflow', 12, 'middle', BLUE, 'bold')
    s.save('workflow')


def fig_pattern_build():
    s = Svg(720, 300)
    s.text(360, 20, 'CSR pattern from DOF lists (two passes, no dense matrix)', 12, 'middle', BLUE, 'bold')
    s.box(30, 40, 200, 60, 'DOF → elements table\nFIRST(dof), MEMBER, MEMBER_LOCAL', LGREEN, GREEN, 10)
    s.box(260, 40, 200, 60, 'pass 1: for each row, mark unique\ncolumns (MARK array) → counts', LYEL, YEL, 10)
    s.box(490, 40, 200, 60, 'prefix sum → ROW_POINTER\nallocate COLUMN_INDEX', LYEL, YEL, 10)
    s.arrow(230, 70, 260, 70); s.arrow(460, 70, 490, 70)
    s.box(260, 130, 200, 60, 'pass 2: store the columns,\nSORT_SEGMENT each row', LRED, RED, 10)
    s.arrow(590, 100, 460, 160)
    s.diamond(360, 235, 280, 50, 'pair (I,J) of an element coupled?\nARE_COUPLED(table, term_I, term_J)')
    s.text(600, 150, 'Lagrange expansion: terms that do not\nshare a sub-element give exact zeros\nand are left out (6× fewer entries).', 10, 'start', '#222')
    s.arrow(360, 190, 360, 210)
    s.save('pattern_build')


def make_all():
    fig_elements_1d()
    fig_elements_2d()
    fig_elements_3d()
    fig_cuf_concept()
    fig_taylor_pyramid()
    fig_quadrature()
    fig_frames_beam()
    fig_frames_plate()
    fig_material_frame()
    fig_expansion_mesh_layers()
    fig_mitc_q9()
    fig_dof_layout()
    fig_csr()
    fig_flow_main()
    fig_flow_cache()
    fig_flow_assembly()
    fig_flow_kernel()
    fig_flow_static()
    fig_flow_modal()
    fig_flow_post()
    if os.path.exists(os.path.join(BUILD, 'deps.json')):
        fig_layers()
    fig_gauss_layout()
    fig_bc_elimination()
    fig_separable_math()
    fig_gui_map()
    fig_workflow_user()
    fig_pattern_build()
    import figs_hle
    figs_hle.make_all()


if __name__ == '__main__':
    make_all()
    print(len(os.listdir(OUT)), 'figures')
