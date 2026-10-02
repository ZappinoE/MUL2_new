#!/usr/bin/env python3
"""Compare the point data of two legacy ASCII VTK files (validation tool).

The solver does not depend on Python: this script is only used to compare the
output of MUL2_V3 with the frozen baseline results in REFERENCES/GOLDEN.

    python compare_vtk.py NEW.vtk OLD.vtk [--only NAME ...]

For every point-data array prints max |new-old| and max |old| and the ratio.
Mode shapes (VECTORS Mode:...) are compared up to sign and scale (MAC).
"""
import re
import sys


def read_vtk(path):
    with open(path, 'r', errors='replace') as handle:
        lines = handle.read().split('\n')
    data = {}
    points = None
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('POINTS'):
            count = int(line.split()[1])
            values = []
            i += 1
            while len(values) < 3 * count:
                values += [float(x) for x in lines[i].split()]
                i += 1
            points = [values[3 * k:3 * k + 3] for k in range(count)]
            continue
        match = re.match(r'(VECTORS|SCALARS)\s+(\S+)', line)
        if match:
            kind, name = match.groups()
            width = 3 if kind == 'VECTORS' else 1
            i += 1
            if kind == 'SCALARS':
                i += 1  # LOOKUP_TABLE
            values = []
            need = width * len(points)
            while len(values) < need:
                values += [float(x) for x in lines[i].split()]
                i += 1
            data[name] = [values[width * k:width * k + width]
                          for k in range(len(points))]
            continue
        i += 1
    return points, data


def flatten(rows):
    return [v for row in rows for v in row]


def main():
    args = sys.argv[1:]
    only = []
    if '--only' in args:
        k = args.index('--only')
        only = args[k + 1:]
        args = args[:k]
    new_points, new = read_vtk(args[0])
    old_points, old = read_vtk(args[1])
    print('points: new=%d old=%d' % (len(new_points), len(old_points)))
    if len(new_points) == len(old_points):
        diff = max(abs(a - b) for p, q in zip(new_points, old_points)
                   for a, b in zip(p, q))
        print('max coordinate difference: %.3e' % diff)
    for name in old:
        if only and name not in only:
            continue
        if name not in new:
            print('%-40s MISSING in new' % name)
            continue
        a = flatten(new[name])
        b = flatten(old[name])
        if len(a) != len(b):
            print('%-40s size differs' % name)
            continue
        if name.startswith('Mode:'):
            dot = sum(x * y for x, y in zip(a, b))
            na = sum(x * x for x in a) ** 0.5
            nb = sum(y * y for y in b) ** 0.5
            mac = (dot / (na * nb)) ** 2 if na * nb > 0 else 0.0
            print('%-40s MAC = %.12f' % (name, mac))
            continue
        scale = max(abs(y) for y in b) or 1.0
        err = max(abs(x - y) for x, y in zip(a, b))
        print('%-40s max|d|=%.3e  max|old|=%.3e  ratio=%.3e' %
              (name, err, scale, err / scale))


if __name__ == '__main__':
    main()
