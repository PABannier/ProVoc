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
BUNDLE = os.path.join(PRODUCTS, 'ProVoc.app')
APP = os.path.join(BUNDLE, 'Contents/MacOS/ProVoc')
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
    'clipboard-between-documents': [('clipboardBetweenDocuments', FRESH)],
    'quit-with-unsaved-changes': [('quitWithUnsavedChanges', FRESH)],
    'launch-with-document': [('launchWithDocument', FRESH + ['{copy:generated/Rich.pvoc}'])],
    'launch-with-old-format-document': [('launchWithOldFormatDocument', FRESH + ['{copy:generated/Old format.provoc}'])],
    'window-state': [('windowStateSave', FRESH), ('windowStateRestore', [])],
    'localization-english': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(en)', 'PV_LANGUAGE=English'])],
    'localization-french': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(fr)', 'PV_LANGUAGE=French'])],
    'localization-german': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(de)', 'PV_LANGUAGE=German'])],
    'localization-italian': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(it)', 'PV_LANGUAGE=Italian'])],
    'localization-spanish': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(es)', 'PV_LANGUAGE=Spanish'])],
    'appearance-light': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(en)', '-AppleInterfaceStyle', 'Light', 'PV_LANGUAGE=English', 'PV_APPEARANCE=Light'])],
    'appearance-dark': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(en)', '-AppleInterfaceStyle', 'Dark', 'PV_LANGUAGE=English', 'PV_APPEARANCE=Dark'])],
    'localization-danish': [('clearRecentDocuments', FRESH), ('localizedSmoke', FRESH + ['-AppleLanguages', '(da)', 'PV_LANGUAGE=Danish'])],
    'quit-with-two-unsaved-documents': [('quitWithTwoUnsavedDocuments', FRESH)],
    'quit-without-changes': [('clearRecentDocuments', FRESH), ('quitWithoutChanges', FRESH)],
}


def run_phase(name, method, arguments, workdir, logs, timeout=120):
    result = os.path.join(workdir, 'result-%s.txt' % method)
    if os.path.exists(result):
        os.remove(result)
    env = dict(os.environ, DYLD_INSERT_LIBRARIES=DRIVER, PV_SCENARIO=method, PV_RESULT_FILE=result, PV_WORKDIR=workdir,
               PV_FIXTURES=FIXTURES)
    arguments = [a.replace('{work}', workdir).replace('{fixtures}', FIXTURES) for a in arguments]
    for index, argument in enumerate(arguments):
        # {copy:path} is replaced by a copy of that fixture in the work directory: fixtures are never opened in place
        match = re.fullmatch(r'\{copy:(.+)\}', argument)
        if match:
            source = os.path.join(FIXTURES, match.group(1))
            target = os.path.join(workdir, os.path.basename(source))
            if not os.path.exists(target):
                (shutil.copytree if os.path.isdir(source) else shutil.copy)(source, target)
            arguments[index] = target
    log_path = os.path.join(logs, 'e2e-%s-%s.log' % (name, method))
    open(log_path, 'w').close()
    # Launched through LaunchServices, as the Finder and the Dock do: the application is
    # activated before its windows appear, and the documents to open come as an "open
    # documents" event. (Started as a plain child process it comes up in the background,
    # and its windows do not become key the same way.)
    extra = dict(a.split('=', 1) for a in arguments if re.match(r'PV_[A-Z_]+=', a))
    arguments = [a for a in arguments if not re.match(r'PV_[A-Z_]+=', a)]
    env.update(extra)
    if 'PV_TRACE_RESPONDER' in os.environ:    # debugging aid: a backtrace when a view of that class becomes first responder
        extra['PV_TRACE_RESPONDER'] = os.environ['PV_TRACE_RESPONDER']
    documents = [a for a in arguments if a.startswith('/')]
    options = [a for a in arguments if not a.startswith('/')]
    command = ['open', '-n', '-W', '-a', BUNDLE, '--stdout', log_path, '--stderr', log_path]
    for key in ['DYLD_INSERT_LIBRARIES', 'PV_SCENARIO', 'PV_RESULT_FILE', 'PV_WORKDIR', 'PV_FIXTURES'] + sorted(extra):
        command += ['--env', '%s=%s' % (key, env[key])]
    command += documents + ['--args'] + BASE + options
    process = subprocess.Popen(command, cwd=workdir)
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        subprocess.run(['pkill', '-f', APP])
        process.wait()
        return ['the application did not end within %d s (killed)' % timeout]
    failures = []
    verdict = open(result).read().splitlines() if os.path.exists(result) else ['NO VERDICT']
    if verdict[:1] != ['PASS']:
        failures += verdict
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
    # the display must not go to sleep (and lock the screen) meanwhile
    awake = subprocess.Popen(['caffeinate', '-d', '-i', '-u', '-w', str(os.getpid())])
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
        awake.terminate()
        if old_dialog:
            subprocess.run(['defaults', 'write', 'com.apple.CrashReporter', 'DialogType', old_dialog])
        else:
            subprocess.run(['defaults', 'delete', 'com.apple.CrashReporter', 'DialogType'], capture_output=True)
    print('%d scenario(s) failed' % failed if failed else 'all scenarios passed')
    return 1 if failed else 0


# scripts/request-capture-access.sh: only the scenario that makes macOS ask for the microphone and the camera
if '--request-capture-access' in sys.argv:
    SCENARIOS = {'request-capture-access': [('requestCaptureAccess', [])]}
    sys.argv.remove('--request-capture-access')
if '--capture-access-status' in sys.argv:
    SCENARIOS = {'capture-access-status': [('captureAccessStatus', [])]}
    sys.argv.remove('--capture-access-status')

# scripts/make-fixtures.sh: only the scenario that writes fixtures/generated
if '--make-fixtures' in sys.argv:
    SCENARIOS = {'generate-fixtures': [('generateFixtures', FRESH)]}
    sys.argv.remove('--make-fixtures')

if __name__ == '__main__':
    sys.exit(main())
