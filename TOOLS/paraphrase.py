"""Natural-language paraphrase of fixed-form Fortran statements.

    python TOOLS/paraphrase.py FILE [FILE ...]     annotate the files in place
    python TOOLS/paraphrase.py --dry FILE          print the notes, no change

For every statement (all of its continuation lines are read) a sentence is
produced and written after column 72 of the first line by annotate.py. The
code part of the file is never modified.
"""
import re
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import annotate as A          # noqa: E402

MAX_NOTE = 110

KIND_WORDS = {'I4': 'int32', 'I8': 'int64', 'R8': 'real64'}


# ---------------------------------------------------------------- helpers
def protect_strings(s):
    """Replace character literals by placeholders; returns (text, list)."""
    out, lits, i = [], [], 0
    while i < len(s):
        c = s[i]
        if c in '\'"':
            j = i + 1
            while j < len(s):
                if s[j] == c:
                    if j + 1 < len(s) and s[j + 1] == c:
                        j += 2
                        continue
                    break
                j += 1
            lits.append(s[i:j + 1])
            out.append('\x01%d\x02' % (len(lits) - 1))
            i = j + 1
        else:
            out.append(c)
            i += 1
    return ''.join(out), lits


def restore(s, lits):
    return re.sub(r'\x01(\d+)\x02', lambda m: lits[int(m.group(1))], s)


def split_top(s, sep=','):
    """Split at top-level separators (outside parentheses)."""
    parts, depth, cur = [], 0, []
    for c in s:
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        if c == sep and depth == 0:
            parts.append(''.join(cur).strip())
            cur = []
        else:
            cur.append(c)
    tail = ''.join(cur).strip()
    if tail or parts:
        parts.append(tail)
    return parts


def match_paren(s, start):
    """Index of the ')' closing the '(' at s[start]."""
    depth = 0
    for i in range(start, len(s)):
        if s[i] == '(':
            depth += 1
        elif s[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


OPERATORS = [
    (r'\.NOT\.', ' not '), (r'\.AND\.', ' and '), (r'\.OR\.', ' or '),
    (r'\.EQV\.', ' equals '), (r'\.NEQV\.', ' differs from '),
    (r'\.EQ\.', ' = '), (r'\.NE\.', ' /= '), (r'\.LT\.', ' < '),
    (r'\.GT\.', ' > '), (r'\.LE\.', ' <= '), (r'\.GE\.', ' >= '),
    (r'\.TRUE\.', 'true'), (r'\.FALSE\.', 'false'),
]


def human(expr, lits):
    """Readable form of a Fortran expression (lower case, no kinds)."""
    e = expr
    for pat, rep in OPERATORS:
        e = re.sub(pat, rep, e)
    e = re.sub(r'(?<=[0-9.])_(I4|I8|R8)\b', '', e)
    e = re.sub(r'\b(\d+)_(I4|I8)\b', r'\1', e)
    e = re.sub(r'(\d)_R8\b', r'\1', e)
    e = e.replace('%', '.')
    e = re.sub(r'\bSTATUS_IS_OK\((\w+)\)', r'\1 is ok', e)
    e = re.sub(r'\s+', ' ', e).strip()
    e = e.lower()
    e = restore(e, lits)
    return e


def words(name):
    return name.lower().replace('_', ' ')


def lower_first(t):
    return t[0].lower() + t[1:] if t else t


def is_zero(rhs):
    return re.fullmatch(r'0(_I[48])?|0\.0*(_R8)?|0\.0*[ED]0(_R8)?', rhs) \
        is not None


# ------------------------------------------------------------ declarations
TYPE_START = re.compile(
    r'^(INTEGER|REAL|LOGICAL|CHARACTER|COMPLEX|DOUBLE PRECISION'
    r'|TYPE\s*\(|CLASS\s*\()', re.I)


def paraphrase_declaration(s, lits):
    if '::' in s:
        head, names = s.split('::', 1)
    else:
        m = re.match(r'(INTEGER|REAL|LOGICAL|CHARACTER|COMPLEX)'
                     r'(\s*\([^)]*\))?\s*(.*)$', s, re.I)
        head, names = (m.group(1) + (m.group(2) or ''), m.group(3)) \
            if m else (s, '')
    parts = split_top(head)
    base = parts[0]
    attrs = [p.upper().replace(' ', '') for p in parts[1:]]
    tm = re.match(r'(INTEGER|REAL|LOGICAL|CHARACTER|COMPLEX|DOUBLE PRECISION'
                  r'|TYPE|CLASS)\s*(?:\((.*)\))?', base, re.I)
    kind = tm.group(1).lower() if tm else base.lower()
    arg = tm.group(2) if tm and tm.group(2) else ''
    if kind == 'type' or kind == 'class':
        tdesc = 'of type ' + arg.lower()
    elif kind == 'character':
        tdesc = 'character (%s)' % arg.lower().replace('len=', 'length ') \
            if arg else 'character'
    elif arg:
        a = arg.upper().replace('KIND=', '')
        tdesc = '%s (%s)' % (kind, KIND_WORDS.get(a, a.lower()))
    else:
        tdesc = kind
    role = []
    for a in attrs:
        if a == 'INTENT(IN)':
            role.append('input')
        elif a == 'INTENT(OUT)':
            role.append('output')
        elif a == 'INTENT(INOUT)':
            role.append('in/out')
        elif a == 'PARAMETER':
            role.append('constant')
        elif a == 'ALLOCATABLE':
            role.append('allocatable')
        elif a == 'OPTIONAL':
            role.append('optional')
        elif a == 'POINTER':
            role.append('pointer')
        elif a == 'SAVE':
            role.append('saved')
        elif a.startswith('DIMENSION'):
            role.append('array ' + a[9:].lower())
        elif a in ('PUBLIC', 'PRIVATE'):
            role.append(a.lower())
        elif a == 'TARGET':
            role.append('target')
        elif a == 'VALUE':
            role.append('by value')
    names = names.strip()
    decl = []
    for item in split_top(names):
        m = re.match(r'(\w+)\s*(\(.*?\))?\s*(=.*)?$', item)
        if m:
            nm = m.group(1).lower()
            if m.group(2):
                nm += m.group(2).lower().replace(' ', '')
            if m.group(3):
                nm += ' = ' + human(m.group(3)[1:].strip(), lits)
            decl.append(nm)
        else:
            decl.append(human(item, lits))
    prefix = ' '.join(role + [tdesc]) if role else tdesc
    prefix = prefix[0].upper() + prefix[1:]
    return '%s: %s.' % (prefix, ', '.join(decl))


# --------------------------------------------------------------- statements
def call_text(s, lits):
    m = re.match(r'CALL\s+([\w%]+)\s*(?:\((.*)\))?\s*$', s, re.I)
    if not m:
        return 'Call ' + human(s[4:], lits) + '.'
    name = m.group(1).upper()
    args = split_top(m.group(2)) if m.group(2) else []
    h = [human(a, lits) for a in args]
    if name == 'CLEAR_STATUS':
        return 'Reset the status to "ok".'
    if name == 'SET_ERROR' and len(h) >= 3:
        return 'Record an error in %s: %s' % (h[0], h[2]) + '.'
    if name == 'SET_WARNING' and len(h) >= 3:
        return 'Record a warning in %s: %s' % (h[0], h[2]) + '.'
    if name == 'MERGE_STATUS' and len(h) == 2:
        return 'Merge status %s into %s.' % (h[0], h[1])
    if name == 'LOG_MESSAGE' and h:
        return 'Write to the log: %s.' % h[-1]
    if name == 'LOG_INFO' and h:
        return 'Log: %s.' % h[-1]
    if name in ('MOVE_ALLOC',) and len(h) == 2:
        return 'Move the allocation of %s into %s.' % (h[0], h[1])
    if name == 'OMP_SET_NUM_THREADS':
        return 'Set the number of OpenMP threads to %s.' % h[0]
    if name == 'CPU_TIME':
        return 'Read the CPU clock into %s.' % h[0]
    if name == 'SYSTEM_CLOCK':
        return 'Read the system clock into %s.' % h[0]
    out = 'Call %s' % words(name)
    if h:
        shown = ', '.join(h)
        out += ' with ' + shown
    return out + '.'


def io_text(kind, s, lits):
    m = re.match(kind + r'\s*\((.*)$', s, re.I)
    if not m:
        return kind.title() + '.'
    body = m.group(1)
    close = match_paren('(' + body, 0)
    ctrl = body[:close - 1] if close > 0 else body
    rest = body[close:].strip() if close > 0 else ''
    ctrl_parts = split_top(ctrl)
    unit = ctrl_parts[0] if ctrl_parts else ''
    items = [human(p, lits) for p in split_top(rest)] if rest else []
    unit_h = human(unit, lits)
    if kind.upper() == 'WRITE':
        if unit == '*' or unit == '6':
            what = 'Print'
        elif re.fullmatch(r'(MESSAGE|LINE|TEXT|BUFFER|FIELD|NUMBER|LABEL'
                          r'|TEMP|TEXT_LINE|PART|WORD)\w*', unit.upper()):
            what = 'Format into the text %s' % unit_h
        else:
            what = 'Write to unit %s' % unit_h
        if items:
            shown = ', '.join(items)
            return '%s: %s.' % (what, shown)
        return what + '.'
    if items:
        return 'Read from %s into %s.' % (
            'the text ' + unit_h if unit.upper() in ('LINE', 'MESSAGE',
                                                     'TEXT') else
            'unit ' + unit_h, ', '.join(items))
    return 'Read a record from unit %s.' % unit_h


def assign_text(lhs, rhs, lits):
    L = human(lhs, lits)
    R = human(rhs, lits)
    if is_zero(rhs.strip()):
        return 'Set %s to zero.' % L
    if rhs.strip().upper() == '.TRUE.':
        return 'Set the flag %s to true.' % L
    if rhs.strip().upper() == '.FALSE.':
        return 'Set the flag %s to false.' % L
    m = re.match(r'^%s\s*([+\-*/])\s*(.+)$' % re.escape(lhs.strip()),
                 rhs.strip(), re.I)
    if m:
        op, tail = m.group(1), human(m.group(2), lits)
        if op == '+':
            return 'Add %s to %s.' % (tail, L)
        if op == '-':
            return 'Subtract %s from %s.' % (tail, L)
        if op == '*':
            return 'Multiply %s by %s.' % (L, tail)
        return 'Divide %s by %s.' % (L, tail)
    m = re.match(r'^(MAX|MIN)\s*\((.*)\)\s*$', rhs.strip(), re.I)
    if m and len(split_top(m.group(2))) == 2:
        a, b = [human(x, lits) for x in split_top(m.group(2))]
        return 'Set %s to the %s of %s and %s.' % (
            L, 'larger' if m.group(1).upper() == 'MAX' else 'smaller', a, b)
    m = re.match(r'^SQRT\s*\((.*)\)\s*$', rhs.strip(), re.I)
    if m:
        return 'Set %s to the square root of %s.' % (L, human(m.group(1),
                                                              lits))
    m = re.match(r'^(SUM|MAXVAL|MINVAL|SIZE|COUNT|ABS|ANY|ALL)\s*\((.*)\)\s*$',
                 rhs.strip(), re.I)
    if m and len(split_top(m.group(2))) == 1:
        word = {'SUM': 'the sum of', 'MAXVAL': 'the maximum of',
                'MINVAL': 'the minimum of', 'SIZE': 'the size of',
                'COUNT': 'the number of true entries of',
                'ABS': 'the absolute value of', 'ANY': 'whether any of',
                'ALL': 'whether all of'}[m.group(1).upper()]
        return 'Set %s to %s %s.' % (L, word, human(m.group(2), lits))
    m = re.match(r'^MERGE\s*\((.*)\)\s*$', rhs.strip(), re.I)
    if m and len(split_top(m.group(1))) == 3:
        a, b, c = [human(x, lits) for x in split_top(m.group(1))]
        return 'Set %s to %s if %s, otherwise %s.' % (L, a, c, b)
    return 'Set %s to %s.' % (L, R)


def paraphrase(stmt):
    """Sentence for one complete (continuations joined) statement."""
    s = re.sub(r'\s+', ' ', stmt).strip()
    s = re.sub(r'^\d+\s+', '', s)
    p, lits = protect_strings(s)
    u = p.upper()

    # ---- block ends
    m = re.match(r'END\s*(IF|DO|SELECT|WHERE|ASSOCIATE|BLOCK|INTERFACE|TYPE'
                 r'|MODULE|SUBROUTINE|FUNCTION|PROGRAM)?\s*(\w+)?\s*$', u)
    if m:
        what, nm = m.group(1), (m.group(2) or '')
        if what == 'IF':
            return 'End of the IF block.'
        if what == 'DO':
            return 'End of the loop.'
        if what == 'SELECT':
            return 'End of the case selection.'
        if what == 'WHERE':
            return 'End of the masked assignment.'
        if what == 'ASSOCIATE':
            return 'End of the shorthand names.'
        if what == 'TYPE':
            return 'End of the type definition %s.' % words(nm)
        if what in ('MODULE', 'SUBROUTINE', 'FUNCTION', 'PROGRAM'):
            return 'End of the %s %s.' % (what.lower(), words(nm))
        return 'End of the block.'

    # ---- structure
    if u == 'CONTAINS':
        return 'The procedures of the module follow.'
    if u == 'IMPLICIT NONE':
        return 'Every variable must be declared explicitly.'
    if u == 'PRIVATE':
        return 'Everything in the module is private unless exported.'
    if u == 'PUBLIC':
        return 'Everything in the module is exported.'
    m = re.match(r'(PUBLIC|PRIVATE)\s*::\s*(.*)$', u)
    if m:
        return '%s: %s.' % ('Export' if m.group(1) == 'PUBLIC' else 'Hide',
                            ', '.join(words(x) for x in split_top(
                                m.group(2))))
    m = re.match(r'USE\s*(?:,\s*INTRINSIC\s*::)?\s*(\w+)\s*(?:,\s*ONLY\s*:'
                 r'\s*(.*))?$', u)
    if m:
        if m.group(2):
            return 'Use from module %s: %s.' % (
                words(m.group(1)),
                ', '.join(words(x) for x in split_top(m.group(2))))
        return 'Use everything exported by module %s.' % words(m.group(1))
    m = re.match(r'IMPORT\s*(?:::)?\s*(.*)$', u)
    if m:
        return 'Import from the host: %s.' % ', '.join(
            words(x) for x in split_top(m.group(1)))
    m = re.match(r'MODULE\s+(\w+)\s*$', u)
    if m:
        return 'Module %s begins.' % words(m.group(1))
    m = re.match(r'PROGRAM\s+(\w+)', u)
    if m:
        return 'Main program %s begins.' % words(m.group(1))
    m = re.match(r'(?:(?:RECURSIVE|PURE|ELEMENTAL|IMPURE)\s+)*'
                 r'(?:(?:INTEGER|REAL|LOGICAL|CHARACTER|COMPLEX|'
                 r'DOUBLE PRECISION)\s*(?:\([^)]*\))?\s+)?'
                 r'(SUBROUTINE|FUNCTION)\s+(\w+)\s*(?:\((.*?)\))?'
                 r'(?:\s*RESULT\s*\((\w+)\))?\s*$', u)
    if m:
        kind, nm, args, res = m.groups()
        text = '%s %s' % ('Subroutine' if kind == 'SUBROUTINE' else
                          'Function', words(nm))
        if args and args.strip():
            text += ' takes ' + ', '.join(words(a) for a in split_top(args))
        if res:
            text += ' and returns %s' % words(res)
        return text + '.'
    m = re.match(r'TYPE\s*(?:,\s*[\w()=]+\s*)*(?:::)?\s*(\w+)\s*$', u)
    if m and not u.startswith('TYPE('):
        return 'Definition of the derived type %s.' % words(m.group(1))
    if re.match(r'INTERFACE\b', u):
        return 'Declare a generic interface.'
    m = re.match(r'EXTERNAL\s*(?:::)?\s*(.*)$', u)
    if m:
        return 'External procedures: %s.' % words(m.group(1))

    # ---- declarations
    if TYPE_START.match(u) and ('::' in u or re.match(
            r'(INTEGER|REAL|LOGICAL|CHARACTER|COMPLEX)\b', u)):
        if not re.match(r'(REAL|INTEGER|LOGICAL|CHARACTER|COMPLEX)\s*\(.*\)'
                        r'\s*FUNCTION', u):
            return paraphrase_declaration(p, lits)

    # ---- control flow
    m = re.match(r'ELSE\s*IF\s*\((.*)\)\s*THEN\s*$', u)
    if m:
        i0 = p.upper().index('(')
        cond = p[i0 + 1:match_paren(p, i0)]
        return 'Otherwise, if %s:' % human(cond, lits)
    if u == 'ELSE':
        return 'Otherwise:'
    m = re.match(r'IF\s*\(', u)
    if m:
        i0 = u.index('(')
        j = match_paren(p, i0)
        cond = human(p[i0 + 1:j], lits)
        rest = p[j + 1:].strip()
        if rest.upper() == 'THEN':
            return 'If %s:' % cond
        if rest.startswith(('1', '2', '3')) or not rest:
            return 'Arithmetic IF on %s.' % cond
        inner = paraphrase(restore(rest, lits)).rstrip('.')
        return 'If %s, %s.' % (cond, lower_first(inner))
    m = re.match(r'DO\s+WHILE\s*\(', u)
    if m:
        i0 = u.index('(')
        j = match_paren(p, i0)
        return 'Repeat while %s:' % human(p[i0 + 1:j], lits)
    m = re.match(r'DO\s+CONCURRENT\s*\((.*)\)', u)
    if m:
        return 'Independent iterations over %s:' % human(m.group(1), lits)
    m = re.match(r'DO\s+(?:\d+\s+)?(\w+)\s*=\s*(.*)$', u)
    if m:
        rng = split_top(m.group(2))
        v = m.group(1).lower()
        # recompute on the protected, case-preserved text
        rng = split_top(p[p.index('=') + 1:])
        rng = [human(x, lits) for x in rng]
        if len(rng) == 3:
            return 'Loop %s from %s to %s in steps of %s:' % (
                v, rng[0], rng[1], rng[2])
        if len(rng) == 2:
            return 'Loop %s from %s to %s:' % (v, rng[0], rng[1])
    if u == 'DO':
        return 'Loop until an EXIT statement is reached:'
    m = re.match(r'SELECT\s*CASE\s*\((.*)\)\s*$', u)
    if m:
        i0 = u.index('(')
        return 'Choose according to the value of %s:' % human(
            p[i0 + 1:match_paren(p, i0)], lits)
    if u == 'CASE DEFAULT':
        return 'In every other case:'
    m = re.match(r'CASE\s*\((.*)\)\s*$', u)
    if m:
        i0 = u.index('(')
        return 'Case %s:' % human(p[i0 + 1:match_paren(p, i0)], lits)
    if u == 'RETURN':
        return 'Return to the caller.'
    if u == 'EXIT':
        return 'Leave the loop.'
    if u == 'CYCLE':
        return 'Skip to the next iteration.'
    m = re.match(r'(?:EXIT|CYCLE)\s+(\w+)', u)
    if m:
        return '%s the loop %s.' % ('Leave' if u.startswith('EXIT')
                                    else 'Continue', m.group(1).lower())
    if re.match(r'STOP\b', u):
        return 'Stop the program.'
    if u.startswith('ERROR STOP'):
        return 'Stop the program with an error.'
    if u == 'CONTINUE':
        return 'No operation (loop terminator).'
    m = re.match(r'GO\s*TO\s+(\d+)', u)
    if m:
        return 'Jump to label %s.' % m.group(1)
    m = re.match(r'ASSOCIATE\s*\((.*)\)\s*$', u)
    if m:
        i0 = u.index('(')
        names = [x.split('=>')[0].strip().lower() for x in split_top(
            p[i0 + 1:match_paren(p, i0)])]
        return 'Use short names (%s) for longer expressions:' % ', '.join(
            names)
    m = re.match(r'WHERE\s*\(', u)
    if m:
        i0 = u.index('(')
        j = match_paren(p, i0)
        cond = human(p[i0 + 1:j], lits)
        rest = p[j + 1:].strip()
        if not rest:
            return 'For the elements where %s:' % cond
        mm = re.match(r'(.+?)\s*=\s*(.*)$', rest)
        if mm:
            return 'Where %s: %s' % (cond, lower_first(
                assign_text(mm.group(1), mm.group(2), lits)))
    if u == 'ELSEWHERE':
        return 'For the remaining elements:'

    # ---- calls and memory
    if u.startswith('CALL '):
        return call_text(p, lits)
    m = re.match(r'ALLOCATE\s*\((.*)\)\s*$', u)
    if m:
        i0 = u.index('(')
        items = split_top(p[i0 + 1:match_paren(p, i0)])
        items = [x for x in items if not re.match(r'(STAT|SOURCE|ERRMSG)\s*=',
                                                  x, re.I)]
        return 'Allocate memory for %s.' % ', '.join(
            human(x, lits) for x in items)
    m = re.match(r'DEALLOCATE\s*\((.*)\)\s*$', u)
    if m:
        i0 = u.index('(')
        items = split_top(p[i0 + 1:match_paren(p, i0)])
        return 'Free the memory of %s.' % ', '.join(
            human(x, lits) for x in items)
    if u.startswith('WRITE'):
        return io_text('WRITE', p, lits)
    if u.startswith('PRINT'):
        return 'Print: %s.' % human(p[5:].lstrip('*, '), lits)
    if re.match(r'READ\s*\(', u):
        return io_text('READ', p, lits)
    if re.match(r'OPEN\s*\(', u):
        m = re.search(r"FILE\s*=\s*([^,)]+)", p, re.I)
        return 'Open the file %s.' % (human(m.group(1), lits) if m
                                       else 'given by the arguments')
    if re.match(r'CLOSE\s*\(', u):
        return 'Close the file.'
    m = re.match(r'INQUIRE\s*\(', u)
    if m:
        mm = re.search(r'(EXIST|OPENED)\s*=\s*([\w%]+)', p, re.I)
        return 'Ask the file system%s.' % (
            ' whether the file exists, result in ' + human(mm.group(2), lits)
            if mm else '')
    m = re.match(r'(\w+)\s*:\s*BLOCK\s*$', u)
    if m:
        return 'Block %s with its own local variables begins:' % words(
            m.group(1))
    if re.match(r'REWIND|BACKSPACE|FLUSH', u):
        return 'Reposition or flush the file.'
    if re.match(r'(NAMELIST|DATA|COMMON|EQUIVALENCE|SAVE|FORMAT)\b', u):
        return 'Declaration: %s.' % human(p, lits)

    # ---- assignment (last)
    m = re.match(r'([A-Za-z_][\w%]*(?:\s*\(.*?\))?(?:%[\w%]*(?:\(.*?\))?)*)'
                 r'\s*(?:=>|=)\s*(.*)$', p)
    if m:
        eq = p.index('=', len(m.group(1)) - 1 if False else 0)
        # split at the first top-level '=' that is not part of '=='
        depth = 0
        for i, c in enumerate(p):
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            elif c == '=' and depth == 0:
                eq = i
                break
        lhs = p[:eq].rstrip('>').strip()
        rhs = p[eq + 1:].lstrip('>').strip()
        if p[eq - 1:eq + 1] == '=>':
            return 'Point %s at %s.' % (human(lhs.rstrip('='), lits),
                                        human(rhs, lits))
        return assign_text(lhs, rhs, lits)
    return 'Statement: %s.' % human(p, lits)


# --------------------------------------------------------------- file level
def statements(lines):
    """Yield (first_line_number, joined_text) for every statement."""
    i, n = 0, len(lines)
    while i < n:
        ln = lines[i]
        if A.is_statement_start(ln):
            code, _ = A.split_note(ln)
            parts = [code[6:] if len(code) > 6 else '']
            j = i + 1
            while j < n and lines[j] and not A.is_comment_line(lines[j]) \
                    and len(lines[j]) > 5 and lines[j][5] not in ' 0':
                c2, _ = A.split_note(lines[j])
                parts.append(c2[6:])
                j += 1
            # blank/comment lines between continuations are tolerated
            yield i + 1, ' '.join(x.strip() for x in parts)
            i = j
        else:
            i += 1


def clip(text):
    return text if len(text) <= MAX_NOTE else text[:MAX_NOTE - 3] + '...'


def build_notes(path):
    lines, _ = A.read_lines(path)
    notes = {}
    for number, stmt in statements(lines):
        notes[number] = clip(paraphrase(stmt))
    return notes


def annotate_file(path, dry=False):
    lines, nl = A.read_lines(path)
    notes = build_notes(path)
    if dry:
        for k in sorted(notes):
            print('%5d  %s' % (k, lines[k - 1][:60].strip()))
            print('       -> ' + notes[k])
        return
    for number, text in notes.items():
        code, _ = A.split_note(lines[number - 1])
        if len(code) > 72:
            continue
        lines[number - 1] = code.ljust(A.NOTE_COLUMN) + '! ' + text
    A.write_lines(path, lines, nl)
    print('%s: %d notes' % (path, len(notes)))


if __name__ == '__main__':
    args = sys.argv[1:]
    dry = False
    if args and args[0] == '--dry':
        dry = True
        args = args[1:]
    for f in args:
        annotate_file(f, dry)

