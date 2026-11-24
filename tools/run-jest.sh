#!/usr/bin/env bash
# The Jenkins "Jest Coverage" lane, runnable locally (the Jenkinsfile calls this file).
# ts-jest/swc cannot read .ets, so each .ets is copied to .ts, jest runs, the lcov paths are
# patched back to .ets for SonarQube, and the .ts copies are removed again — also on failure.
# Exit code = jest's exit code (a failing test fails the build).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DIRS=(entry/src/main/ets entry/src/ohosTest/ets/test)

cleanup() { for d in "${DIRS[@]}"; do find "$d" -name '*.ts' -delete; done; }
trap cleanup EXIT

for d in "${DIRS[@]}"; do
    find "$d" -name '*.ets' | while IFS= read -r f; do cp "$f" "${f%.ets}.ts"; done
done
npm run test:coverage -- --forceExit
RC=$?
# lcov: .ts → .ets so SonarQube matches the source files (perl: same on GNU and BSD).
[ -f coverage/jest/lcov.info ] && perl -pi -e 's/\.ts$/.ets/; s/\.ts:/.ets:/g' coverage/jest/lcov.info
exit $RC
