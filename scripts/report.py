#!/usr/bin/env python3
"""Writes verification/report.md from the results of scripts/verify.sh.

The report is scripts/report-notes.md (what was broken and how it was fixed, the
shortcuts, the obsolete features, how to rebuild, the keyboard cheat sheet) followed
by the results of the last run: the steps of the verification, and one verdict for
each line of FEATURES.md.

A line of FEATURES.md names its tests after "test:", separated by commas:
    ProVocTests/Class/method     a test hosted in the application; a method name that
                                 ends with * stands for every test that starts so
                                 (testXInSheet and testXInDimmedModalPanel)
    e2e/name                     a scenario of scripts/e2e.py
    scripts/name.sh              a check made by a script
    verify/name                  a step of scripts/verify.sh
A line passes if each of its tests ran and passed in every run of the suite.

Exit status 0 only if every line of FEATURES.md is ticked and passes.
"""
import glob, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V = os.path.join(ROOT, 'verification')


def load_results():
    """id -> list of (file, 'PASS' | 'FAIL')"""
    results = {}
    for path in sorted(glob.glob(os.path.join(V, 'results', '*.txt'))):
        name = os.path.basename(path)
        if not re.match(r'(hosted-run|e2e-run|scripts|verify)', name):
            continue
        for line in open(path, errors='replace'):
            match = re.match(r'(PASS|FAIL) (\S+)', line)
            if match:
                results.setdefault(match.group(2), []).append((name[:-4], match.group(1)))
    return results


def verdict(test, results, runs):
    """(passed, explanation) for one test id of FEATURES.md"""
    if test.endswith('*'):
        ids = sorted(i for i in results if i.startswith(test[:-1]))
        if not ids:
            return False, '%s: no such test ran' % test
    else:
        ids = [test]
    for i in ids:
        outcomes = results.get(i)
        if not outcomes:
            return False, '%s did not run' % i
        failed = [run for run, outcome in outcomes if outcome != 'PASS']
        if failed:
            return False, '%s failed (%s)' % (i, ', '.join(failed))
        expected = runs.get(i.split('/')[0], 1)
        if len(outcomes) < expected:
            return False, '%s ran %d time(s) instead of %d' % (i, len(outcomes), expected)
    return True, ''


def main():
    results = load_results()
    # the suites are run twice: a test must have passed in both runs
    runs = {'ProVocTests': len(glob.glob(os.path.join(V, 'results', 'hosted-run*.txt'))) or 1,
            'e2e': len(glob.glob(os.path.join(V, 'results', 'e2e-run*.txt'))) or 1}
    features = []
    section = ''
    problems = []
    for number, line in enumerate(open(os.path.join(ROOT, 'FEATURES.md'), encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if line.startswith('## '):
            section = line[3:]
        match = re.match(r'- \[( |x)\] (.*)', line)
        if not match:
            continue
        ticked, text = match.group(1) == 'x', match.group(2)
        parts = re.split(r' — test: ', text)
        tests = [t.strip().strip('`') for t in parts[1].split(',')] if len(parts) == 2 else []
        tests = [t for t in tests if t]
        ok, why = True, []
        if not ticked:
            ok, why = False, ['not ticked']
        if not tests or tests == ['(pending)']:
            ok, why = False, why + ['no test named']
        else:
            for test in tests:
                passed, explanation = verdict(test, results, runs)
                if not passed:
                    ok = False
                    why.append(explanation)
        features.append((section, parts[0], tests, ok, why))
        if not ok:
            problems.append('FEATURES.md:%d: %s — %s' % (number, parts[0][:80], '; '.join(why)))

    out = []
    notes = os.path.join(ROOT, 'scripts', 'report-notes.md')
    if os.path.exists(notes):
        out.append(open(notes, encoding='utf-8').read().rstrip() + '\n')
    out.append('## Results of the last verification run\n')
    commit = subprocess.run(['git', 'log', '-1', '--format=%h %s'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    dirty = subprocess.run(['git', 'status', '--porcelain', '--', 'Sources', 'Resources', 'ProVocTests', 'ProVocDriver', 'scripts', 'project.yml', 'FEATURES.md', 'Importer', 'Actions'],
                           cwd=ROOT, capture_output=True, text=True).stdout.strip()
    out.append('Run of %s in `%s`, at commit `%s`%s.\n' % (time.strftime('%Y-%m-%d %H:%M'), ROOT, commit, ' (with uncommitted changes)' if dirty else ''))
    steps = results_of('verify')
    failed_steps = [i for i, outcome in steps if outcome != 'PASS']
    feature_failures = [f for f in features if not f[3]]
    out.append('**Verdict: %s.**\n' % ('everything passed' if not failed_steps and not feature_failures else
                                      '%d step(s) of the verification and %d line(s) of FEATURES.md do not pass' % (len(failed_steps), len(feature_failures))))
    out.append('### Steps\n')
    out.append('| Step | Result |\n|---|---|')
    for i, outcome in steps:
        out.append('| `%s` | %s |' % (i, outcome))
    out.append('')
    for config in ('Release', 'Debug'):
        path = os.path.join(V, 'results', 'warnings-%s.txt' % config)
        if os.path.exists(path):
            out.append('- %s build: %d different compiler / linker warnings (`verification/results/warnings-%s.txt`).' % (config, sum(1 for l in open(path, errors='replace') if l.strip()), config))
    lipo = os.path.join(V, 'results', 'lipo.txt')
    if os.path.exists(lipo):
        out.append('- ' + open(lipo).read().strip())
    for suite, label in (('hosted', 'Tests hosted in the application'), ('e2e', 'Scenarios of the stand-alone application')):
        for path in sorted(glob.glob(os.path.join(V, 'results', '%s-run*.txt' % suite))):
            lines = [l.split()[:2] for l in open(path) if l.strip()]
            bad = [i for outcome, i in lines if outcome != 'PASS']
            out.append('- %s, run %s: %d passed, %d failed%s.' % (label, re.search(r'run(\d+)', path).group(1), len(lines) - len(bad), len(bad),
                                                                   ' (' + ', '.join('`%s`' % b for b in bad) + ')' if bad else ''))
    out.append('')
    out.append('### Features\n')
    current = None
    for section, text, tests, ok, why in features:
        if section != current:
            current = section
            out.append('\n#### %s\n' % section)
            out.append('| | Feature | Tests |\n|---|---|---|')
        cell = '<br>'.join('`%s`' % t for t in tests) or '—'
        if why:
            cell += '<br>**' + '; '.join(why).replace('|', '\\|') + '**'
        out.append('| %s | %s | %s |' % ('PASS' if ok else 'FAIL', text.replace('|', '\\|'), cell))
    out.append('')
    open(os.path.join(V, 'report.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')

    passed = sum(1 for f in features if f[3])
    print('%d of %d lines of FEATURES.md pass' % (passed, len(features)))
    for problem in problems[:40]:
        print(problem)
    if problems:
        print('%d line(s) of FEATURES.md do not pass' % len(problems))
    return 1 if problems else 0


def results_of(name):
    path = os.path.join(V, 'results', name + '.txt')
    if not os.path.exists(path):
        return []
    return [(m.group(2), m.group(1)) for m in (re.match(r'(PASS|FAIL) (\S+)', l) for l in open(path)) if m]


if __name__ == '__main__':
    sys.exit(main())
