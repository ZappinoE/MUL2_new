"""Run the validation groups:  python run_all.py [group ...]"""
import importlib
import sys
import time

GROUPS = [
    ('taylor', 'g_beams', 'group_taylor'),
    ('le', 'g_beams', 'group_le'),
    ('hle', 'g_hle', 'group_hle'),
    ('plates', 'g_plates', 'group_plates'),
    ('plates2', 'g_plates2', 'group_plates2'),
    ('solids', 'g_solids', 'group_solids'),
    ('ndk', 'g_ndk', 'group_ndk'),
    ('multi', 'g_multi', 'group_multi'),
    ('mitc', 'g_mitc', 'group_mitc'),
    ('multifield', 'g_multifield', 'group_multifield'),
    ('nonlinear', 'g_nonlinear', 'group_nonlinear'),
]

if __name__ == '__main__':
    want = sys.argv[1:] or [g[0] for g in GROUPS]
    t0 = time.time()
    for gid, mod, fn in GROUPS:
        if gid in want:
            t1 = time.time()
            getattr(importlib.import_module(mod), fn)()
            print('   (%.0f s)' % (time.time() - t1))
    print('total %.0f s' % (time.time() - t0))

