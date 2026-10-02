#!/usr/bin/env python3
"""Scans the log of a run of the hosted tests (xcodebuild) for messages that must never
be there: exceptions, unknown selectors, nibs or outlets that fail, layout conflicts.

usage: scripts/scan-log.py <log>     prints the offending lines; exit status 1 if any

The lines of xcodebuild and XCTest themselves are not looked at, nor what the
application logs during a test whose very subject is such a message.
"""
import re, sys

FORBIDDEN = re.compile(r'unrecognized selector|[Ee]xception|Could not load NIB|failed to load|nil outlet|Could not connect|Unknown class|'
                       r'Unable to simultaneously satisfy constraints|was deallocated while key value observers|excessive live window count|\*\*\* ')
# lines that are not about ProVoc
ALLOWED = re.compile(r"^Test (Case|Suite) |^\*\* TEST|^\s+Executed \d+ tests|AUCrashHandler|temporary-exception|CoreAnalytics|TCC|com\.apple\.|IDETestOperationsObserverDebug")
# tests that make the application log an exception on purpose (and check that it does)
EXPECTED = {'testCorruptDeckIsRefusedAndTheExceptionIsLogged'}

current = None
found = []
lines = 0
for line in open(sys.argv[1], errors='replace'):
    lines += 1
    match = re.match(r"Test Case '-\[\w+ (\w+)\]' (started|passed|failed)", line)
    if match:
        current = match.group(1) if match.group(2) == 'started' else None
    if FORBIDDEN.search(line) and not ALLOWED.search(line) and current not in EXPECTED:
        found.append('%s%s' % ('[%s] ' % current if current else '', line.strip()[:400]))
print('\n'.join(found))
if lines == 0:
    print('empty log: nothing to scan')
sys.exit(1 if found or lines == 0 else 0)
