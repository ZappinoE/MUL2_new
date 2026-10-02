"""Group: further plate benchmarks (Navier plate, Taylor thickness up to
order 20, hierarchical thickness equivalences, laminates)."""
import math

import vlib as V
from vcheck import Group
from g_beams import E, NU, RHO, G, D0
from g_plates import (P, L, B, H, NY, W_TIM, ps_reference)


# ---------------------------------------------------- Navier plate
def navier_center(q, a, D, nterms=201):
    """central deflection of a simply supported square Kirchhoff plate
    under uniform pressure (double Navier series)."""
    s = 0.0
    for m in range(1, nterms, 2):
        for n in range(1, nterms, 2):
            s += (-1) ** ((m + n) // 2 - 1) / (m * n * (m * m + n * n) ** 2)
    return 16.0 * q * a ** 4 / (math.pi ** 6 * D) * s


def navier_case(name, topo, n, a, h, q, thick, shear, sol=101):
    """quarter of a simply supported square plate (x, y in [0, a/2]),
    symmetric about the planes x = 0 and y = 0, pressure q on the top."""
    tm = V.line_mesh(thick[1], thick[2], h)
    pm = V.rect_mesh(topo, n, n, 0.0, a / 2, 0.0, a / 2)
    c = V.Case(name)
    lines = ['%d' % len(pm.nodes), '']
    for i in sorted(pm.nodes):
        u, v = pm.nodes[i]
        lines.append('%d  %s  %s  0.0D0  LE 1' % (i, V.fmt(u), V.fmt(v)))
    c.put('NODES.dat', '\n'.join(lines) + '\n')
    el = ['%d' % len(pm.elems), '']
    for k, (tp, ids, extra, lam) in enumerate(pm.elems):
        el.append('%s %d  %s  1  1' % (tp, k + 1, ' '.join(map(str, ids))))
    c.put('CONNECTIVITY.dat', '\n'.join(el) + '\n')
    c.put('VERSORS.dat', '1\n\nVERSOR 1  1 0 0\n')
    c.put('ANALYSIS.dat', V.analysis_text(sol, 4, plate=shear))
    c.put('MATERIAL.dat', V.material_text(E, NU, RHO))
    c.put('LAMINATION.dat', V.LAM_TEXT)
    c.put('EXP_MESH_01.dat', tm.mesh_text(False))
    c.put('EXP_CONN_01.dat', tm.conn_text())
    top = max(tm.nodes[j][1] for j in tm.nodes)
    recs = [V.dplane(1, 1, 0, 0, 0, 0.0, None, None),
            V.dplane(2, 0, 1, 0, 0, None, 0.0, None),
            V.dplane(3, 1, 0, 0, -a / 2, None, None, 0.0),
            V.dplane(4, 0, 1, 0, -a / 2, None, None, 0.0)]
    w = pm.consistent(lambda u, v: q)
    for i in sorted(w):
        u, v = pm.nodes[i]
        recs.append(V.fpoint(len(recs) + 1, u, v, top, 0.0, 0.0, w[i]))
    c.put('BC.dat', V.bc_text(recs))
    c.put('POSTPROCESSING.dat', V.post_text([(1e-6, 1e-6, 0.0)]))
    return c


def orth_text():
    return ('1 1\n\nORT-M 1  140.0D9 10.0D9 10.0D9  0.3 0.3 0.4  '
            '5.0D9 5.0D9 3.5D9  1600.0\n')


def cross_ply_flexural(angles, h, EL=140e9, ET=10e9, nuLT=0.3):
    """plane-strain (eps_x = 0, sigma_z = 0) flexural rigidity per unit
    width of a laminate with equal plies of angle 0 / 90."""
    n = len(angles)
    D = 0.0
    for k, ang in enumerate(angles):
        z0 = -h / 2 + h * k / n
        z1 = -h / 2 + h * (k + 1) / n
        if ang == 0:
            Ey = 1.0 / (1.0 / EL - (nuLT / EL) ** 2 / (1.0 / ET))
        else:
            Ey = 1.0 / (1.0 / ET - (nuLT / EL) ** 2 / (1.0 / EL))
        D += Ey * (z1 ** 3 - z0 ** 3) / 3.0
    return D


def group_plates2():
    g = Group('plates2', 'Further plate benchmarks',
              'Simply supported square plate (Navier series), Taylor '
              'thickness expansion up to order 20, equivalences of the '
              'hierarchical thickness expansion, laminated strips.')
    # ------------------------------------------------------- Navier
    a, h, q = 10.0, 0.1, 100.0
    Dp = E * h ** 3 / (12 * (1 - NU ** 2))
    wn = navier_center(q, a, Dp)
    meshes = {'Q4': 8, 'Q9': 4, 'Q16': 3, 'T3': 8, 'T6': 4}
    rows = []
    for topo, n in meshes.items():
        vals = {}
        for shear in ('NONE', 'MITC'):
            c = navier_case('nv_%s_%s' % (topo, shear), topo, n, a, h, q,
                            ('LE', 'B3', 1), shear)
            r = g.run(c)
            vals[shear] = r.u(0)[2] / wn if r.ok and r.points else \
                float('nan')
        rows.append([topo, '%dx%d' % (n, n), '%.4f' % vals['NONE'],
                     '%.4f' % vals['MITC']])
        tol = {'Q4': 0.03, 'Q9': 0.01, 'Q16': 0.01, 'T3': None,
               'T6': None}[topo]
        g.check('Navier plate %s %dx%d (MITC): centre deflection'
                % (topo, n, n), vals['MITC'] * wn, wn, tol,
                'Navier series (Kirchhoff), a/h = 100',
                note='triangles have no MITC tying table: shear locking '
                     'of the full integration' if topo[0] == 'T' else '')
    g.table('Simply supported square plate, a/h = 100, uniform pressure '
            '(quarter model): centre deflection / Navier value %.5e m'
            % wn, ['plate', 'mesh (quarter)', 'full integration', 'MITC'],
            rows,
            'Thickness expansion: one B3 element; the symmetry planes '
            'carry u_x = 0 or u_y = 0, the supports u_z = 0.')
    # ------------------------------------------- Taylor up to order 20
    ref = ps_reference()
    ns, ws, rows = [], [], []
    for n in range(1, 21):
        c = V.plate_case('plte_%d' % n, 'Q9', 8, ('TE', n),
                         load=('shear', P))
        r = g.run(c)
        if not (r.ok and r.points):
            g.flag('plate Q9 TE%d runs' % n, False, 'run failed')
            continue
        w = r.u(0)[2]
        ns.append(n)
        ws.append(w / ref['w'])
        rows.append([n, n + 1, r.ndof, '%.6e' % w,
                     '%+.3f' % (100 * (w / ref['w'] - 1)),
                     '%+.3f' % (100 * (w / W_TIM - 1))])
        if n >= 3:
            g.check('plate Q9 TE%d: tip deflection vs 3D solid' % n, w,
                    ref['w'], 0.005, '3D plane-strain solid H27')
    g.table('Plate Q9 (8 elements) with Taylor thickness expansion of '
            'order n', ['n', 'terms', 'DOF', 'tip w [m]',
                        'vs 3D solid [%]', 'vs Timoshenko [%]'], rows)
    g.plot('Plate with Taylor thickness expansion', 'Taylor order n',
           'w / w(3D solid)', {'Q9 TE n': (ns, ws)})
    # ---------------------------- hierarchical thickness equivalences
    for hb, (kind, ne, p) in (('HB p=1', ('B2', 1, 1)),
                              ('HB p=2', ('B3', 1, 2)),
                              ('HB p=3', ('B4', 1, 3))):
        rr = []
        for sol in (101, 103):
            ca = V.plate_case('hbe_a_%s_%d' % (kind, sol), 'Q9', 8,
                              ('LE', kind, 1), sol=sol, nmodes=4,
                              load=('shear_v', P))
            cb = V.plate_case('hbe_b_%s_%d' % (kind, sol), 'Q9', 8,
                              ('HB', 1, p), sol=sol, nmodes=4,
                              load=('shear_v', P))
            ra, rb = g.run(ca), g.run(cb)
            rr.append((ra.u(0)[2], rb.u(0)[2]) if sol == 101 else
                      (ra.freq[0], rb.freq[0]))
        g.check('%s == LE %s: tip deflection' % (hb, kind), rr[0][1],
                rr[0][0], 1e-9, 'equivalent function spaces')
        g.check('%s == LE %s: f1' % (hb, kind), rr[1][1], rr[1][0], 1e-9,
                'equivalent function spaces')
    # ----------------------------------------------------- laminates
    iso = V.plate_case('lam_iso', 'Q9', 8, ('LE', 'B3', 2),
                       load=('shear', P))
    ri = g.run(iso)
    eqm = ('1 1\n\nORT-M 1  %s %s %s  %s %s %s  %s %s %s  %s\n' % (
        V.fmt(E), V.fmt(E), V.fmt(E), V.fmt(NU), V.fmt(NU), V.fmt(NU),
        V.fmt(G), V.fmt(G), V.fmt(G), V.fmt(2700.0)))
    lam = '2\n\nLAM2 1 1 0.0 37.0\nLAM2 2 1 23.0 55.0\n'
    ro = g.run(V.plate_case('lam_ort', 'Q9', 8, ('LE', 'B3', 2),
                            load=('shear', P), material=eqm,
                            lamination=lam, ply=[1, 2]))
    g.check('isotropic ORT-M with ply angles (37,0) / (23,55) == ISO-M '
            '(rotation machinery)', ro.u(0)[2], ri.u(0)[2], 1e-9,
            'invariance of the isotropic tensor')
    lam3 = '3\n\nLAM2 1 1 0 0\nLAM2 2 1 0 0\nLAM2 3 1 0 0\n'
    mono = g.run(V.plate_case('lam_mono', 'Q9', 8, ('LE', 'B2', 3),
                              load=('shear', P)))
    split = g.run(V.plate_case('lam_split', 'Q9', 8, ('LE', 'B2', 3),
                               load=('shear', P), lamination=lam3,
                               ply=[1, 2, 3]))
    g.check('three plies of the same material == one lamination',
            split.u(0)[2], mono.u(0)[2], 1e-12, 'same model')
    # cross-ply laminates against the closed form
    ht = 0.1
    rows = []
    laminate_lam = '2\n\nLAM2 1 1 0.0 0.0\nLAM2 2 1 0.0 90.0\n'
    for name, angs, ply in (('[0/90/0]', [0, 90, 0], [1, 2, 1]),
                            ('[90/0/90]', [90, 0, 90], [2, 1, 2]),
                            ('[0/0/0]', [0, 0, 0], [1, 1, 1]),
                            ('[90/90/90]', [90, 90, 90], [2, 2, 2])):
        Pl = 1.0e3
        c = V.plate_case('lamx_' + name.replace('/', '').strip('[]'),
                         'Q9', 8, ('LE', 'B3', 3), h=ht, load=('shear', Pl),
                         material=orth_text(), lamination=laminate_lam,
                         ply=ply)
        r = g.run(c)
        D = cross_ply_flexural(angs, ht)
        w_eb = (Pl / B) * L ** 3 / (3 * D)
        w = r.u(0)[2] if r.ok and r.points else float('nan')
        rows.append([name, '%.5e' % D, '%.5e' % w_eb, '%.5e' % w,
                     '%+.3f' % (100 * (w / w_eb - 1))])
        g.check('laminate %s: tip deflection vs plane-strain '
                'Euler-Bernoulli laminate' % name, w, w_eb, 0.03,
                'closed form sum(E\'_k (z_k+1^3 - z_k^3))/3')
    g.table('Cross-ply laminated strips (L=10, h=0.1, three equal plies, '
            'carbon-like ply 140/10 GPa), plane strain in x',
            ['stacking', 'D [N m]', 'EB tip w [m]', 'computed w [m]',
             'error [%]'], rows,
            'Closed form: flexural rigidity of the plane-strain reduced '
            'axial modulus of each ply.  The 0 degree plies have the '
            'fibre along the strip axis y.')
    g.save()
    return g
