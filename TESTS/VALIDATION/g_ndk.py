"""Group: models with node-dependent kinematics (NDK)."""
import vlib as V
from vcheck import Group
from g_beams import (L, B, H, E, NU, I, W_TIM, references, ref_table, D0,
                     section, patch_error, P)
from g_hle import hle_section

NEL = 6
NN = 3 * NEL + 1
SPLIT = 9                  # nodes 0..SPLIT-1 use A, SPLIT..NN-1 use B


def kin_list(a, b, interface=None):
    k = [a] * SPLIT + [b] * (NN - SPLIT)
    if interface:
        k[SPLIT] = interface
    return k


def model(g, name, secs, elem_sec, kin, sol=101, nu=NU, load='shear',
          points=None, nm=6):
    kw = dict(nel=NEL, elem_section=elem_sec, nu=nu, shear='MITC')
    if sol == 101:
        if load == 'shear':
            kw['load'] = ('shear', P)
        else:
            kw['load'] = ('axial_disp', D0)
    c = V.beam_case(name, secs, kin, sol=sol, nmodes=nm, points=points, **kw)
    return g.run(c)


def group_ndk():
    g = Group('ndk', 'Non-uniform (node-dependent) kinematics',
              'A B4 x 6 cantilever (L=10, section 1x1): the structural '
              'nodes 1-9 carry the expansion A and nodes 10-19 the '
              'expansion B, so that the element 3 mixes both.  Pairs: '
              'TE-m/TE-n, TE/LE, HLE/TE and HLE/LE (the last through a '
              'Taylor node on the interface, because a Lagrange or '
              'hierarchical node requires a single section mesh).')
    ref = references()
    ref_table(g, ref)
    q9 = section('Q9', 1)
    q9b = section('Q9', 2)
    hq = hle_section(2, 3)
    pts_patch = [(0.0, 2.0, 0.0), (0.3, 8.2, -0.2)]
    pts_cont = [(0.3, 5.0 - 1e-7, 0.2), (0.3, 5.0 + 1e-7, 0.2)]
    # (label, secs, elem_section, kin A, kin B, interface node kin)
    cases = [
        ('TE1 / TE4', [q9], [1] * NEL, 'TE1', 'TE4', None),
        ('TE2 / TE6', [q9], [1] * NEL, 'TE2', 'TE6', None),
        ('TE4 / TE2', [q9], [1] * NEL, 'TE4', 'TE2', None),
        ('TE3 / TE8', [q9], [1] * NEL, 'TE3', 'TE8', None),
        ('TE4 / LE', [q9b], [1] * NEL, 'TE4', 'LE', None),
        ('LE / TE4', [q9b], [1] * NEL, 'LE', 'TE4', None),
        ('HLE / TE4', [hq], [1] * NEL, 'HLE', 'TE4', None),
        ('TE4 / HLE', [hq], [1] * NEL, 'TE4', 'HLE', None),
        ('HLE / LE (TE4 interface)', [hq, q9b], [1, 1, 1, 2, 2, 2], 'HLE',
         'LE', 'TE4'),
        ('LE / HLE (TE4 interface)', [q9b, hq], [1, 1, 1, 2, 2, 2], 'LE',
         'HLE', 'TE4'),
    ]
    # uniform models used as bounds: (secs, elem_sec, token)
    uni = {}

    def uniform(tok, secs, es):
        key = (tok, id(secs[0]))
        if key not in uni:
            kin = tok if tok in ('LE', 'HLE') else tok
            r = model(g, 'ndk_u_%s_%d' % (tok, len(uni)), secs, es,
                      kin_list(tok, tok))
            rm = model(g, 'ndk_um_%s_%d' % (tok, len(uni)), secs, es,
                       kin_list(tok, tok), sol=103)
            uni[key] = (r.u(0)[2] if r.ok and r.points else float('nan'),
                        rm.freq[0] if rm.ok and rm.freq else float('nan'))
        return uni[key]

    rows = []
    for label, secs, es, a, b, itf in cases:
        kin = kin_list(a, b, itf)
        tag = label.replace(' ', '').replace('/', '_').replace('(', '_') \
            .replace(')', '')
        # exactness: uniform extension (nu = 0)
        rp = model(g, 'ndk_p_' + tag, secs, es, kin, nu=0.0, load='axial',
                   points=pts_patch)
        pe = patch_error(rp) if rp.ok and rp.points else float('nan')
        g.check('%s: uniform-extension patch test (nu=0)' % label, pe, 0.0,
                1e-6, 'exact field', mode='abs')
        # static / modal
        pts = [(0.0, L - 1e-6, 0.0)] + pts_cont
        r = model(g, 'ndk_s_' + tag, secs, es, kin, points=pts)
        rm = model(g, 'ndk_m_' + tag, secs, es, kin, sol=103)
        if not (r.ok and rm.ok and r.points):
            g.flag('%s runs' % label, False, 'run failed')
            rows.append([label, 'fail'] + ['-'] * 7)
            continue
        w = r.u(0)[2]
        f1 = rm.freq[0]
        jump = abs(r.u(1)[2] - r.u(2)[2]) / abs(w)
        jx = abs(r.u(1)[0] - r.u(2)[0]) / abs(w)
        g.check('%s: displacement continuity at the interface node '
                '(jump / tip w)' % label, max(jump, jx), 0.0, 1e-5,
                'continuity of the field', mode='abs')
        # bounds from the uniform models of the same section meshes
        wa = uniform(a if a != 'HLE' else 'HLE', secs[:1], [1] * NEL)[0]
        wb = uniform(b if b != 'HLE' else 'HLE', secs[-1:], [1] * NEL)[0]
        lo, hi = min(wa, wb), max(wa, wb)
        inside = lo * 0.995 <= w <= hi * 1.005
        g.check('%s: tip deflection between the two uniform models' % label,
                1.0 if inside else 0.0, 1.0, 0.0,
                'uniform A: %.5e, uniform B: %.5e' % (wa, wb), mode='abs',
                note='NDK %.5e' % w)
        if a != 'TE1' and b != 'TE1':
            g.check('%s: tip deflection vs LE reference' % label, w,
                    ref['le_w'], 0.02, 'LE Q16 4x4')
        rows.append([label, r.ndof, '%.5e' % wa, '%.5e' % wb, '%.5e' % w,
                     '%+.3f' % (100 * (w / ref['le_w'] - 1)),
                     '%.4f' % f1, '%.1e' % pe, '%.1e' % max(jump, jx)])
    g.table('NDK models: tip deflection, first frequency and exactness',
            ['A / B', 'DOF', 'w uniform A', 'w uniform B', 'w NDK',
             'vs LE ref [%]', 'f1 [Hz]', 'patch err', 'interface jump'],
            rows,
            'w uniform A / B: the same beam with the expansion A or B '
            'on all the nodes (same section meshes).  The interface '
            'jump is the displacement difference measured 1e-7 before and '
            'after the interface node, relative to the tip deflection.')
    # equivalence: KINEMATICS.dat route versus the NODES.dat tokens
    ra = V.beam_case('ndk_eq_a', q9, 'TE 4', nel=NEL, load=('shear', P))
    ra = g.run(ra)
    rb = V.beam_case('ndk_eq_b', q9, ['TE4'] * NN, nel=NEL,
                     load=('shear', P))
    rb = g.run(rb)
    g.check('KINEMATICS.dat (TE4 on every node) == NODES.dat token TE 4',
            rb.u(0)[2], ra.u(0)[2], 1e-12, 'same model, two input routes')
    ra = V.beam_case('ndk_eq_c', q9b, 'LE 1', nel=NEL, load=('shear', P))
    ra = g.run(ra)
    rb = V.beam_case('ndk_eq_d', q9b, ['LE'] * NN, nel=NEL,
                     load=('shear', P))
    rb = g.run(rb)
    g.check('KINEMATICS.dat (LE on every node) == NODES.dat token LE',
            rb.u(0)[2], ra.u(0)[2], 1e-12, 'same model, two input routes')
    g.save()
    return g
