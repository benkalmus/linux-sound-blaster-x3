#!/usr/bin/env bash
# Run every agent test on its own private bus.

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
failed=0

for test in "$HERE"/test_*.sh; do
  name=$(basename "$test" .sh)
  if dbus-run-session -- "$test"; then
    echo "PASS $name"
  else
    echo "FAIL $name"
    failed=1
  fi
done

exit "$failed"
