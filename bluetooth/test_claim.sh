#!/usr/bin/env bash
# The agent takes the default agent back after bluedevil claims it.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_stub
sleep 1
start_agent
sleep 2

DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  /usr/bin/python3 -u "$HERE/claim_as_competitor.py"
sleep 7

stop_all

expect_line "RequestDefaultAgent /modules/bluedevil/Agent" "$STUB_LOG"
expect_order "RequestDefaultAgent /modules/bluedevil/Agent" \
  "RequestDefaultAgent /org/bluez/autoagent" "$STUB_LOG"
echo "claim test ok"
