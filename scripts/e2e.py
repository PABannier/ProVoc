#!/usr/bin/env python3
"""Plays the end-to-end scenarios of ProVocDriver in the stand-alone Debug application.

usage: scripts/e2e.py [--list] [--only NAME[,NAME...]] [--logs DIR]

Each scenario is one launch of build/DerivedData/Build/Products/Debug/ProVoc.app with
the driver library inserted (see ProVocDriver/PVDriver.h). A scenario with several
phases launches the application several times with the same work directory.
Exit status 0 only if every scenario passes and no log holds a forbidden message.
"""
import os, re, shutil, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRODUCTS = os.path.join(ROOT, 'build/DerivedData/Build/Products/Debug')
APP = os.path.join(PRODUCTS, 'ProVoc.app/Contents/MacOS/ProVoc')
DRIVER = os.path.join(PRODUCTS, 'ProVocDriver.dylib')
ACTIVATOR = os.path.join(ROOT, 'build/activate-test-host')
FIXTURES = os.path.join(ROOT, 'fixtures')

# Messages that must never be in the log of the application
FORBIDDEN = re.compile(r'unrecognized selector|[Ee]xception|Could not load NIB|failed to load|nil outlet|Could not connect|Unknown class|'
                       r'Unable to simultaneously satisfy constraints|An instance .* was deallocated while key value observers|\*\*\*')
# ... except these lines, which are not about ProVoc
ALLOWED = re.compile(r'AUCrashHandler|temporary-exception|CoreAnalytics|TCC|com\.apple\.')

FRESH = ['-PVResetDefaults', 'YES']
BASE = ['-ApplePersistenceIgnoreState', 'YES', '-NSQuitAlwaysKeepsWindows', 'NO', '-PVRandomSeed', '42']

# name -> list of phases; a phase is (scenario method, arguments of the application, expects termination)
SCENARIOS = {
    'launch': [('clearRecentDocuments', FRESH), ('launch', FRESH)],
    'document-new-save-close-reopen': [('documentNewSaveCloseReopen', FRESH)],
    'editing-words-with-undo': [('editingWordsWithUndo', FRESH)],
    'editing-lessons-with-undo': [('editingLessonsWithUndo', FRESH)],
}


def run_phase(name, method, arguments, workdir, logs, timeout=120):
    result = os.path.join(workdir, 'result-%s.txt' % method)
    if os.path.exists(result):
        os.remove(result)
    env = dict(os.environ, DYLD_INSERT_LIBRARIES=DRIVER, PV_SCENARIO=method, PV_RESULT_FILE=result, PV_WORKDIR=workdir,
               PV_FIXTURES=FIXTURES)
    arguments = [a.replace('{work}', workdir).replace('{fixtures}', FIXTURES) for a in arguments]
    log_path = os.path.join(logs, 'e2e-%s-%s.log' % (name, method))
    with open(log_path, 'w') as log:
        process = subprocess.Popen([APP] + BASE + arguments, env=env, stdout=log, stderr=subprocess.STDOUT, cwd=workdir)
        try:
            status = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            return ['the application did not end within %d s (killed)' % timeout]
    failures = []
    verdict = open(result).read().splitlines() if os.path.exists(result) else ['NO VERDICT (exit status %s)' % status]
    if verdict[:1] != ['PASS']:
        failures += verdict
    if status != 0 and not failures:
        failures.append('exit status %s' % status)
    for line in open(log_path, errors='replace'):
        if FORBIDDEN.search(line) and not ALLOWED.search(line) and 'PVDriver: FAILED' not in line:
            failures.append('log: ' + line.strip()[:300])
    return failures


def main():
    arguments = sys.argv[1:]
    if '--list' in arguments:
        print('\n'.join(SCENARIOS))
        return 0
    only = None
    if '--only' in arguments:
        only = arguments[arguments.index('--only') + 1].split(',')
    logs = os.path.join(ROOT, 'verification/logs')
    if '--logs' in arguments:
        logs = arguments[arguments.index('--logs') + 1]
    os.makedirs(logs, exist_ok=True)
    for path in (APP, DRIVER, ACTIVATOR):
        if not os.path.exists(path):
            print('missing %s (build the Debug configuration first)' % path)
            return 2
    # no "quit unexpectedly" dialog if the application crashes: it would keep the keyboard focus
    old_dialog = subprocess.run(['defaults', 'read', 'com.apple.CrashReporter', 'DialogType'], capture_output=True, text=True).stdout.strip()
    subprocess.run(['defaults', 'write', 'com.apple.CrashReporter', 'DialogType', 'none'])
    # the application is started in the background: bring it to the front
    activator = subprocess.Popen([ACTIVATOR, APP], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    failed = 0
    try:
        for name, phases in SCENARIOS.items():
            if only and name not in only:
                continue
            workdir = tempfile.mkdtemp(prefix='provoc-e2e-%s-' % name)
            started = time.time()
            failures = []
            for phase in phases:
                method, phase_arguments = phase[0], phase[1]
                failures = run_phase(name, method, phase_arguments, workdir, logs)
                if failures:
                    failures = ['phase %s: %s' % (method, f) for f in failures]
                    break
            shutil.rmtree(workdir, ignore_errors=True)
            print('%s %s (%.1f s)' % ('PASS' if not failures else 'FAIL', name, time.time() - started))
            for failure in failures:
                print('    ' + failure[:600])
            failed += bool(failures)
    finally:
        activator.terminate()
        if old_dialog:
            subprocess.run(['defaults', 'write', 'com.apple.CrashReporter', 'DialogType', old_dialog])
        else:
            subprocess.run(['defaults', 'delete', 'com.apple.CrashReporter', 'DialogType'], capture_output=True)
    print('%d scenario(s) failed' % failed if failed else 'all scenarios passed')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
