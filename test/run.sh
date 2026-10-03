#!/usr/bin/env bash
# Runs ping.sh the way the action does and checks each outcome.
# Usage: LATEPING_TEST_URL=https://app-staging.lateping.com/p/<check-id> test/run.sh
# The test check should have a long period, so these pings never make it alert. Failure mapping is
# tested against a check ID that doesn't exist, so no /fail alert is ever sent.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
: "${LATEPING_TEST_URL:?set LATEPING_TEST_URL}"
base="${LATEPING_TEST_URL%/p/*}"
missing="$base/p/00000000-0000-0000-0000-000000000000"
fails=0

run() { # run <expected-exit> <expected-signal|-> <url> <status> [strict]
  local out; out=$(mktemp)
  GITHUB_OUTPUT="$out" LATEPING_URL="$3" LATEPING_STATUS="$4" LATEPING_STRICT="${5:-false}" bash ping.sh >"$out.log" 2>&1
  local code=$? signal; signal=$(sed -n 's/^signal=//p' "$out")
  if [[ $code -ne $1 || ( "$2" != - && "$signal" != "$2" ) ]]; then
    echo "FAIL: status=$4 strict=${5:-false}: exit $code (want $1), signal '$signal' (want $2)"; cat "$out.log"; fails=$((fails + 1))
  else
    echo "ok   status=$4 strict=${5:-false} -> exit $code, signal ${signal:-none}"
  fi
  if [[ -n "$3" ]] && grep -qF "${3#https://}" "$out.log"; then echo "FAIL: the ping URL was printed"; fails=$((fails + 1)); fi
}

run 0 start "$LATEPING_TEST_URL" start
run 0 success "$LATEPING_TEST_URL" success
run 0 success "$LATEPING_TEST_URL" Success
run 0 fail "$missing" failure          # 404 warns, doesn't break the job
run 0 fail "$missing" cancelled
run 1 fail "$missing" failure true     # strict: a failed ping fails the step
run 1 - "$LATEPING_TEST_URL" sideways  # unknown status
run 1 - "https://example.com/hook" success   # not a ping URL
run 1 - "" success                     # missing URL
if [[ $fails -eq 0 ]]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
