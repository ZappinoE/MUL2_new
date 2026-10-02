import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import refgen

infos = refgen.build()
out = []
for i in infos:
    if not i['module']:
        continue
    out.append('## %s  (%s)' % (i['module'], i['file']))
    for p in i['procs']:
        vis = 'P' if p['name'] in i['public'] else 'p'
        out.append('  %s %s %s(%s)%s' % (
            vis, p['kind'][0], p['name'], ','.join(p['args']),
            '' if not p['doc'] else '  | ' + p['doc'][:80]))
open(os.path.join(os.path.dirname(__file__), '..', 'build', 'procs.txt'),
     'w', encoding='utf-8').write('\n'.join(out))
print(len(out))
