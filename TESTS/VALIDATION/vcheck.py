"""Result collection for the validation campaign."""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
RES_DIR = os.path.join(HERE, 'results')


class Group:
    """Container of the checks, tables and plot series of one test group."""

    def __init__(self, gid, title, intro=''):
        self.id = gid
        self.title = title
        self.intro = intro
        self.checks = []
        self.tables = []
        self.series = []
        self.notes = []
        self.runs = 0
        self.seconds = 0.0

    def run(self, case, **kw):
        """run a Case and account for it."""
        r = case.run(**kw)
        self.runs += 1
        self.seconds += r.wall
        return r

    def check(self, name, measured, reference, tol, ref, mode='rel',
              unit='', note=''):
        """record a comparison.  mode 'rel': |m-r|/|r|; 'abs': |m-r|;
        tol None -> informative row (status INFO)."""
        if measured is None or reference is None or \
                (isinstance(measured, float) and math.isnan(measured)):
            err = float('nan')
        elif mode == 'rel':
            err = abs(measured - reference) / max(abs(reference), 1e-300)
        else:
            err = abs(measured - reference)
        if tol is None:
            status = 'INFO'
        else:
            status = 'PASS' if (err == err and err <= tol) else 'FAIL'
        self.checks.append(dict(name=name, measured=measured,
                                reference=reference, err=err, tol=tol,
                                ref=ref, mode=mode, unit=unit,
                                status=status, note=note))
        return status

    def flag(self, name, ok, detail, ref=''):
        """boolean check (expected behaviour)."""
        self.checks.append(dict(name=name, measured=None, reference=None,
                                err=0.0 if ok else 1.0, tol=0.0, ref=ref,
                                mode='flag', unit='', note=detail,
                                status='PASS' if ok else 'FAIL'))
        return ok

    def table(self, title, headers, rows, note=''):
        self.tables.append(dict(title=title, headers=headers, rows=rows,
                                note=note))

    def plot(self, title, xlabel, ylabel, curves, logy=False, logx=False,
             hlines=None, note=''):
        """curves: {label: (xs, ys)}; hlines: {label: value}"""
        self.series.append(dict(title=title, xlabel=xlabel, ylabel=ylabel,
                                curves={k: [list(v[0]), list(v[1])]
                                        for k, v in curves.items()},
                                logy=logy, logx=logx, hlines=hlines or {},
                                note=note))

    def summary(self):
        n = len(self.checks)
        p = sum(1 for c in self.checks if c['status'] == 'PASS')
        f = sum(1 for c in self.checks if c['status'] == 'FAIL')
        i = sum(1 for c in self.checks if c['status'] == 'INFO')
        return n, p, f, i

    def save(self):
        os.makedirs(RES_DIR, exist_ok=True)
        with open(os.path.join(RES_DIR, self.id + '.json'), 'w') as f:
            json.dump(dict(id=self.id, title=self.title, intro=self.intro,
                           checks=self.checks, tables=self.tables,
                           series=self.series, notes=self.notes,
                           runs=self.runs, seconds=self.seconds), f,
                      indent=1, default=lambda o: None)
        n, p, f_, i = self.summary()
        print('[%s] %d checks: %d PASS, %d FAIL, %d INFO  (%d runs, %.1f s)'
              % (self.id, n, p, f_, i, self.runs, self.seconds))
        for c in self.checks:
            if c['status'] == 'FAIL':
                print('   FAIL', c['name'], c['measured'], c['reference'],
                      'err=%.3e' % c['err'], c['note'])


def sci(x, d=4):
    if x is None:
        return '-'
    if isinstance(x, str):
        return x
    if x != x:
        return 'NaN'
    return ('%.' + str(d) + 'g') % x
