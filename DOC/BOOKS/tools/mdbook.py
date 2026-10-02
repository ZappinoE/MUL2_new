"""Minimal Markdown dialect -> single HTML book (math as MathML, SVG inline).

Dialect (see the sources in ../theory, ../implementation, ../user):
  # Chapter / ## Section / ### Subsection / #### unnumbered heading
  paragraphs, - bullets, 1. numbers (one nested level by 2 spaces),
  | tables | with header separator, optional  'Table: caption'  line before
  ```lang fenced code``` with optional first line  '#caption: text'
  $inline math$, $$display math$$ followed by  {#eq:name}  (numbered)
  ![caption](figures/file.svg){#fig:name}   (SVG is inlined)
  > NOTE: ... / > WARNING: ... / > TIP: ... / > EXAMPLE: ...  (callouts)
  {fig:name} {eq:name} {tab:name} {sec:name}  cross references
  \\pagebreak
"""
import os
import re
import html
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tex2mathml import tex_to_mathml  # noqa: E402


def slug(s):
    s = re.sub(r'<[^>]+>', '', s)
    s = re.sub(r'[^A-Za-z0-9]+', '-', s).strip('-').lower()
    return s or 'x'


class Book:
    def __init__(self, title, subtitle, author, version, base_dir,
                 figure_dir):
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.version = version
        self.base_dir = base_dir
        self.figure_dir = figure_dir
        self.labels = {}      # label -> (kind, text)
        self.toc = []         # (level, number, title, id)
        self.chapter = 0
        self.appendix = 0
        self.sec = 0
        self.sub = 0
        self.fig = 0
        self.eq = 0
        self.tab = 0
        self.out = []
        self.is_appendix = False
        self.pending_caption = None

    # ------------------------------------------------------------ inline
    def inline(self, text):
        keep = []

        def hold(h):
            keep.append(h)
            return '\x00%d\x00' % (len(keep) - 1)

        # code spans
        text = re.sub(r'`([^`]+)`',
                      lambda m: hold('<code>%s</code>' % html.escape(
                          m.group(1), quote=False)), text)
        # math
        text = re.sub(r'\$([^$\n]+)\$',
                      lambda m: hold(tex_to_mathml(m.group(1))), text)
        text = html.escape(text, quote=False)
        text = re.sub(r'\*\*([^*\n]+)\*\*', r'<strong>\1</strong>', text)
        text = re.sub(r'(?<![\w*])\*([^*\s][^*\n]*?)\*(?![\w*])',
                      r'<em>\1</em>', text)
        text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
                      r'<a href="\2">\1</a>', text)
        text = re.sub(r'\{(fig|eq|tab|sec):([A-Za-z0-9_\-]+)\}',
                      lambda m: self.ref(m.group(1), m.group(2)), text)
        text = text.replace('--', '–') if False else text
        text = re.sub(r'\x00(\d+)\x00', lambda m: keep[int(m.group(1))],
                      text)
        return text

    def ref(self, kind, name):
        key = '%s:%s' % (kind, name)
        if key in self.labels:
            lab, text = self.labels[key]
            return '<a class="ref" href="#%s">%s</a>' % (lab, text)
        return '<span class="missing">??%s??</span>' % key


    def expand_includes(self, text):
        """`@include path [max_lines] [caption]` -> fenced listing of a file
        (path relative to DOC/BOOKS)."""
        root = os.path.dirname(self.base_dir)
        out = []
        for ln in text.split('\n'):
            m = re.match(r'@include\s+(\S+)(?:\s+(\d+))?(?:\s+(.*))?$', ln)
            if not m:
                out.append(ln)
                continue
            path = os.path.join(root, m.group(1))
            if not os.path.exists(path):
                out.append('`missing include %s`' % m.group(1))
                continue
            data = open(path, encoding='utf-8', errors='replace').read().split('\n')
            while data and not data[-1].strip():
                data.pop()
            limit = int(m.group(2)) if m.group(2) else len(data)
            body = [l.rstrip() for l in data[:limit]]
            if len(data) > limit:
                body.append('...   (%d more lines)' % (len(data) - limit))
            cap = m.group(3) or os.path.basename(path)
            out.append('```text')
            out.append('#caption: ' + cap)
            out.extend(body)
            out.append('```')
        return '\n'.join(out)

    # ------------------------------------------------------------ pass 1
    def number_pass(self, files):
        """assign numbers to chapters, sections, figures, equations."""
        chapter = 0
        appendix = 0
        fig = eq = tab = 0
        sec = sub = 0
        for path in files:
            is_app = os.path.basename(path).startswith('app_')
            with open(path, encoding='utf-8') as f:
                lines = f.read().split('\n')
            in_code = False
            for i, ln in enumerate(lines):
                if ln.startswith('```'):
                    in_code = not in_code
                    continue
                if in_code:
                    continue
                m = re.match(r'(#{1,3}) (.*?)(?: \{#sec:([\w\-]+)\})?$', ln)
                if m:
                    lvl = len(m.group(1))
                    if lvl == 1:
                        if is_app:
                            appendix += 1
                            num = chr(64 + appendix)
                        else:
                            chapter += 1
                            num = str(chapter)
                        fig = eq = tab = 0
                        sec = sub = 0
                        cur = num
                    elif lvl == 2:
                        sec += 1
                        sub = 0
                        num = '%s.%d' % (cur, sec)
                    else:
                        sub += 1
                        num = '%s.%d.%d' % (cur, sec, sub)
                    if m.group(3):
                        self.labels['sec:' + m.group(3)] = (
                            'sec-' + slug(num), num)
                    continue
                m = re.search(r'\{#fig:([\w\-]+)\}', ln)
                if m and ln.startswith('!['):
                    fig += 1
                    self.labels['fig:' + m.group(1)] = (
                        'fig-' + m.group(1), 'Figure %s.%d' % (cur, fig))
                m = re.search(r'\{#eq:([\w\-]+)\}', ln)
                if m:
                    eq += 1
                    self.labels['eq:' + m.group(1)] = (
                        'eq-' + m.group(1), '(%s.%d)' % (cur, eq))
                m = re.match(r'Table: .*\{#tab:([\w\-]+)\}\s*$', ln)
                if m:
                    tab += 1
                    self.labels['tab:' + m.group(1)] = (
                        'tab-' + m.group(1), 'Table %s.%d' % (cur, tab))

    # ------------------------------------------------------------ pass 2
    def render_file(self, path):
        is_app = os.path.basename(path).startswith('app_')
        with open(path, encoding='utf-8') as f:
            text = f.read()
        text = self.expand_includes(text)
        lines = text.split('\n')
        i = 0
        n = len(lines)
        o = self.out
        while i < n:
            ln = lines[i]
            if not ln.strip():
                i += 1
                continue
            if ln.strip() == '\\pagebreak':
                o.append('<div class="pagebreak"></div>')
                i += 1
                continue
            # code fence
            if ln.startswith('```'):
                lang = ln[3:].strip()
                i += 1
                code = []
                while i < n and not lines[i].startswith('```'):
                    code.append(lines[i])
                    i += 1
                i += 1
                cap = ''
                if code and code[0].startswith('#caption:'):
                    cap = code.pop(0)[9:].strip()
                o.append('<figure class="listing">%s<pre class="code %s">'
                         '<code>%s</code></pre></figure>' % (
                             '<figcaption>%s</figcaption>' % self.inline(cap)
                             if cap else '', lang,
                             html.escape('\n'.join(code), quote=False)))
                continue
            # headings
            m = re.match(r'(#{1,4}) (.*?)(?: \{#sec:([\w\-]+)\})?$', ln)
            if m:
                self.heading(len(m.group(1)), m.group(2), is_app)
                i += 1
                continue
            # figure
            m = re.match(r'!\[(.*?)\]\((.*?)\)(?:\{#fig:([\w\-]+)\})?\s*$',
                         ln)
            if m:
                self.figure(m.group(1), m.group(2), m.group(3))
                i += 1
                continue
            # display math
            if ln.strip().startswith('$$'):
                s = ln.strip()[2:]
                label = None
                if '$$' in s:
                    idx = s.index('$$')
                    body = s[:idx]
                    tail = s[idx + 2:]
                    i += 1
                else:
                    parts = [s]
                    i += 1
                    while i < n and '$$' not in lines[i]:
                        parts.append(lines[i])
                        i += 1
                    last = lines[i] if i < n else ''
                    idx = last.find('$$')
                    parts.append(last[:idx])
                    tail = last[idx + 2:]
                    i += 1
                    body = '\n'.join(parts)
                m = re.search(r'\{#eq:([\w\-]+)\}', tail)
                if m:
                    label = m.group(1)
                self.display_math(body, label)
                continue
            # table
            if ln.startswith('|') or ln.startswith('Table:'):
                caption = None
                tlabel = None
                if ln.startswith('Table:'):
                    caption = ln[6:].strip()
                    m = re.search(r'\{#tab:([\w\-]+)\}\s*$', caption)
                    if m:
                        tlabel = m.group(1)
                        caption = caption[:m.start()].strip()
                    i += 1
                    while i < n and not lines[i].strip():
                        i += 1
                    if i >= n:
                        continue
                    ln = lines[i]
                rows = []
                while i < n and lines[i].startswith('|'):
                    rows.append(lines[i])
                    i += 1
                self.table(rows, caption, tlabel)
                continue
            # blockquote / callout
            if ln.startswith('>'):
                buf = []
                while i < n and lines[i].startswith('>'):
                    buf.append(lines[i][1:].strip())
                    i += 1
                self.callout(' '.join(buf))
                continue
            # lists
            if re.match(r'\s*([-*]|\d+\.) ', ln):
                i = self.list_block(lines, i)
                continue
            # raw html
            if ln.startswith('<'):
                o.append(ln)
                i += 1
                continue
            # paragraph
            buf = [ln]
            i += 1
            while i < n and lines[i].strip() and not re.match(
                    r'(#{1,4} |```|\||>|!\[|\$\$|Table:|\s*([-*]|\d+\.) )',
                    lines[i]):
                buf.append(lines[i])
                i += 1
            o.append('<p>%s</p>' % self.inline(' '.join(buf)))

    # ------------------------------------------------------------ blocks
    def heading(self, lvl, title, is_app):
        o = self.out
        if lvl == 1:
            if is_app:
                self.appendix += 1
                num = chr(64 + self.appendix)
                label = 'Appendix %s' % num
            else:
                self.chapter += 1
                num = str(self.chapter)
                label = 'Chapter %s' % num
            self.cur = num
            self.sec = self.sub = 0
            self.fig_n = self.eq_n = self.tab_n = 0
            hid = 'sec-' + slug(num)
            self.toc.append((1, num, title, hid))
            o.append('<h1 id="%s"><span class="chapno">%s</span>%s</h1>' % (
                hid, label, self.inline(title)))
        elif lvl == 2:
            self.sec += 1
            self.sub = 0
            num = '%s.%d' % (self.cur, self.sec)
            hid = 'sec-' + slug(num)
            self.toc.append((2, num, title, hid))
            o.append('<h2 id="%s"><span class="no">%s</span>%s</h2>' % (
                hid, num, self.inline(title)))
        elif lvl == 3:
            self.sub += 1
            num = '%s.%d.%d' % (self.cur, self.sec, self.sub)
            hid = 'sec-' + slug(num)
            o.append('<h3 id="%s"><span class="no">%s</span>%s</h3>' % (
                hid, num, self.inline(title)))
        else:
            o.append('<h4>%s</h4>' % self.inline(title))

    def figure(self, caption, src, label):
        self.fig_n += 1
        number = 'Figure %s.%d' % (self.cur, self.fig_n)
        path = os.path.join(self.base_dir, src)
        if not os.path.exists(path):
            path = os.path.join(self.figure_dir, os.path.basename(src))
        if os.path.exists(path):
            svg = open(path, encoding='utf-8').read()
            svg = re.sub(r'<\?xml.*?\?>', '', svg)
        else:
            svg = '<div class="missing">missing figure %s</div>' % src
        fid = ' id="fig-%s"' % label if label else ''
        self.out.append(
            '<figure class="fig"%s>%s<figcaption><b>%s.</b> %s'
            '</figcaption></figure>' % (fid, svg, number,
                                         self.inline(caption)))

    def display_math(self, tex, label):
        mm = tex_to_mathml(tex, display=True)
        if label:
            self.eq_n += 1
            num = '(%s.%d)' % (self.cur, self.eq_n)
            self.out.append(
                '<div class="eq" id="eq-%s"><div class="eqbody">%s</div>'
                '<div class="eqno">%s</div></div>' % (label, mm, num))
        else:
            self.out.append('<div class="eq"><div class="eqbody">%s</div>'
                            '<div class="eqno"></div></div>' % mm)

    def table(self, rows, caption, tlabel):
        cells = []
        for r in rows:
            r = r.strip()
            if r.startswith('|'):
                r = r[1:]
            if r.endswith('|'):
                r = r[:-1]
            # split on unescaped pipes (pipes inside `code` or $math$ are kept)
            r = re.sub(r'(`[^`]*`|\$[^$]*\$)',
                       lambda m: m.group(0).replace('|', '\x01'), r)
            parts = re.split(r'(?<!\\)\|', r)
            cells.append([p.strip().replace('\\|', '|').replace('\x01', '|')
                          for p in parts])
        header = cells[0]
        body = cells[1:]
        if body and all(re.fullmatch(r':?-{2,}:?', c.strip()) or not c
                        for c in body[0]):
            aligns = []
            for c in body[0]:
                c = c.strip()
                if c.startswith(':') and c.endswith(':'):
                    aligns.append('center')
                elif c.endswith(':'):
                    aligns.append('right')
                else:
                    aligns.append('left')
            body = body[1:]
        else:
            aligns = ['left'] * len(header)
        self.tab_n += 1
        number = 'Table %s.%d' % (self.cur, self.tab_n)
        tid = ' id="tab-%s"' % tlabel if tlabel else ''
        h = ['<table%s>' % tid]
        if caption is not None:
            h.append('<caption><b>%s.</b> %s</caption>' % (
                number, self.inline(caption)))
        h.append('<thead><tr>%s</tr></thead>' % ''.join(
            '<th style="text-align:%s">%s</th>' % (
                aligns[k] if k < len(aligns) else 'left', self.inline(c))
            for k, c in enumerate(header)))
        h.append('<tbody>')
        for r in body:
            h.append('<tr>%s</tr>' % ''.join(
                '<td style="text-align:%s">%s</td>' % (
                    aligns[k] if k < len(aligns) else 'left',
                    self.inline(c)) for k, c in enumerate(r)))
        h.append('</tbody></table>')
        self.out.append(''.join(h))

    def callout(self, text):
        m = re.match(r'(NOTE|WARNING|TIP|EXAMPLE|DEFINITION):\s*(.*)', text)
        kind = 'note'
        if m:
            kind = m.group(1).lower()
            text = m.group(2)
        title = {'note': 'Note', 'warning': 'Warning', 'tip': 'Tip',
                 'example': 'Example', 'definition': 'Definition'}[kind]
        self.out.append('<div class="callout %s"><div class="ctitle">%s'
                        '</div><div>%s</div></div>' % (
                            kind, title, self.inline(text)))

    def list_block(self, lines, i):
        n = len(lines)
        items = []   # (indent, ordered, text)
        while i < n:
            ln = lines[i]
            m = re.match(r'(\s*)([-*]|\d+\.) (.*)', ln)
            if m:
                items.append([len(m.group(1)), m.group(2)[0].isdigit(),
                              m.group(3)])
                i += 1
            elif ln.startswith('  ') and ln.strip() and items:
                items[-1][2] += ' ' + ln.strip()
                i += 1
            else:
                break

        def build(idx, indent):
            html_ = []
            ordered = items[idx][1]
            tag = 'ol' if ordered else 'ul'
            html_.append('<%s>' % tag)
            while idx < len(items) and items[idx][0] >= indent:
                if items[idx][0] > indent:
                    sub, idx = build(idx, items[idx][0])
                    html_[-1] = html_[-1].replace('</li>', '') + sub + '</li>'
                    continue
                html_.append('<li>%s</li>' % self.inline(items[idx][2]))
                idx += 1
            html_.append('</%s>' % tag)
            return ''.join(html_), idx

        idx = 0
        while idx < len(items):
            h, idx = build(idx, items[idx][0])
            self.out.append(h)
        return i

    # ------------------------------------------------------------ build
    def build(self, files, css, cover_extra=''):
        self.number_pass(files)
        self.out = []
        self.cur = '0'
        self.fig_n = self.eq_n = self.tab_n = 0
        for path in files:
            self.render_file(path)
        body = '\n'.join(self.out)
        toc = ['<div class="toc"><h1 class="toctitle">Contents</h1>']
        for lvl, num, title, hid in self.toc:
            toc.append('<div class="toc%d"><a href="#%s"><span class="tn">'
                       '%s</span>%s</a></div>' % (
                           lvl, hid, num, self.inline(title)))
        toc.append('</div>')
        cover = (
            '<div class="cover"><div class="covertop">MUL2_NEW</div>'
            '<h1 class="covertitle">%s</h1><div class="coversub">%s</div>'
            '<div class="coverinfo">%s<br/>Version %s</div>%s</div>' % (
                self.title, self.subtitle, self.author, self.version,
                cover_extra))
        return ('<!doctype html><html><head><meta charset="utf-8">'
                '<title>%s</title><style>%s</style></head><body>%s%s%s'
                '</body></html>' % (
                    html.escape(self.title), css, cover, '\n'.join(toc),
                    body))
