"""Small LaTeX-subset to MathML converter (no dependencies).

Supported: letters/digits/operators, ^ _, \\frac, \\sqrt, \\sum \\int \\prod
with limits, Greek letters, \\mathbf \\boldsymbol \\mathrm \\mathcal \\text,
\\left \\right, bmatrix/pmatrix/matrix/cases/aligned, accents (\\hat \\tilde
\\bar \\dot \\vec), common operators and arrows.
MathML is rendered natively by Chromium/Edge (used to print the PDFs).
"""
import re

GREEK = {
    'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε',
    'varepsilon': 'ϵ', 'zeta': 'ζ', 'eta': 'η', 'theta': 'θ', 'vartheta': 'ϑ',
    'iota': 'ι', 'kappa': 'κ', 'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ',
    'pi': 'π', 'rho': 'ρ', 'sigma': 'σ', 'tau': 'τ', 'upsilon': 'υ',
    'phi': 'ϕ', 'varphi': 'φ', 'chi': 'χ', 'psi': 'ψ', 'omega': 'ω',
    'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ', 'Lambda': 'Λ', 'Xi': 'Ξ',
    'Pi': 'Π', 'Sigma': 'Σ', 'Phi': 'Φ', 'Psi': 'Ψ', 'Omega': 'Ω',
}
OPS = {
    'cdot': '⋅', 'times': '×', 'approx': '≈', 'le': '≤', 'leq': '≤',
    'ge': '≥', 'geq': '≥', 'ne': '≠', 'neq': '≠', 'in': '∈', 'notin': '∉',
    'rightarrow': '→', 'to': '→', 'Rightarrow': '⇒', 'Leftrightarrow': '⇔',
    'leftarrow': '←', 'forall': '∀', 'exists': '∃', 'partial': '∂',
    'nabla': '∇', 'infty': '∞', 'pm': '±', 'mp': '∓', 'otimes': '⊗',
    'oplus': '⊕', 'equiv': '≡', 'sim': '∼', 'propto': '∝', 'subset': '⊂',
    'cup': '∪', 'cap': '∩', 'circ': '∘', 'ldots': '…', 'cdots': '⋯',
    'dots': '…', 'perp': '⊥', 'parallel': '∥', 'langle': '⟨',
    'rangle': '⟩', 'prime': '′', 'mapsto': '↦', 'll': '≪', 'gg': '≫',
    'setminus': '∖', 'Longleftrightarrow': '⟺', 'iff': '⟺', 'Longrightarrow': '⟹', 'emptyset': '∅', 'sum': '∑', 'int': '∫', 'prod': '∏',
    'oint': '∮', 'star': '⋆', 'bullet': '•', 'lVert': '‖', 'rVert': '‖',
}
SPACES = {',': '0.17em', ';': '0.28em', ':': '0.22em', '!': '-0.17em',
          'quad': '1em', 'qquad': '2em', ' ': '0.28em'}
FUNCS = {'sin', 'cos', 'tan', 'exp', 'log', 'ln', 'det', 'max', 'min',
         'sup', 'inf', 'lim', 'arg', 'dim', 'tr', 'diag', 'sgn', 'cosh',
         'sinh', 'tanh', 'atan', 'acos', 'asin'}
ACCENTS = {'hat': '^', 'tilde': '~', 'bar': '¯', 'dot': '˙', 'vec': '→',
           'ddot': '¨', 'overline': '¯'}
BIG = {'sum', 'prod', 'int', 'oint'}
UNKNOWN = set()
SIZERS = {'big', 'Big', 'bigg', 'Bigg', 'bigl', 'bigr', 'Bigl', 'Bigr',
          'biggl', 'biggr', 'Biggl', 'Biggr'}


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


class Parser:
    def __init__(self, s):
        self.s = s
        self.i = 0

    # ---------------------------------------------------------------
    def eof(self):
        return self.i >= len(self.s)

    def peek(self):
        return self.s[self.i] if not self.eof() else ''

    def skip_ws(self):
        while not self.eof() and self.s[self.i] in ' \t\r\n':
            self.i += 1

    def command(self):
        """read a backslash command name (after the backslash)"""
        m = re.match(r'[A-Za-z]+', self.s[self.i:])
        if m:
            self.i += m.end()
            return m.group(0)
        c = self.s[self.i]
        self.i += 1
        return c

    # ---------------------------------------------------------------
    def parse_row(self, stop=None):
        """parse until a stop token ('}' or '\\right' or '&' or '\\\\'...)"""
        items = []
        while True:
            self.skip_ws()
            if self.eof():
                break
            c = self.peek()
            if c == '}':
                break
            if c == '&':
                break
            if c == '\\':
                if self.s.startswith('\\\\', self.i):
                    break
                j = self.i
                self.i += 1
                name = self.command()
                self.i = j
                if name in ('right', 'end'):
                    break
            atom = self.parse_atom()
            if atom is None:
                continue
            atom = self.scripts(atom)
            items.append(atom)
        return items

    def scripts(self, base):
        sub = sup = None
        while True:
            self.skip_ws()
            c = self.peek()
            if c == '_':
                self.i += 1
                sub = self.parse_script_arg()
            elif c == '^':
                self.i += 1
                sup = self.parse_script_arg()
            elif c == "'":
                self.i += 1
                sup = '<mo>′</mo>' if sup is None else sup
            else:
                break
        if sub is None and sup is None:
            return base
        big = base.startswith('<mo>') and any(
            ('<mo>%s</mo>' % OPS[k]) == base for k in BIG)
        if big:
            if sub is not None and sup is not None:
                return '<munderover>%s%s%s</munderover>' % (base, sub, sup)
            if sub is not None:
                return '<munder>%s%s</munder>' % (base, sub)
            return '<mover>%s%s</mover>' % (base, sup)
        if sub is not None and sup is not None:
            return '<msubsup>%s%s%s</msubsup>' % (base, sub, sup)
        if sub is not None:
            return '<msub>%s%s</msub>' % (base, sub)
        return '<msup>%s%s</msup>' % (base, sup)

    def parse_script_arg(self):
        self.skip_ws()
        if self.peek() == '{':
            self.i += 1
            row = self.parse_row()
            if self.peek() == '}':
                self.i += 1
            return '<mrow>%s</mrow>' % ''.join(row)
        atom = self.parse_atom()
        return atom if atom else '<mrow></mrow>'

    def group(self):
        """parse a {...} argument as mrow"""
        self.skip_ws()
        if self.peek() == '{':
            self.i += 1
            row = self.parse_row()
            if self.peek() == '}':
                self.i += 1
            return '<mrow>%s</mrow>' % ''.join(row)
        a = self.parse_atom()
        return a or '<mrow></mrow>'

    def text_arg(self):
        self.skip_ws()
        if self.peek() == '{':
            depth = 0
            j = self.i
            while j < len(self.s):
                if self.s[j] == '{':
                    depth += 1
                elif self.s[j] == '}':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            t = self.s[self.i + 1:j]
            self.i = j + 1
            return t
        t = self.s[self.i]
        self.i += 1
        return t

    # ---------------------------------------------------------------
    def parse_atom(self):
        self.skip_ws()
        if self.eof():
            return None
        c = self.peek()
        if c == '{':
            self.i += 1
            row = self.parse_row()
            if self.peek() == '}':
                self.i += 1
            return '<mrow>%s</mrow>' % ''.join(row)
        if c == '\\':
            self.i += 1
            return self.parse_command()
        self.i += 1
        if c.isdigit() or (c == '.' and self.peek().isdigit()):
            m = re.match(r'[0-9]*\.?[0-9]*', self.s[self.i - 1:])
            num = m.group(0)
            self.i += len(num) - 1
            return '<mn>%s</mn>' % num
        if c.isalpha():
            return '<mi>%s</mi>' % c
        if c == '|':
            return '<mo stretchy="false">|</mo>'
        if c in '()[]':
            return '<mo stretchy="false">%s</mo>' % c
        if c in ',;':
            return '<mo>%s</mo>' % c
        if c == '-':
            return '<mo>−</mo>'
        if c == '*':
            return '<mo>∗</mo>'
        return '<mo>%s</mo>' % esc(c)

    def parse_command(self):
        name = self.command()
        if name in GREEK:
            return '<mi>%s</mi>' % GREEK[name]
        if name in OPS:
            return '<mo>%s</mo>' % OPS[name]
        if name in SPACES:
            return '<mspace width="%s"/>' % SPACES[name]
        if name in FUNCS:
            return '<mi mathvariant="normal">%s</mi><mo>&#x2061;</mo>' % name
        if name in SIZERS:
            self.skip_ws()
            d = self.read_delim()
            return '<mo stretchy="false">%s</mo>' % esc(d)
        if name == 'underbrace':
            body = self.group()
            self.skip_ws()
            label = ''
            if self.peek() == '_':
                self.i += 1
                label = self.parse_script_arg()
            res = '<munder><munder>%s<mo>&#x23DF;</mo></munder>%s</munder>' % (
                body, label) if label else '<munder>%s<mo>&#x23DF;</mo></munder>' % body
            return res
        if name == 'overbrace':
            body = self.group()
            self.skip_ws()
            label = ''
            if self.peek() == '^':
                self.i += 1
                label = self.parse_script_arg()
            return '<mover><mover>%s<mo>&#x23DE;</mo></mover>%s</mover>' % (
                body, label) if label else '<mover>%s<mo>&#x23DE;</mo></mover>' % body
        if name == 'xrightarrow':
            arg = self.group()
            return '<mover><mo>→</mo>%s</mover>' % arg
        if name in ('mathrel', 'mathbin', 'mathop', 'mathord'):
            return self.group()
        if name == 'mid':
            return '<mo>|</mo>'
        if name == 'vert' or name == '|':
            return '<mo>‖</mo>'
        if name == 'frac' or name == 'dfrac' or name == 'tfrac':
            a = self.group()
            b = self.group()
            return '<mfrac>%s%s</mfrac>' % (a, b)
        if name == 'sqrt':
            self.skip_ws()
            if self.peek() == '[':
                j = self.s.index(']', self.i)
                idx = Parser(self.s[self.i + 1:j]).parse_row()
                self.i = j + 1
                return '<mroot>%s<mrow>%s</mrow></mroot>' % (
                    self.group(), ''.join(idx))
            return '<msqrt>%s</msqrt>' % self.group()
        if name in ('mathbf', 'boldsymbol', 'bm'):
            inner = self.group()
            return '<mrow mathvariant="bold">%s</mrow>' % bold(inner)
        if name in ('mathrm', 'operatorname'):
            t = self.text_arg()
            return '<mi mathvariant="normal">%s</mi>' % esc(t)
        if name == 'text':
            t = self.text_arg()
            return '<mtext>%s</mtext>' % esc(t)
        if name == 'mathcal':
            t = self.text_arg()
            return '<mi>%s</mi>' % mathcal(t)
        if name == 'mathbb':
            t = self.text_arg()
            return '<mi>%s</mi>' % {'R': 'ℝ', 'N': 'ℕ', 'Z': 'ℤ'}.get(t, t)
        if name in ACCENTS:
            inner = self.group()
            return '<mover accent="true">%s<mo>%s</mo></mover>' % (
                inner, ACCENTS[name])
        if name == 'underline':
            inner = self.group()
            return '<munder>%s<mo>_</mo></munder>' % inner
        if name == 'left':
            self.skip_ws()
            d = self.read_delim()
            row = self.parse_row()
            self.skip_ws()
            if self.s.startswith('\\right', self.i):
                self.i += 6
                self.skip_ws()
                e = self.read_delim()
            else:
                e = ''
            return '<mrow>%s%s%s</mrow>' % (fence(d, True), ''.join(row),
                                           fence(e, False))
        if name == 'begin':
            env = self.text_arg()
            return self.environment(env)
        if name == '{' or name == '}':
            return '<mo>%s</mo>' % name
        if name == '\\':
            return None
        if name == '%':
            return '<mo>%</mo>'
        if name == '&':
            return '<mo>&amp;</mo>'
        if name == '_':
            return '<mo>_</mo>'
        if name == 'ell':
            return '<mi>ℓ</mi>'
        if name == 'hbar':
            return '<mi>ℏ</mi>'
        if name == 'overset' or name == 'stackrel':
            a = self.group()
            b = self.group()
            return '<mover>%s%s</mover>' % (b, a)
        UNKNOWN.add(name)
        # unknown: render as text
        return '<mtext>\\%s</mtext>' % esc(name)

    def read_delim(self):
        if self.eof():
            return ''
        c = self.peek()
        if c == '\\':
            self.i += 1
            n = self.command()
            return {'{': '{', '}': '}', 'langle': '⟨', 'rangle': '⟩',
                    'lVert': '‖', 'rVert': '‖', '|': '‖'}.get(n, n)
        self.i += 1
        return '' if c == '.' else c

    def environment(self, env):
        rows = []
        cur = []
        cell = []
        while True:
            self.skip_ws()
            if self.eof():
                break
            if self.s.startswith('\\end', self.i):
                self.i += 4
                self.text_arg()
                break
            if self.peek() == '&':
                self.i += 1
                cur.append(''.join(cell))
                cell = []
                continue
            if self.s.startswith('\\\\', self.i):
                self.i += 2
                cur.append(''.join(cell))
                cell = []
                rows.append(cur)
                cur = []
                continue
            atom = self.parse_atom()
            if atom is None:
                continue
            cell.append(self.scripts(atom))
        if cell or cur:
            cur.append(''.join(cell))
            rows.append(cur)
        rows = [r for r in rows if any(c.strip() for c in r)]
        if env in ('cases', 'aligned', 'align', 'array', 'split'):
            align = 'left'
        else:
            align = 'center'
        t = ''.join('<mtr>%s</mtr>' % ''.join(
            '<mtd columnalign="%s"><mrow>%s</mrow></mtd>' % (align, c)
            for c in r) for r in rows)
        table = '<mtable columnspacing="0.8em" rowspacing="0.25em">%s</mtable>' % t
        if env == 'bmatrix':
            return '<mrow>%s%s%s</mrow>' % (fence('[', True), table,
                                           fence(']', False))
        if env == 'pmatrix':
            return '<mrow>%s%s%s</mrow>' % (fence('(', True), table,
                                           fence(')', False))
        if env == 'vmatrix':
            return '<mrow>%s%s%s</mrow>' % (fence('|', True), table,
                                           fence('|', False))
        if env == 'cases':
            return '<mrow>%s%s</mrow>' % (fence('{', True), table)
        return table


def fence(d, opening):
    if not d:
        return ''
    return '<mo fence="true" stretchy="true">%s</mo>' % esc(d)


def bold(inner):
    return inner.replace('<mi>', '<mi mathvariant="bold">') \
                .replace('<mn>', '<mn>')


def mathcal(t):
    table = {'A': '𝒜', 'B': 'ℬ', 'C': '𝒞', 'D': '𝒟', 'E': 'ℰ', 'F': 'ℱ',
             'G': '𝒢', 'H': 'ℋ', 'I': 'ℐ', 'J': '𝒥', 'K': '𝒦', 'L': 'ℒ',
             'M': 'ℳ', 'N': '𝒩', 'O': '𝒪', 'P': '𝒫', 'Q': '𝒬', 'R': 'ℛ',
             'S': '𝒮', 'T': '𝒯', 'U': '𝒰', 'V': '𝒱', 'W': '𝒲', 'X': '𝒳',
             'Y': '𝒴', 'Z': '𝒵'}
    return ''.join(table.get(ch, ch) for ch in t)


def tex_to_mathml(tex, display=False):
    p = Parser(tex.strip())
    row = []
    while not p.eof():
        row.extend(p.parse_row())
        if not p.eof():
            p.i += 1  # stray closing token
    body = ''.join(row)
    attr = ' display="block"' if display else ''
    return '<math%s xmlns="http://www.w3.org/1998/Math/MathML">%s</math>' % (
        attr, body)


if __name__ == '__main__':
    print(tex_to_mathml(r'\boldsymbol{\varepsilon}=\frac{\partial u}{\partial x}'
                        r'+\sum_{i=1}^{N}N_i F_\tau', True))
