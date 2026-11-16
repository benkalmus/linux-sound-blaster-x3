#!/usr/bin/env bash
# A refused registration exits 1, so systemd restarts the unit.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_stub STUB_FAIL_REGISTER=1
sleep 1
start_agent
agent=$LAST_PID

set +e
wait "$agent"
status=$?
set -e

stop_all

[[ $status -eq 1 ]] || fail "expected exit 1, got $status"
expect_text "Agent registration failed: org.bluez.Error.Failed" "$AGENT_LOG"
echo "register failure test ok"
