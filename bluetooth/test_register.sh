#!/usr/bin/env bash
# The agent registers, claims the default agent, and configures the adapter.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_stub
sleep 1
start_agent
sleep 7

stop_all

expect_line "RegisterAgent /org/bluez/autoagent NoInputNoOutput" "$STUB_LOG"
expect_count "RequestDefaultAgent /org/bluez/autoagent" 2 "$STUB_LOG"
expect_line "Set org.bluez.Adapter1 Discoverable 1" "$STUB_LOG"
expect_line "Set org.bluez.Adapter1 Pairable 1" "$STUB_LOG"
expect_text "Agent registered with NoInputNoOutput and set as default" "$AGENT_LOG"
echo "register test ok"
