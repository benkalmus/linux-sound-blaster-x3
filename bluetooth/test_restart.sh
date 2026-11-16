#!/usr/bin/env bash
# The agent re-registers when bluetoothd restarts.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_stub
stub=$LAST_PID
sleep 1
start_agent
sleep 2

kill "$stub" 2>/dev/null || true
wait "$stub" 2>/dev/null || true
sleep 1

start_stub
sleep 3

stop_all

expect_count "RegisterAgent /org/bluez/autoagent NoInputNoOutput" 2 "$STUB_LOG"
expect_count "Bluetooth daemon appeared" 2 "$AGENT_LOG"
expect_text "Bluetooth daemon went away" "$AGENT_LOG"
echo "restart test ok"
