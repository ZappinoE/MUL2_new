import os
import re
import sys
from collections import Counter

p = os.path.join(os.path.dirname(__file__), '..', 'implementation',
                 'app_reference.md')
c = Counter()
where = {}
cur = None
for ln in open(p, encoding='utf-8'):
    m = re.match(r'#### `(\w+)`', ln)
    if m:
        cur = m.group(1)
    m = re.match(r'\| `(\w+)` \| (?:`[^`]*` )?\|\s*\|$', ln.strip()) or \
        re.match(r'\| `(\w+)` \| `[^`]*` \|\s*\|$', ln.strip())
    if m:
        c[m.group(1)] += 1
        where.setdefault(m.group(1), []).append(cur)
for k, v in sorted(c.items()):
    print(k, v, where[k][:3])
