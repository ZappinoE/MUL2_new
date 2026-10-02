import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import refgen

infos = refgen.build()
out = []
for i in infos:
    for t in i['types']:
        out.append('%s.%s  [%s]' % (i['module'], t['name'], t['doc']))
        for nm, typ, dims, dflt, doc in t['comps']:
            out.append('    %s %s%s = %s | %s' % (nm, typ, dims, dflt, doc))
    for nm, typ, val, doc, pub in i['params']:
        if pub:
            out.append('PARAM %s.%s = %s | %s' % (i['module'], nm, val, doc))
open(os.path.join(os.path.dirname(__file__), '..', 'build', 'types.txt'),
     'w', encoding='utf-8').write('\n'.join(out))
print(len(out))
