"""Build the validation report (HTML -> PDF with Edge headless).

    python build_report.py

Reads results/*.json (written by run_all.py) and, if present,
results/regression.json (ctest results).  Output: DOC/MUL2_NEW_Validation_Report.pdf
"""
import base64
import datetime
import html
import io
import json
import os
import subprocess

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
RES = os.path.join(HERE, 'results')
OUT_HTML = os.path.join(HERE, 'results', 'validation_report.html')
OUT_PDF = os.path.join(ROOT, 'DOC', 'MUL2_NEW_Validation_Report.pdf')
EDGE = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

ORDER = ['taylor', 'le', 'hle', 'plates', 'plates2', 'solids', 'ndk',
         'multi', 'mitc', 'multifield', 'nonlinear']
TITLES = {
    'taylor': 'Taylor expansions up to order 20',
    'le': 'Lagrange expansions of all section types',
    'hle': 'Hierarchical Legendre expansions',
    'plates': 'Plate elements Q4, Q9, Q16, T3, T6',
    'plates2': 'Further plate benchmarks',
    'solids': 'Solid elements H8 and H27',
    'ndk': 'Models with node-dependent kinematics',
    'multi': 'Multi-dimensional models',
    'mitc': 'MITC versus full integration',
    'multifield': 'Multifield analyses: electric and thermal fields',
    'nonlinear': 'Geometrically nonlinear analyses',
}
WHAT = {
    'taylor': ('Convergence of the Taylor expansion (TE1-TE20) of a beam '
               'section against closed-form beam theories and against two '
               'independent 3D references; exactness of the uniform '
               'extension; independence of the result from the size of the '
               'section.'),
    'le': ('Section meshes of Q4, Q9, Q16, T3 and T6 sub-elements with '
           'increasing refinement: convergence, agreement with a 3D solid '
           'model, exactness of the uniform extension and of the pure '
           'bending.'),
    'hle': ('p-convergence of the hierarchical expansion (HQ4 up to order '
            '8), equivalence with the Lagrange Q4 for p = 1, the patch '
            'test, sub-elements of different order sharing an interface '
            '(Ritz bounds and independence of the node numbering) and curved '
            'sections described by arcs.'),
    'plates': ('Plate topologies (in-plane) combined with Taylor, Lagrange '
               'and hierarchical expansions through the thickness, against a '
               '3D plane-strain solid and the Timoshenko strip.'),
    'plates2': ('Navier series for a simply supported plate, Taylor '
                'thickness expansion up to order 20, equivalence of the '
                'hierarchical and Lagrange thickness expansions, rotation of '
                'the material axes and cross-ply laminates against the '
                'classical closed form.'),
    'solids': ('H8 and H27 hexahedra with and without MITC: convergence '
               'against Timoshenko and a fine H27 mesh, patch test and pure '
               'bending.'),
    'ndk': ('Beams whose nodes carry different expansions (TE-m/TE-n, '
            'TE/LE, HLE/TE, HLE/LE): exactness, continuity at the '
            'interface, bounds given by the uniform models.'),
    'multi': ('Beams, plates and solids in the same model, either in '
              'independent regions or joined at shared nodes, with exact '
              'closed-form solutions.'),
    'multifield': ('Displacements coupled with the electric potential '
                   '(piezoelectric actuation, short/open circuit '
                   'resonance of a stack) and with the temperature '
                   '(thermal expansion and stress, steady conduction, '
                   'transient heat conduction with thermal capacity), '
                   'and selection of the fields in ANALYSIS.dat.'),
    'nonlinear': ('Large-displacement statics (analysis 108): elastica of '
                  'a cantilever for a sweep of the load, beam-column '
                  'with P-delta effect, solid elastica, thermal strain '
                  'in the Green measure and snap-through of a shallow '
                  'arch with the arc length method.'),
    'mitc': ('Shear-locking relief of the MITC tying compared with the full '
             'integration on slender beams, plates and solids '
             '(L/h = 100).'),
}


def esc(s):
    return html.escape(str(s))


def fnum(x, d=4):
    if x is None:
        return '&ndash;'
    if isinstance(x, str):
        return esc(x)
    if x != x:
        return 'NaN'
    if x == 0:
        return '0'
    a = abs(x)
    if 1e-3 <= a < 1e5:
        return ('%.' + str(d) + 'g') % x
    return ('%.' + str(d - 1) + 'e') % x


def plot_png(s):
    fig, ax = plt.subplots(figsize=(5.2, 3.4), dpi=170)
    marks = ['o', 's', '^', 'D', 'v', 'P', 'X', '<']
    cols = ['#1f4e79', '#c0504d', '#4f8f3a', '#8064a2', '#e08a00',
            '#2c9aa0', '#7f7f7f', '#b0306a']
    for k, (lab, (xs, ys)) in enumerate(s['curves'].items()):
        ax.plot(xs, ys, marker=marks[k % 8], ms=4, lw=1.3,
                color=cols[k % 8], label=lab)
    for k, (lab, v) in enumerate(s['hlines'].items()):
        ax.axhline(v, ls='--', lw=1.0, color=['#555', '#a33', '#383',
                                               '#639'][k % 4], label=lab)
    if s['logx']:
        ax.set_xscale('log')
    if s['logy']:
        ax.set_yscale('log')
    ax.set_xlabel(s['xlabel'], fontsize=9)
    ax.set_ylabel(s['ylabel'], fontsize=9)
    ax.set_title(s['title'], fontsize=10)
    ax.tick_params(labelsize=8)
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=7.5, ncol=2, framealpha=0.9)
    fig.tight_layout()
    bio = io.BytesIO()
    fig.savefig(bio, format='png')
    plt.close(fig)
    return base64.b64encode(bio.getvalue()).decode()


def table_html(t):
    out = ['<h4 class="tcap">%s</h4><table class="data"><thead><tr>' %
           esc(t['title'])]
    out += ['<th>%s</th>' % esc(h) for h in t['headers']]
    out.append('</tr></thead><tbody>')
    for r in t['rows']:
        out.append('<tr>' + ''.join('<td>%s</td>' % esc(c) for c in r) +
                   '</tr>')
    out.append('</tbody></table>')
    if t.get('note'):
        out.append('<p class="note">%s</p>' % esc(t['note']))
    return '\n'.join(out)


def checks_html(g):
    out = ['<h4 class="tcap">Check list of the group '
           '(%d checks)</h4><table class="checks"><thead><tr><th>#</th>'
           '<th>check</th>'
           '<th>computed</th><th>reference</th><th>error</th>'
           '<th>tol.</th><th>reference solution</th><th>result</th>'
           '</tr></thead><tbody>' % len(g['checks'])]
    for i, c in enumerate(g['checks']):
        cls = {'PASS': 'ok', 'FAIL': 'bad', 'INFO': 'info'}[c['status']]
        if c['mode'] == 'flag':
            m = r = ''
            e = ''
            tl = ''
            ref = esc(c['ref']) if c['ref'] else ''
            note = esc(c['note']) if isinstance(c['note'], str) else \
                esc('; '.join(c['note']))
            extra = '<br><span class="note">%s</span>' % note if note else ''
        else:
            m, r = fnum(c['measured']), fnum(c['reference'])
            e = fnum(c['err'], 2)
            tl = fnum(c['tol'], 2) if c['tol'] is not None else '&ndash;'
            ref = esc(c['ref'])
            extra = ('<br><span class="note">%s</span>' % esc(c['note'])
                     if c['note'] else '')
        out.append('<tr class="%s"><td>%d</td><td>%s%s</td><td>%s</td>'
                   '<td>%s</td><td>%s</td><td>%s</td><td>%s</td>'
                   '<td class="st">%s</td></tr>' % (
                       cls, i + 1, esc(c['name']), extra, m, r, e, tl, ref,
                       c['status']))
    out.append('</tbody></table>')
    return '\n'.join(out)


CSS = """
@page { size: A4; margin: 16mm 14mm 16mm 14mm; }
body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 9.5pt;
       color: #1a1a1a; line-height: 1.38; }
h1 { font-size: 24pt; margin: 0 0 4pt 0; color: #14375e; }
h2 { font-size: 15pt; color: #14375e; border-bottom: 1.5px solid #14375e;
     padding-bottom: 2pt; margin-top: 20pt; page-break-before: always; }
h2.first { page-break-before: auto; }
h3 { font-size: 11.5pt; color: #14375e; margin-top: 12pt; }
.cover { text-align: left; padding-top: 55mm; }
.cover .sub { font-size: 13pt; color: #444; margin-bottom: 18pt; }
.cover .meta td { padding: 2pt 14pt 2pt 0; font-size: 10pt; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0 4pt 0; }
table.data th, table.data td, table.checks th, table.checks td,
table.sum th, table.sum td { border: 0.5px solid #9aa6b5; padding: 2pt 4pt; }
table.data { font-size: 8pt; }
table.data thead th, table.checks thead th, table.sum thead th {
   background: #dbe5f1; text-align: left; }
table.data td { font-variant-numeric: tabular-nums; }
table.checks { font-size: 7pt; }
table.sum { font-size: 9pt; }
h4.tcap { text-align: left; font-weight: 600; font-size: 9pt;
          color: #14375e; margin: 10pt 0 2pt 0; break-after: avoid;
          page-break-after: avoid; }
tr { page-break-inside: avoid; }
tr.ok td.st { color: #1b7a2b; font-weight: 700; }
tr.bad td.st { color: #b3261e; font-weight: 700; }
tr.bad { background: #fdecea; }
tr.info td.st { color: #8a6d00; font-weight: 700; }
.note { color: #555; font-size: 7.5pt; margin: 1pt 0 3pt 0; }
p.note { font-size: 8.5pt; }
.fig { text-align: center; page-break-inside: avoid; margin: 6pt 0; }
.fig img { max-width: 78%; }
.figs { display: flex; flex-wrap: wrap; justify-content: center; gap: 4pt; }
.figs .fig { width: 49%; margin: 2pt 0; }
.figs .fig img { max-width: 100%; }
.callout { border-left: 3px solid #14375e; background: #eef3fa;
           padding: 5pt 8pt; margin: 6pt 0; }
.callout.warn { border-left-color: #c77d00; background: #fff6e5; }
.badge { display: inline-block; padding: 1pt 6pt; border-radius: 8pt;
         font-weight: 700; font-size: 8.5pt; }
.badge.ok { background: #d9f0dc; color: #15642a; }
.badge.bad { background: #f8d7d3; color: #9c1f17; }
ul { margin: 3pt 0 3pt 14pt; padding: 0; }
code { font-family: Consolas, monospace; font-size: 8.5pt; }
"""


FINDINGS = [
    ('warn', 'Shell edges: the first-order Taylor term cannot be shared '
     'as a Cartesian vector.',
     'A thin square box built with shells shared at the corner nodes came '
     'out 5 to 10 times too stiff in bending. At an edge the thickness '
     'derivative of a wall of normal x and of a wall of normal z is not the '
     'same quantity, and sharing it suppresses the bending slope at the '
     'edge. The first-order term of the shell is now the rotation of the '
     'node acting on the director of each element (corrected; the square '
     'tube is 0.995-1.03 of beam theory). The previous square-tube test '
     'passed because its beam-theory reference had a wrong moment of '
     'inertia; reference and load case were corrected.'),
    ('warn', 'The nodal director was not averaged.',
     'An early exit in the loop over the elements at a node used only the '
     'first element listed. Corrected; found, with the previous item, on '
     'the wing box of the aircraft (closed-form stiffness known).'),
    ('warn', 'Rows of order-0 nodes lock the skin.',
     'Beam elements joined to a skin along a whole line of TE0 nodes '
     '(stringers, rings) make the structure 4 to 6 times too stiff: a node '
     'of order 0 has no rotation. TE0 joints are admissible at isolated '
     'nodes only (documented in the user guide).'),
    ('warn', 'Triangular section sub-elements (T3) are unreliable for '
     'beams.',
     'T3 uses a one-point integration rule (inherited from the baseline). '
     'The products of linear shape functions that appear in the axial '
     'strain and in the mass are then under-integrated: a 1x1 section of '
     'two triangles gives a singular matrix, a 2x2 section is 17% too soft '
     'and a 4x4 section 3% too soft (table in the LE chapter). The cause '
     'was confirmed with a temporary change (not kept in the code): with a '
     'three-point rule the matrix is regular for every mesh, the pure '
     'bending is exact to 1e-11 and the tip deflection converges from '
     'below (-19.7%, -7.8%, -2.4%, -0.7% for 1x1, 2x2, 4x4, 8x8 '
     'sections). T3 plates (in-plane) behave as the usual constant-strain '
     'triangle (-3% on the tip deflection with 16 elements) but lock in '
     'bending because the MITC tying exists only for quadrilaterals. '
     'Recommendation: use T6 (or Q9) sections, or adopt the three-point '
     'rule for T3 (a change of one line in <code>mul2_quadrature.for</code>'
     ' that moves the results away from the frozen baseline for T3 only).'),
    ('warn', 'The MITC tying of the H8 solid works; the documentation '
     'says the opposite.',
     'STATUS.md and the notes of the User Guide state that H8 + MITC gives '
     'a singular matrix. In all the tests of this campaign (plane-strain '
     'strips and free blocks, meshes up to 2214 DOF) H8 + MITC is regular, '
     'reproduces the pure bending to 1e-8 and removes most of the bending '
     'locking of the full integration (error -6.8% against -29.7% on a '
     '10x2 mesh). The statement should be removed or restricted to the '
     'configuration in which it was observed.'),
    ('', 'T6 integration (three points) is not exact for the products of '
     'quadratic functions.',
     'The pure bending of a T6 section is reproduced with an error of '
     '2.6e-6 instead of the 1e-8 of the quadrilaterals. The effect is '
     'negligible for engineering use.'),
    ('', 'Debug build: false bounds violation in the curved-HLE geometry '
     'cache (fixed).',
     'The Debug configuration (full run-time checks) stopped with '
     '"subscript of VERTEX_2D out of range" on every model with curved HQ4 '
     'sides, while Release was correct. The array-constructor assignments '
     'of the vertex and mid-node coordinates in '
     '<code>mul2_gauss_geometry.for</code> were replaced by scalar '
     'assignments; Debug and Release now give the same frequency '
     '(11.2619 Hz for the tube with p = 2) and both pass the six '
     'regression suites.'),
    ('', 'Linear thickness expansions lock in plane strain.',
     'TE1, HB p=1 and B2 with one element give errors of -17.7% on the '
     'strip (Poisson locking: u_z linear in z gives a constant '
     '&epsilon;<sub>zz</sub>). TE2, HB p>=2 and Lagrange B3/B4 remove it. '
     'This is the known behaviour of the unified formulation.'),
    ('', 'Quadrilateral beam sections with a single Q4 are too stiff.',
     'A 1x1 Q4 section is 13% too stiff in bending, 4% with 2x2 '
     'and 1% with 4x4 sub-elements. Use Q9 or Q16 sub-elements.'),
]

NOT_COVERED = [
    'Curved beams and shells in the linear buckling (105) and nonlinear (108) '
    'analyses and surface loads on them (they stop with an error).',
    'A beam sharing nodes with a shell along a line: the beam-shell joint '
    'is limited to isolated nodes of order 0 (a row of them locks the '
    'skin).',
    'Shell edges with LE kinematics (the node rotation of an edge needs a '
    'Taylor expansion).',
    'Distributed or follower loads, plasticity, contact.',
    'The complete aircraft has no closed-form reference: it is a robustness '
    'and performance demonstration.',
    'Linux/gfortran builds (not exercised in this campaign).',
]


SUITE_ORDER = ['MUL2_HLE_SOLVER_TESTS', 'MUL2_REDUCED_TESTS',
               'MUL2_PIEZO_TESTS', 'MUL2_EXTENDED_TESTS',
               'MUL2_THERMAL_TESTS', 'MUL2_DYNAMICS_TESTS',
               'MUL2_BUCKLING_TESTS', 'MUL2_NONLINEAR_TESTS',
               'MUL2_CURVED_TESTS', 'MUL2_JOIN_TESTS']
SUITE_DESC = {
    'MUL2_HLE_SOLVER_TESTS': 'hierarchical expansions at solver level',
    'MUL2_REDUCED_TESTS': 'reduced and selective integration, locking',
    'MUL2_PIEZO_TESTS': 'piezoelectric and pyroelectric fields',
    'MUL2_EXTENDED_TESTS': 'dynamics, frequency response, thermoelastic '
                           'fields',
    'MUL2_THERMAL_TESTS': 'temperature field, heat loads, thermal stress',
    'MUL2_DYNAMICS_TESTS': 'time response, damping, heat transient',
    'MUL2_BUCKLING_TESTS': 'linear and thermal buckling',
    'MUL2_NONLINEAR_TESTS': 'geometric nonlinearity, load control and arc '
                            'length',
    'MUL2_CURVED_TESTS': 'curved beams and shells, tubes, joints',
    'MUL2_JOIN_TESTS': 'joining of the DOFs by coincidence',
}
AIRCRAFT = """<p>A twin-engine transport aircraft of the 737 class
(<code>EXAMPLES/AIRCRAFT</code>): 14 433 nodes, 3 706 S9 shells (fuselage,
frames, floor, wings, tails, spars, ribs, fairings, pylons), 4 CB3 curved beams
(tie rods) and 48 H8 solids (engines), 129 093 degrees of freedom, all joined by
shared nodes with node-dependent kinematics (no multipliers).</p>
<table class="sum"><thead><tr><th>item</th><th>result</th></tr></thead><tbody>
<tr><td>rigid-body modes of the free aircraft</td><td>6</td></tr>
<tr><td>first elastic modes (103)</td><td>0.89, 1.55, 2.25, 2.61, 2.63, 3.82,
3.95 Hz (global modes of wings, fuselage and fin)</td></tr>
<tr><td>clamped wing box, tip load 10 kN</td><td>13.9 mm against 13.8 mm of beam
theory</td></tr>
<tr><td>static (101): nose ring clamped, 50 kN at each wing tip</td><td>tip
displacements 0.33010 m and 0.33012 m (symmetric to 5e-5), maximum 0.34 m
</td></tr>
<tr><td>time (fine mesh)</td><td>modes (40): 2 min; static: 27 s</td></tr>
</tbody></table>
<p>The aircraft is a robustness and performance demonstration of the whole
chain (input, assembly, solvers, output); the accuracy of the single elements
and joints is established by the checks of the previous chapters. It also
exposed the two corrected defects listed in the findings.</p>"""


def main():
    groups = {}
    for gid in ORDER:
        p = os.path.join(RES, gid + '.json')
        if os.path.exists(p):
            groups[gid] = json.load(open(p))
    reg = None
    rp = os.path.join(RES, 'regression.json')
    if os.path.exists(rp):
        reg = json.load(open(rp))
    meta = {}
    mp = os.path.join(RES, 'meta.json')
    if os.path.exists(mp):
        meta = json.load(open(mp))

    tot = dict(n=0, p=0, f=0, i=0, runs=0, sec=0.0)
    for g in groups.values():
        st = [c['status'] for c in g['checks']]
        g['_n'] = len(st)
        g['_p'] = st.count('PASS')
        g['_f'] = st.count('FAIL')
        g['_i'] = st.count('INFO')
        tot['n'] += g['_n']
        tot['p'] += g['_p']
        tot['f'] += g['_f']
        tot['i'] += g['_i']
        tot['runs'] += g['runs']
        tot['sec'] += g['seconds']

    h = ['<!doctype html><html><head><meta charset="utf-8">'
         '<title>MUL2_NEW Validation Report</title><style>%s</style>'
         '</head><body>' % CSS]
    # ------------------------------------------------------------ cover
    today = datetime.date.today().strftime('%d %B %Y')
    h.append('<div class="cover"><h1>MUL2_NEW<br>Validation Report</h1>'
             '<div class="sub">Benchmarks, closed-form comparisons and '
             'cross-checks of the static, free-vibration, dynamic, buckling, '
             'nonlinear, multiphysics and curved beam/shell analyses</div><table class="meta">'
             '<tr><td><b>Program</b></td><td>MUL2_NEW (unified CUF finite '
             'element code: TE, LE, HLE expansions; beams, plates, '
             'solids)</td></tr>'
             '<tr><td><b>Executable</b></td><td>%s</td></tr>'
             '<tr><td><b>Date</b></td><td>%s</td></tr>'
             '<tr><td><b>Campaign</b></td><td>%d checks in %d solver runs'
             '</td></tr>'
             '<tr><td><b>Generated by</b></td><td><code>TESTS/VALIDATION/'
             'run_all.py</code> and <code>build_report.py</code></td></tr>'
             '</table></div>' % (esc(meta.get('exe', 'Release build')),
                                 today, tot['n'], tot['runs']))
    # --------------------------------------------------- 1 summary
    h.append('<h2 class="first">1. Summary</h2>')
    verdict = 'bad' if tot['f'] else 'ok'
    h.append('<p><span class="badge %s">%d of %d checks passed, %d failed, '
             '%d informative</span></p>' % (
                 verdict, tot['p'], tot['n'], tot['f'], tot['i']))
    h.append('<table class="sum"><caption>Results by group</caption><thead>'
             '<tr><th>group</th><th>checks</th><th>pass</th><th>fail</th>'
             '<th>info</th><th>solver runs</th><th>time [s]</th></tr>'
             '</thead><tbody>')
    for gid in ORDER:
        if gid not in groups:
            continue
        g = groups[gid]
        h.append('<tr><td>%s</td><td>%d</td><td>%d</td><td>%d</td>'
                 '<td>%d</td><td>%d</td><td>%.0f</td></tr>' % (
                     esc(TITLES[gid]), g['_n'], g['_p'], g['_f'], g['_i'],
                     g['runs'], g['seconds']))
    h.append('<tr><td><b>total</b></td><td><b>%d</b></td><td><b>%d</b></td>'
             '<td><b>%d</b></td><td><b>%d</b></td><td><b>%d</b></td>'
             '<td><b>%.0f</b></td></tr></tbody></table>' % (
                 tot['n'], tot['p'], tot['f'], tot['i'], tot['runs'],
                 tot['sec']))
    h.append('<p>"Informative" rows are comparisons without a pass/fail '
             'threshold, mostly the cases in which the limitation of an '
             'element is documented in chapter 12 rather than hidden.</p>')
    # headline numbers
    h.append('<h3>Headline results</h3><ul>')
    for line in meta.get('headlines', []):
        h.append('<li>%s</li>' % line)
    h.append('</ul>')
    if reg:
        h.append('<h3>Regression suites of the repository</h3>'
                 '<table class="sum"><thead><tr><th>suite</th><th>result'
                 '</th><th>time [s]</th></tr></thead><tbody>')
        for name, res, sec in reg['rows']:
            h.append('<tr><td>%s</td><td>%s</td><td>%s</td></tr>' % (
                esc(name), esc(res), esc(sec)))
        h.append('</tbody></table>')
    # ------------------------------------------------------ 2 method
    h.append('<h2>2. Method</h2>')
    h.append("""
<p>Each group builds its models with a small generator (<code>vlib.py</code>)
that writes the standard input files, runs <code>MUL2_V3.exe</code> and reads
<code>POST_POINT.dat</code> and <code>FREQUENCIES.dat</code>. Nothing is read
from the code under test except its output files, so the campaign is a black
box validation of the solver and of the input chain.</p>
<h3>Reference solutions</h3>
<ul>
<li><b>Closed forms.</b> Euler-Bernoulli and Timoshenko cantilevers (Cowper
shear coefficient for rectangles, 5/6 for strips, the hollow-circle formula
for tubes), static tip deflection and the first four frequencies (the
frequency equation of the Timoshenko beam is integrated numerically with a
Runge-Kutta scheme and bisection); Navier double series for the simply
supported plate; the reduced plane-strain flexural rigidity of cross-ply
laminates; uniform-stress junction tests with exact solution 3&sigma;/E.</li>
<li><b>Exact fields (patch tests).</b> With &nu; = 0 the clamped bar under an
imposed tip elongation has the uniform solution u<sub>y</sub> = &delta;y/L,
which every element/expansion that contains the constant must reproduce to
machine precision; the cantilever under a tip moment has the quadratic
solution u<sub>z</sub> = My&sup2;/(2EI) which belongs to every quadratic
element.</li>
<li><b>Independent numerical models.</b> A 3D solid of H27 elements and a
Lagrange beam with a Q16 4x4 section solve the same square cantilever; they
agree to 0.004% (chapter 3). The plane-strain strip is solved by a 1x10x3 H27
mesh, used as reference for the plates.</li>
<li><b>Equivalences.</b> Different input routes or function spaces that must
give the same answer (HQ4 p=1 and Q4, HB p=1-3 and B2-B4, KINEMATICS.dat and
the NODES.dat tokens, three plies of one material and one ply, an isotropic
orthotropic material rotated by arbitrary angles, three independent regions
in one input and in three).</li>
</ul>
<h3>Common data</h3>
<p>Beam, strip and block: L = 10, section 1x1 (slender runs: h = 0.1),
E = 70 GPa, &nu; = 0.3 (0 in the exactness tests), &rho; = 2700 kg/m&sup3;,
B4 beam elements with MITC unless stated; tip load P = 10<sup>6</sup> N
applied as the consistent nodal load of a uniform traction; clamp at y = 0
(all three components on the plane, i.e. a 3D clamp, which stiffens the
structure by about 1.3% with respect to the beam theories because it
restrains the Poisson contraction at the root).</p>
<h3>Tolerances</h3>
<p>Exactness tests: 10<sup>-6</sup> relative (the observed errors are 10<sup>-9</sup> or
smaller). Comparisons with beam and plate theories: 2&ndash;4%, i.e. the
modelling error of the theory; comparisons between formulations of the same
physics: 0.5&ndash;1%; equivalences between identical function spaces:
10<sup>-9</sup>. A check marked FAIL is a defect either of the code or of the
claim being tested.</p>""")
    # -------------------------------------------------- chapters
    for ci, gid in enumerate(ORDER):
        if gid not in groups:
            continue
        g = groups[gid]
        num = ci + 3
        h.append('<h2>%d. %s</h2>' % (num, esc(TITLES[gid])))
        h.append('<p><b>Purpose.</b> %s</p>' % esc(WHAT[gid]))
        if g.get('intro'):
            h.append('<p><b>Models.</b> %s</p>' % esc(g['intro']))
        verdict = 'bad' if g['_f'] else 'ok'
        h.append('<p><span class="badge %s">%d checks: %d passed, %d failed, '
                 '%d informative &mdash; %d solver runs, %.0f s</span></p>' %
                 (verdict, g['_n'], g['_p'], g['_f'], g['_i'], g['runs'],
                  g['seconds']))
        for t in g['tables']:
            h.append(table_html(t))
        if g['series']:
            h.append('<div class="figs">')
            for s in g['series']:
                png = plot_png(s)
                h.append('<div class="fig"><img src="data:image/png;'
                         'base64,%s"/>%s</div>' % (
                             png, '<div class="note">%s</div>' %
                             esc(s['note']) if s.get('note') else ''))
            h.append('</div>')
        h.append(checks_html(g))
    # ------------------------------------- later features (ctest suites)
    n = len(ORDER) + 3
    if reg and reg.get('checks'):
        h.append('<h2>%d. Later features: checks of the regression suites'
                 '</h2>' % n)
        h.append('<p>Every feature added after the first release has its '
                 'own ctest suite. The tables list every check of the last '
                 'Release run, with the measured agreement.</p>')
        for suite in SUITE_ORDER:
            rows = reg['checks'].get(suite)
            if not rows:
                continue
            npass = sum(1 for r in rows if r[0] == 'PASS')
            h.append('<h3>%s</h3><p>%s &mdash; <span class="badge %s">%d of '
                     '%d checks passed</span></p>' % (
                         esc(suite), esc(SUITE_DESC.get(suite, '')),
                         'ok' if npass == len(rows) else 'bad', npass,
                         len(rows)))
            h.append('<table class="checks"><thead><tr><th>#</th><th>check'
                     '</th><th>measured</th><th>result</th></tr></thead>'
                     '<tbody>')
            for i, (st, name, det) in enumerate(rows):
                h.append('<tr class="%s"><td>%d</td><td>%s</td><td>%s</td>'
                         '<td class="st">%s</td></tr>' % (
                             'ok' if st == 'PASS' else 'bad', i + 1,
                             esc(name), esc(det), st))
            h.append('</tbody></table>')
        n += 1
    # ------------------------------------------------------ aircraft
    h.append('<h2>%d. Complete aircraft (analyses 103 and 101)</h2>' % n)
    h.append(AIRCRAFT)
    for fn, cap in (('aircraft_geometry.png', 'Nodes of the model'),
                    ('aircraft_mode_04.png', 'Mode 4, 0.89 Hz'),
                    ('aircraft_mode_06.png', 'Mode 6, 2.25 Hz')):
        p = os.path.join(ROOT, 'EXAMPLES', 'AIRCRAFT', 'RESULTS_FINE', fn)
        if os.path.exists(p):
            h.append('<div class="fig"><img src="data:image/png;base64,%s"/>'
                     '<div class="note">%s</div></div>' % (
                         base64.b64encode(open(p, 'rb').read()).decode(),
                         esc(cap)))
    n += 1
    # ---------------------------------------------------- findings
    h.append('<h2>%d. Findings and limitations</h2>' % n)
    h.append('<p>The campaign did not find an error in the numerical '
             'formulation of quadrilateral, hexahedral, hierarchical and '
             'Taylor elements. It found the following limitations, which '
             'are reported with the evidence in the chapters above.</p>')
    for kind, title, text in FINDINGS:
        h.append('<div class="callout %s"><b>%s</b><br>%s</div>' % (
            kind, esc(title), text))
    h.append('<h3>Not covered by this campaign</h3><ul>')
    for s in NOT_COVERED:
        h.append('<li>%s</li>' % esc(s))
    h.append('</ul>')
    # ------------------------------------------------- reproduce
    h.append('<h2>%d. Reproducing the campaign</h2>' % (n + 1))
    h.append("""<pre style="font-size:8.5pt;background:#f4f6f9;padding:6pt;">
cmake --build BUILD/WINDOWS_IFX --config Release
python TESTS/VALIDATION/run_all.py            # all groups (about 6 minutes)
python TESTS/VALIDATION/run_all.py hle ndk    # selected groups
python TESTS/VALIDATION/build_report.py       # this report
</pre>
<p>The models are written under the temporary folder
(<code>%TEMP%\\mul2_validation\\&lt;case&gt;</code>) with their inputs, console
logs and outputs; each case can be re-run by hand with
<code>MUL2_V3.exe INPUT</code> in that folder. Results are stored as JSON in
<code>TESTS/VALIDATION/results</code>.</p>""")
    h.append('</body></html>')
    os.makedirs(os.path.dirname(OUT_HTML), exist_ok=True)
    with open(OUT_HTML, 'w', encoding='utf-8') as f:
        f.write('\n'.join(h))
    print('html written', OUT_HTML, os.path.getsize(OUT_HTML) // 1024, 'KB')
    global OUT_PDF
    if os.path.exists(OUT_PDF):
        try:
            os.remove(OUT_PDF)
        except PermissionError:
            OUT_PDF = OUT_PDF[:-4] + '_new.pdf'
    url = 'file:///' + OUT_HTML.replace('\\', '/').replace(' ', '%20')
    subprocess.run([EDGE, '--headless=new', '--disable-gpu',
                    '--no-pdf-header-footer',
                    '--generate-pdf-document-outline',
                    '--virtual-time-budget=20000',
                    '--print-to-pdf=' + OUT_PDF, url],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=600)
    print('pdf', OUT_PDF, os.path.getsize(OUT_PDF) // 1024
          if os.path.exists(OUT_PDF) else 'NOT CREATED', 'KB')


if __name__ == '__main__':
    main()
