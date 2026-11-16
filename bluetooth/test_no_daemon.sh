#!/usr/bin/env bash
# With no bluetoothd the agent waits instead of crashing.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_agent
agent=$LAST_PID
sleep 2

kill -0 "$agent" 2>/dev/null || fail "agent exited without bluetoothd"

stop_all

expect_text "Waiting for Bluetooth daemon..." "$AGENT_LOG"
echo "no daemon test ok"
