"""Margin comments for the fixed-form sources.

The code of a fixed-form line ends at column 72; whatever follows is ignored
by the compiler. This tool appends a natural-language paraphrase of a
statement after column 72 ('!' in column 74), so that the source can be read
as prose without touching the code.

    python TOOLS/annotate.py list FILE            statements without a note
    python TOOLS/annotate.py apply FILE NOTES.py  NOTES.py defines NOTES =
                                                  {line_number: 'text'}
    python TOOLS/annotate.py strip FILE           remove all margin notes

Only the first line of a statement (not a continuation line, not a comment
line) accepts a note; a note on any other line is an error. Existing notes
are replaced. The code part is never modified (checked byte by byte).
"""
import io
import re
import sys

NOTE_COLUMN = 73          # 0-based index of the '!' (column 74)


def is_comment_line(line):
    s = line.rstrip('\r\n')
    if not s.strip():
        return True
    c = s[0]
    if c in 'Cc*!' and (c != 'C' and c != 'c' or True):
        return True
    return s.lstrip().startswith('!')


def split_note(line):
    """(code, note) of a physical line; the note starts after column 72."""
    s = line.rstrip('\r\n')
    code = s[:72].rstrip()
    rest = s[72:].strip()
    if rest.startswith('!'):
        return code, rest[1:].strip()
    return s.rstrip(), ''


def is_statement_start(line):
    s = line.rstrip('\r\n')
    if is_comment_line(s):
        return False
    if len(s) > 5 and s[5] not in ' 0':
        return False           # continuation line
    return True


def read_lines(path):
    with io.open(path, encoding='utf-8', newline='') as f:
        text = f.read()
    nl = '\r\n' if '\r\n' in text else '\n'
    return text.replace('\r\n', '\n').split('\n'), nl


def write_lines(path, lines, nl):
    with io.open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(nl.join(lines))


def cmd_list(path):
    lines, _ = read_lines(path)
    for i, ln in enumerate(lines, 1):
        if is_statement_start(ln):
            code, note = split_note(ln)
            if not note:
                print('%5d  %s' % (i, code.strip()))


def cmd_apply(path, notes_path):
    ns = {}
    exec(open(notes_path, encoding='utf-8').read(), ns)
    notes = ns['NOTES']
    lines, nl = read_lines(path)
    errors = []
    for number, text in sorted(notes.items()):
        if number < 1 or number > len(lines):
            errors.append('line %d out of range' % number)
            continue
        ln = lines[number - 1]
        if not is_statement_start(ln):
            errors.append('line %d is not the first line of a statement: '
                          '%s' % (number, ln.strip()[:50]))
            continue
        code, _ = split_note(ln)
        if len(code) > 72:
            errors.append('line %d is longer than 72 columns' % number)
            continue
        text = ' '.join(text.split())
        lines[number - 1] = code.ljust(NOTE_COLUMN) + '! ' + text
    if errors:
        print('\n'.join(errors))
        sys.exit(1)
    write_lines(path, lines, nl)
    print('%s: %d notes' % (path, len(notes)))


def cmd_strip(path):
    lines, nl = read_lines(path)
    out = []
    for ln in lines:
        if is_statement_start(ln) or ln[72:].lstrip().startswith('!'):
            code, _ = split_note(ln)
            out.append(code)
        else:
            out.append(ln)
    write_lines(path, out, nl)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    {'list': lambda: cmd_list(sys.argv[2]),
     'apply': lambda: cmd_apply(sys.argv[2], sys.argv[3]),
     'strip': lambda: cmd_strip(sys.argv[2])}[sys.argv[1]]()
