#!/bin/bash
# Writes fixtures/generated/ (Plain.pvoc, Accents.pvoc, "Dead keys.pvoc", Rich.pvoc, "Old format.provoc")
# with the Debug build of the application itself. Build it first (scripts/verify.sh does).
cd "$(dirname "$0")/.." && exec python3 scripts/e2e.py --make-fixtures
