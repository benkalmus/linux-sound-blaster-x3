#!/usr/bin/env bash
# Every pairing request is accepted without a prompt and the device is trusted.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_stub STUB_TRIGGER_PAIRING=1
sleep 1
start_agent
sleep 4

stop_all

expect_line "RequestConfirmation accepted" "$STUB_LOG"
expect_line "RequestAuthorization accepted" "$STUB_LOG"
expect_line "AuthorizeService accepted" "$STUB_LOG"
expect_count "Set org.bluez.Device1 Trusted 1" 3 "$STUB_LOG"
expect_text "RequestConfirmation /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF 123456" "$AGENT_LOG"
echo "agent1 test ok"
