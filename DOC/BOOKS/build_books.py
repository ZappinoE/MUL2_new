"""Build the three PDF guides.

    python DOC/BOOKS/build_books.py [theory|implementation|user|all] [--html-only]

Steps: generate figures and the source reference, convert the Markdown
chapters to one HTML file per book (MathML math, inline SVG), print to PDF
with Edge headless (Chromium). Output: DOC/MUL2_NEW_<name>_Guide.pdf
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'tools'))
import mdbook  # noqa: E402
import refgen  # noqa: E402
import figs    # noqa: E402

EDGE = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
VERSION = '1.0 (October 2026)'
AUTHOR = 'Politecnico di Torino · MUL2 project'

BOOKS = {
    'theory': dict(
        title='Theoretical Guide',
        subtitle='Carrera Unified Formulation, finite elements and numerical methods behind MUL2_NEW',
        out='MUL2_NEW_Theoretical_Guide.pdf'),
    'implementation': dict(
        title='Implementation Guide',
        subtitle='Architecture, data structures, algorithms and routine reference of MUL2_NEW',
        out='MUL2_NEW_Implementation_Guide.pdf'),
    'user': dict(
        title='User Guide',
        subtitle='Building models, reference systems, running analyses and reading results',
        out='MUL2_NEW_User_Guide.pdf'),
}


# A5 pages for e-readers (reMarkable): narrower margins, slightly smaller
# tables and listings so that they fit the 148 mm width
A5_CSS = '''
@page { size: A5; margin: 13mm 10mm 14mm 11mm; }
html { font-size: 10pt; }
h1 { font-size: 19pt; } h2 { font-size: 13pt; } h3 { font-size: 11pt; }
table { font-size: 7.8pt; } td code { font-size: 7.2pt; }
code { font-size: 8pt; } pre { font-size: 7.2pt; padding: 4pt 5pt; }
.eqbody { font-size: 10.5pt; } .coverTitle, .covertitle { font-size: 26pt; }
.coversub { font-size: 12pt; margin-bottom: 24pt; }
'''


def chapter_files(name):
    d = os.path.join(HERE, name)
    chapters = sorted(glob.glob(os.path.join(d, '[0-9]*.md')))
    apps = sorted(glob.glob(os.path.join(d, 'app_*.md')))
    files = chapters + apps
    only = os.environ.get('ONLY')          # e.g. ONLY=04,05 prints a subset
    if only:
        keys = only.split(',')
        files = [f for f in files if any(
            os.path.basename(f).startswith(k) for k in keys)]
    return files


def build(name, html_only=False):
    cfg = BOOKS[name]
    css = open(os.path.join(HERE, 'tools', 'style.css'),
               encoding='utf-8').read()
    a5 = '--a5' in sys.argv
    if a5:
        css += A5_CSS
    book = mdbook.Book(cfg['title'], cfg['subtitle'], AUTHOR, VERSION,
                       os.path.join(HERE, name),
                       os.path.join(HERE, 'figures'))
    html = book.build(chapter_files(name), css)
    suffix = '_part' if os.environ.get('ONLY') else ''
    if a5:
        suffix += '_A5'
    out_html = os.path.join(HERE, 'build', name + suffix + '.html')
    with open(out_html, 'w', encoding='utf-8') as f:
        f.write(html)
    import tex2mathml
    if tex2mathml.UNKNOWN:
        print('  UNKNOWN LaTeX commands:', sorted(tex2mathml.UNKNOWN))
    missing = html.count('class="missing"')
    print('%s: %d chapters/sections, %d unresolved refs/figures' % (
        name, len(book.toc), missing))
    if html_only:
        return
    pdf = os.path.abspath(os.path.join(HERE, '..', cfg['out']))
    if a5:
        pdf = pdf[:-4] + '_A5.pdf'
    if os.environ.get('ONLY'):
        pdf = os.path.join(HERE, 'build', name + '_part.pdf')
    if os.path.exists(pdf):
        try:
            os.remove(pdf)
        except PermissionError:      # file open in a viewer
            pdf = pdf[:-4] + '_new.pdf'
            if os.path.exists(pdf):
                os.remove(pdf)
    url = 'file:///' + out_html.replace('\\', '/')
    url = url.replace(' ', '%20')
    subprocess.run([EDGE, '--headless=new', '--disable-gpu',
                    '--no-pdf-header-footer',
                    '--generate-pdf-document-outline',
                    '--virtual-time-budget=20000',
                    '--print-to-pdf=' + pdf, url],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=600)
    print('  ->', pdf, os.path.getsize(pdf) // 1024 if os.path.exists(pdf)
          else 'NOT CREATED', 'KB')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    html_only = '--html-only' in sys.argv
    which = args[0] if args else 'all'
    figs.make_all()
    refgen.build()
    for name in (BOOKS if which == 'all' else [which]):
        build(name, html_only)


if __name__ == '__main__':
    main()
