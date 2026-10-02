"""Parse the fixed-form Fortran sources and write the routine reference.

Outputs (next to the implementation book):
  implementation/app_reference.md  module-by-module reference
  build/deps.json                  directory-level dependency edges
"""
import json
import os
import re
import sys
from collections import OrderedDict, defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'SRC')
sys.path.insert(0, os.path.dirname(__file__))
import descriptions as D  # noqa: E402

LAYER_ORDER = ['BASE', 'MODEL', 'IO', 'QUADRATURE', 'FEM', 'GEOMETRY',
               'CUF', 'KINEMATICS', 'MATERIALS', 'GAUSS', 'ELEMENTS',
               'ASSEMBLY', 'BOUNDARY', 'SOLVERS', 'ANALYSES', 'POST',
               'APP']

LAYER_TEXT = {
    'BASE': 'Precision kinds, status/error handling, logging, timers, string and file utilities, sorting and searching.',
    'MODEL': 'Plain data types of the model: nodes, elements, kinematics, expansion meshes, materials, laminations, boundary conditions, analysis and post-processing requests.',
    'IO': 'Readers of the legacy input files and assembly of the complete model.',
    'QUADRATURE': 'Gauss–Legendre and triangle rules.',
    'FEM': 'Shape functions and natural derivatives of every topology.',
    'GEOMETRY': 'Element reference frames, Jacobians and local-frame gradients.',
    'CUF': 'Expansion bases (Taylor, Lagrange), point factors and the fundamental nucleus.',
    'KINEMATICS': 'Linear strain–displacement operator.',
    'MATERIALS': 'Constitutive matrices, rotations and lamination resolution.',
    'GAUSS': 'Reference rules, global Gauss-point layout, geometry and material caches.',
    'ELEMENTS': 'Element matrices (reference and separable kernels), MITC, dense products.',
    'ASSEMBLY': 'DOF numbering, CSR pattern and assembly, sparse operations.',
    'BOUNDARY': 'Constraints and loads.',
    'SOLVERS': 'PARDISO wrappers and the modal eigensolver (ARPACK / dense).',
    'ANALYSES': 'Model cache, parallel assembly, analyses 101 and 103, driver.',
    'POST': 'Point location and recovery, output grids, output files.',
    'APP': 'Program entry points.',
}


def read_logical_lines(path):
    """return list of (lineno, text, is_comment) with continuation merged."""
    out = []
    with open(path, encoding='utf-8', errors='replace') as f:
        raw = f.read().split('\n')
    for no, ln in enumerate(raw, 1):
        ln = ln.rstrip('\r')
        if not ln.strip():
            out.append((no, '', False))
            continue
        if ln[0] in 'cC*!' or ln.lstrip().startswith('!'):
            if ln.lstrip().startswith('!$'):
                continue
            out.append((no, ln.lstrip()[1:].rstrip(), True))
            continue
        cont = len(ln) > 5 and ln[5] not in ' 0'
        stmt = ln[6:] if len(ln) > 6 else ''
        # strip trailing comment (outside quotes)
        stmt = strip_comment(stmt)
        if cont and out and not out[-1][2]:
            n0, t0, _ = out[-1]
            out[-1] = (n0, t0 + ' ' + stmt.strip(), False)
        else:
            out.append((no, stmt.strip(), False))
    return out


def strip_comment(s):
    q = None
    for i, c in enumerate(s):
        if q:
            if c == q:
                q = None
        elif c in '\'"':
            q = c
        elif c == '!':
            return s[:i]
    return s


def split_args(s):
    depth = 0
    cur = ''
    out = []
    for c in s:
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        if c == ',' and depth == 0:
            out.append(cur.strip())
            cur = ''
        else:
            cur += c
    if cur.strip():
        out.append(cur.strip())
    return out


PROC_RE = re.compile(
    r'^((?:RECURSIVE|PURE|ELEMENTAL|MODULE)\s+)*'
    r'(?:(INTEGER\([A-Z0-9_]+\)|REAL\([A-Z0-9_]+\)|LOGICAL|'
    r'CHARACTER\(LEN=[^)]*\)|DOUBLE PRECISION|COMPLEX\([A-Z0-9_]+\))\s+)?'
    r'(SUBROUTINE|FUNCTION)\s+([A-Z0-9_]+)\s*(?:\((.*)\))?'
    r'(?:\s+RESULT\s*\(([A-Z0-9_]+)\))?\s*$', re.I)


def parse_file(path):
    lines = read_logical_lines(path)
    rel = os.path.relpath(path, SRC).replace('\\', '/')
    info = {'file': rel, 'dir': rel.split('/')[0], 'header': [],
            'module': None, 'uses': [], 'public': set(), 'procs': [],
            'types': [], 'params': []}
    # header comments before MODULE
    i = 0
    n = len(lines)
    hdr = []
    while i < n:
        no, t, is_c = lines[i]
        if is_c:
            if not set(t.strip()) <= {'=', '-'}:
                hdr.append(t.strip())
        elif t:
            break
        i += 1
    info['header'] = hdr
    pending = []
    in_type = None
    proc = None
    in_decl = False
    in_interface = False
    for i in range(n):
        no, t, is_c = lines[i]
        if is_c:
            if not set(t.strip()) <= {'=', '-'}:
                pending.append(t.strip())
            continue
        if not t:
            if proc is None and in_type is None:
                pass
            continue
        u = t.upper().strip()
        if u == 'INTERFACE':
            in_interface = True
            pending = []
            continue
        if u == 'END INTERFACE':
            in_interface = False
            proc = None
            pending = []
            continue
        m = re.match(r'MODULE\s+([A-Z0-9_]+)\s*$', u)
        if m and not u.startswith('MODULE PROCEDURE'):
            info['module'] = m.group(1)
            pending = []
            continue
        m = re.match(r'USE\s+([A-Z0-9_]+)', u)
        if m and proc is None:
            if m.group(1) not in info['uses'] and not m.group(1).startswith(
                    'OMP') and not m.group(1).startswith('IEEE') and \
                    not m.group(1).startswith('ISO_'):
                info['uses'].append(m.group(1))
            continue
        m = re.match(r'PUBLIC\s*::\s*(.*)', u)
        if m:
            for x in split_args(m.group(1)):
                info['public'].add(x.strip())
            pending = []
            continue
        if u == 'PRIVATE':
            pending = []
            continue
        m = re.match(r'END\s+TYPE', u)
        if m:
            in_type = None
            pending = []
            continue
        m = re.match(r'TYPE\s*(?:,\s*([A-Z, ]*?))?\s*::\s*([A-Z0-9_]+)\s*$', u)
        if m and proc is None:
            attrs = (m.group(1) or '')
            name = m.group(2)
            if 'PUBLIC' in attrs:
                info['public'].add(name)
            in_type = {'name': name, 'doc': ' '.join(pending),
                       'comps': []}
            info['types'].append(in_type)
            pending = []
            continue
        if in_type is not None:
            m = re.match(r'(.+?)\s*::\s*(.+)$', t)
            if m:
                typ = m.group(1).strip()
                rest = m.group(2).strip()
                nm = re.match(r'([A-Za-z0-9_]+)(\([^)]*\))?', rest)
                dflt = ''
                if '=' in rest:
                    dflt = rest.split('=', 1)[1].strip()
                if nm:
                    in_type['comps'].append(
                        (nm.group(1), typ.upper(),
                         (nm.group(2) or '').upper(), dflt,
                         ' '.join(pending)))
            pending = []
            continue
        m = re.match(r'(INTEGER\([A-Z0-9_]+\)|REAL\([A-Z0-9_]+\)|LOGICAL|'
                     r'CHARACTER\(LEN=[^)]*\))\s*,\s*PARAMETER\s*(?:,\s*'
                     r'PUBLIC\s*)?::\s*([A-Z0-9_]+)\s*=\s*(.*)$', u)
        if m and proc is None:
            ispub = 'PUBLIC' in u.split('::')[0]
            info['params'].append((m.group(2), m.group(1), m.group(3),
                                   ' '.join(pending), ispub))
            pending = []
            continue
        if re.match(r'(CONTAINS)\s*$', u):
            pending = []
            continue
        m = PROC_RE.match(u)
        if m and not re.match(r'END\s', u):
            kind = m.group(3)
            name = m.group(4)
            args = [a.strip() for a in split_args(m.group(5) or '')]
            ret = m.group(2) or ''
            proc = {'name': name, 'kind': kind.capitalize(), 'args': args,
                    'ret': ret, 'doc': ' '.join(pending), 'decl': {},
                    'line': no, 'result': m.group(6),
                    'prefix': (m.group(1) or '').strip(),
                    'external': in_interface}
            info['procs'].append(proc)
            pending = []
            in_decl = True
            continue
        if re.match(r'END\s+(SUBROUTINE|FUNCTION)', u):
            proc = None
            pending = []
            continue
        if proc is not None and in_decl:
            m = re.match(r'(.+?)\s*::\s*(.+)$', t)
            if m and re.match(r'(TYPE|INTEGER|REAL|LOGICAL|CHARACTER|'
                              r'DOUBLE|COMPLEX)', m.group(1).strip(),
                              re.I):
                spec = m.group(1).strip()
                names = split_args(m.group(2))
                for nm in names:
                    mm = re.match(r'([A-Za-z0-9_]+)\s*(\([^=]*\))?', nm)
                    if mm:
                        proc['decl'][mm.group(1).upper()] = (
                            spec.upper(), (mm.group(2) or '').upper(),
                            ' '.join(pending))
                pending = []
                continue
            if re.match(r'(IMPLICIT|USE|SAVE)', u):
                continue
            # first executable statement: stop collecting declarations
            in_decl = False
        pending = []
    return info


def clean_doc(s):
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'^[=\-]+', '', s).strip()
    return s[:1].upper() + s[1:].lower() if s.isupper() else s


def sentence_case(s):
    s = re.sub(r'\s+', ' ', s).strip()
    if not s:
        return ''
    if s == s.upper():
        s = s.lower()
        s = s[0].upper() + s[1:]
    return s


def md_escape(s):
    return s.replace('|', '\\|')


def describe_type(spec, dims):
    spec = spec.replace('INTENT(', 'intent(')
    return spec + dims


def const_doc(nm):
    if nm.startswith('TOPOLOGY_'):
        return 'Topology code ' + nm[9:] + '.'
    if nm.startswith('FIELD_'):
        return 'Field index of ' + nm[6:] + '.'
    if nm.startswith('EXPANSION_'):
        return 'Expansion family ' + nm[10:] + '.'
    if nm.startswith('SHEAR_'):
        return 'Shear-correction code ' + nm[6:] + '.'
    if nm.startswith('POST_FORMAT'):
        return 'Output format code.'
    if nm.startswith('POST_FRAME'):
        return 'Output frame code.'
    if nm.startswith('SOLUTION_'):
        return 'Analysis number.'
    if nm.startswith('STATUS_'):
        return 'Status code.'
    if nm.startswith('BC_'):
        return 'Boundary-condition kind.'
    if nm.startswith('MATERIAL_'):
        return 'Material model code.'
    if nm.startswith('MTYPE_'):
        return 'PARDISO matrix type.'
    if nm == 'N_FIELDS':
        return 'Number of fields of the unified formulation.'
    return ''


def proc_doc(p):
    d = sentence_case(p['doc'])
    if not d:
        d = D.PROC_DOC.get(p['name'], '')
    return d


def arg_doc(p, a, comment):
    if (p['name'], a.upper()) in D.ARG_PROC:
        return D.ARG_PROC[(p['name'], a.upper())]
    if comment:
        return sentence_case(comment)
    return D.ARG_DOC.get(a.upper(), '')


def build():
    infos = []
    for d in sorted(os.listdir(SRC)):
        dd = os.path.join(SRC, d)
        if not os.path.isdir(dd) or d == 'ARPACK':
            continue
        for fn in sorted(os.listdir(dd)):
            if fn.endswith('.for'):
                infos.append(parse_file(os.path.join(dd, fn)))
    mod2dir = {i['module']: i['dir'] for i in infos if i['module']}
    # dependency edges
    edges = defaultdict(set)
    for i in infos:
        for u in i['uses']:
            if u in mod2dir and mod2dir[u] != i['dir']:
                edges[i['dir']].add(mod2dir[u])
    os.makedirs(os.path.join(ROOT, 'DOC', 'BOOKS', 'build'), exist_ok=True)
    json.dump({k: sorted(v) for k, v in edges.items()},
              open(os.path.join(ROOT, 'DOC', 'BOOKS', 'build',
                                'deps.json'), 'w'), indent=1)
    json.dump({i['module']: {'dir': i['dir'], 'file': i['file'],
                             'uses': i['uses']} for i in infos if i['module']},
              open(os.path.join(ROOT, 'DOC', 'BOOKS', 'build',
                                'modules.json'), 'w'), indent=1)

    md = []
    md.append('# Source reference {#sec:reference}\n')
    md.append('This appendix is generated from the sources by '
              '`DOC/BOOKS/tools/refgen.py`; it lists, layer by layer, every '
              'module with its purpose, the modules it uses, its public '
              'derived types and constants, and its procedures with the '
              'meaning of the dummy arguments. Procedure descriptions are '
              'the comments written above each routine in the code.\n')
    nproc = sum(len(i['procs']) for i in infos)
    md.append('The code base has **%d modules** and **%d procedures** in %d '
              'source files (ARPACK excluded).\n' % (
                  len([i for i in infos if i['module']]), nproc,
                  len(infos)))
    for layer in LAYER_ORDER:
        group = [i for i in infos if i['dir'] == layer]
        if not group:
            continue
        md.append('## Layer %s {#sec:ref_%s}\n' % (layer, layer.lower()))
        md.append(LAYER_TEXT[layer] + '\n')
        for i in group:
            md.append('### %s\n' % i['module'])
            md.append('File `SRC/%s`.\n' % i['file'])
            hdr = sentence_case(' '.join(i['header']))
            if hdr:
                md.append(hdr + '\n')
            if i['uses']:
                md.append('Uses: ' + ', '.join('`%s`' % u for u in i['uses'])
                          + '.\n')
            pubparams = [p for p in i['params'] if p[4] or p[0] in i['public']]
            if pubparams:
                md.append('Table: Public constants of `%s`.\n' % i['module'])
                md.append('| Name | Type | Value | Meaning |')
                md.append('|---|---|---|---|')
                for nm, typ, val, doc, _ in pubparams:
                    md.append('| `%s` | `%s` | `%s` | %s |' % (
                        nm, typ, md_escape(val[:50]), md_escape(
                            sentence_case(doc) or const_doc(nm))))
                md.append('')
            for t in i['types']:
                md.append('Table: Derived type `%s` — %s\n' % (
                    t['name'], md_escape(sentence_case(t['doc']) or
                                         D.TYPE_DOC.get(t['name'], 'component list'))))
                md.append('| Component | Type | Shape | Default | Meaning |')
                md.append('|---|---|---|---|---|')
                for nm, typ, dims, dflt, doc in t['comps']:
                    md.append('| `%s` | `%s` | `%s` | `%s` | %s |' % (
                        nm, md_escape(typ), md_escape(dims),
                        md_escape(dflt), md_escape(
                            sentence_case(doc) or D.COMP_DOC.get(nm, ''))))
                md.append('')
            pubs = [p for p in i['procs'] if not p.get('external') and
                    p['name'] in i['public']]
            privs = [p for p in i['procs'] if p not in pubs]
            if i['procs']:
                md.append('Table: Procedures of `%s`.\n' % i['module'])
                md.append('| Procedure | Kind | Visibility | Purpose |')
                md.append('|---|---|---|---|')
                for p in i['procs']:
                    vis = 'external (MKL/ARPACK/LAPACK)' if p.get('external') else ('public' if p in pubs else 'private')
                    md.append('| `%s` | %s | %s | %s |' % (
                        p['name'], p['kind'] + ('' if not p['ret'] else
                                                ' → ' + p['ret'].lower()),
                        vis, md_escape(proc_doc(p))))
                md.append('')
            for p in pubs:
                if not p['args']:
                    continue
                md.append('#### `%s`\n' % p['name'])
                if proc_doc(p):
                    md.append(proc_doc(p) + '\n')
                md.append('| Argument | Declaration | Meaning |')
                md.append('|---|---|---|')
                for a in p['args']:
                    d = p['decl'].get(a.upper())
                    if d:
                        spec, dims, doc = d
                        md.append('| `%s` | `%s%s` | %s |' % (
                            a, md_escape(describe_type(spec, '')),
                            md_escape(dims), md_escape(
                                arg_doc(p, a, doc))))
                    else:
                        md.append('| `%s` | | %s |' % (a, md_escape(arg_doc(p, a, ''))))
                md.append('')
    open(os.path.join(ROOT, 'DOC', 'BOOKS', 'implementation',
                      'app_reference.md'), 'w', encoding='utf-8').write(
        '\n'.join(md))
    return infos


if __name__ == '__main__':
    infos = build()
    print('modules', len([i for i in infos if i['module']]), 'procs',
          sum(len(i['procs']) for i in infos))
