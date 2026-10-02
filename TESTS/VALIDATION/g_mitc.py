"""Group: MITC shear-locking correction versus full integration."""
import vlib as V
from vcheck import Group
from g_beams import E, NU, RHO, G, KAP

HT = 0.1                       # thin: slenderness L/h = 100
LT = V.LB
BT = V.BB


def beam_ref(P):
    I = HT * HT ** 3 / 12.0
    A = HT * HT
    return (V.timoshenko_tip(P, LT, E, I, G, A, KAP),
            V.timoshenko_freqs(LT, E, I, RHO, A, G, KAP, 2)[0])


def strip_ref(P):
    Ep = E / (1 - NU ** 2)
    Ih = HT ** 3 / 12.0
    q = P / BT
    return (V.timoshenko_tip(q, LT, Ep, Ih, G, HT, 5 / 6.),
            V.timoshenko_freqs(LT, Ep, Ih, RHO, HT, G, 5 / 6., 2)[0])


def group_mitc():
    g = Group('mitc', 'MITC shear correction versus full integration',
              'Slender structures (L/h = 100) where the full integration '
              'of the transverse shear locks.  Each cell reports the ratio '
              'between the computed tip deflection and the Timoshenko '
              'solution (1.000 = no locking).')
    rows = []
    # ------------------------------------------------------------ beams
    P = 1.0
    wref, fref = beam_ref(P)
    sec_le = V.rect_mesh('Q9', 1, 1, -HT / 2, HT / 2, -HT / 2, HT / 2)
    sec_te = V.rect_mesh('Q9', 1, 1, -HT / 2, HT / 2, -HT / 2, HT / 2)
    for sname, sec, kin in (('LE Q9 1x1', sec_le, 'LE 1'),
                            ('TE2', sec_te, 'TE 2')):
        for bt, nel in (('B2', 12), ('B3', 6), ('B4', 4)):
            vals = {}
            for shear in ('NONE', 'MITC'):
                c = V.beam_case('mt_b_%s_%s_%s' % (sname.split()[0], bt, shear),
                                sec, kin, btype=bt, nel=nel, shear=shear,
                                load=('shear', P))
                # the helper fixes the section height from the mesh; the
                # load weights come from the mesh itself
                r = g.run(c)
                cm = V.beam_case('mt_bm_%s_%s_%s' % (sname.split()[0], bt,
                                                    shear), sec, kin,
                                 btype=bt, nel=nel, shear=shear, sol=103,
                                 nmodes=4)
                rm = g.run(cm)
                vals[shear] = (r.u(0)[2] / wref if r.ok and r.points else
                               float('nan'),
                               rm.freq[0] / fref if rm.ok and rm.freq else
                               float('nan'))
            rows.append(['beam %s' % sname, '%s x %d' % (bt, nel),
                         '%.3f' % vals['NONE'][0], '%.3f' % vals['MITC'][0],
                         '%.3f' % vals['NONE'][1], '%.3f' % vals['MITC'][1]])
            g.check('beam %s %s MITC: tip deflection ratio' % (sname, bt),
                    vals['MITC'][0], 1.0, 0.04, 'Timoshenko beam')
            g.check('beam %s %s MITC: f1 ratio' % (sname, bt),
                    vals['MITC'][1], 1.0, 0.03, 'Timoshenko beam')
            if bt == 'B2':
                g.check('beam %s B2: MITC removes the locking of the full '
                        'integration' % sname,
                        1.0 if abs(vals['MITC'][0] - 1) <
                        abs(vals['NONE'][0] - 1) else 0.0, 1.0, 0.0,
                        'locking relief', mode='abs',
                        note='ratio NONE %.3f, MITC %.3f' % (
                            vals['NONE'][0], vals['MITC'][0]))
    # ----------------------------------------------------------- plates
    P = 1.0e3
    wref, fref = strip_ref(P)
    NY = {'Q4': 16, 'Q9': 8, 'Q16': 5, 'T3': 16, 'T6': 8}
    for topo, ny in NY.items():
        vals = {}
        for shear in ('NONE', 'MITC'):
            c = V.plate_case('mt_p_%s_%s' % (topo, shear), topo, ny,
                             ('LE', 'B3', 1), h=HT, shear=shear,
                             load=('shear', P))
            r = g.run(c)
            cm = V.plate_case('mt_pm_%s_%s' % (topo, shear), topo, ny,
                              ('LE', 'B3', 1), h=HT, shear=shear, sol=103,
                              nmodes=4)
            rm = g.run(cm)
            vals[shear] = (r.u(0)[2] / wref if r.ok and r.points else
                           float('nan'),
                           rm.freq[0] / fref if rm.ok and rm.freq else
                           float('nan'))
        rows.append(['plate %s (%d el.)' % (topo, ny), 'LE B3 x 1',
                     '%.3f' % vals['NONE'][0], '%.3f' % vals['MITC'][0],
                     '%.3f' % vals['NONE'][1], '%.3f' % vals['MITC'][1]])
        if topo in ('Q4', 'Q9', 'Q16'):
            g.check('plate %s MITC: tip deflection ratio' % topo,
                    vals['MITC'][0], 1.0, 0.04, 'Timoshenko strip')
            g.check('plate %s MITC: f1 ratio' % topo, vals['MITC'][1], 1.0,
                    0.03, 'Timoshenko strip')
        else:
            g.check('plate %s (no MITC table, full integration): ratio'
                    % topo, vals['MITC'][0], 1.0, None, 'Timoshenko strip',
                    note='MITC is not defined for triangles; both columns '
                         'use the full integration')
        if topo == 'Q4':
            g.check('plate Q4: MITC removes the locking of the full '
                    'integration', 1.0 if abs(vals['MITC'][0] - 1) <
                    abs(vals['NONE'][0] - 1) else 0.0, 1.0, 0.0,
                    'locking relief', mode='abs',
                    note='ratio NONE %.3f, MITC %.3f' % (
                        vals['NONE'][0], vals['MITC'][0]))
    # ----------------------------------------------------------- solids
    for topo, (ny, nz) in (('H8', (20, 2)), ('H27', (10, 1))):
        vals = {}
        for shear in ('NONE', 'MITC'):
            c = V.solid_case('mt_s_%s_%s' % (topo, shear), topo, ny, nz,
                             h=HT, shear=shear, load=('shear', P))
            r = g.run(c)
            cm = V.solid_case('mt_sm_%s_%s' % (topo, shear), topo, ny, nz,
                              h=HT, shear=shear, sol=103, nmodes=4)
            rm = g.run(cm)
            vals[shear] = (r.u(0)[2] / wref if r.ok and r.points else
                           float('nan'),
                           rm.freq[0] / fref if rm.ok and rm.freq else
                           float('nan'))
        rows.append(['solid %s' % topo, '1x%dx%d' % (ny, nz),
                     '%.3f' % vals['NONE'][0], '%.3f' % vals['MITC'][0],
                     '%.3f' % vals['NONE'][1], '%.3f' % vals['MITC'][1]])
        g.check('solid %s MITC: tip deflection ratio' % topo,
                vals['MITC'][0], 1.0, 0.04 if topo == 'H27' else 0.1,
                'Timoshenko strip')
        g.check('solid %s: MITC is closer to the solution than the full '
                'integration' % topo,
                1.0 if abs(vals['MITC'][0] - 1) <= abs(vals['NONE'][0] - 1)
                else 0.0, 1.0, 0.0, 'locking relief', mode='abs',
                note='ratio NONE %.3f, MITC %.3f' % (vals['NONE'][0],
                                                     vals['MITC'][0]))
    g.table('Slender structures (L/h = 100): response relative to the '
            'Timoshenko solution (1 = exact)',
            ['structure', 'discretisation', 'tip w, full', 'tip w, MITC',
             'f1, full', 'f1, MITC'], rows,
            'Beams: square section h = b = 0.1; plates and solids: '
            'plane-strain strip h = 0.1, b = 1.  Triangles have no tying '
            'table: both columns are identical.')
    g.save()
    return g

