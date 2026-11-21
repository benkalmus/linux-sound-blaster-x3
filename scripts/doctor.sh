#!/usr/bin/env bash
# Check the installed state. Read-only.
set -euo pipefail
source "$(dirname "$0")/common.sh"

echo "== card =="
as_user pactl list cards short 2>/dev/null | grep -i creative || echo "not found"
echo "== sinks =="
as_user pactl list short sinks 2>/dev/null
echo "== default sink =="
as_user pactl info 2>/dev/null | grep "Default Sink" || true
echo "== expected output =="
as_user pactl list short sinks 2>/dev/null | grep -F "$X3_SINK" || echo "missing: $X3_SINK"
echo "== speaker volume =="
amixer -c "$CARD_ID" cget numid=13 2>/dev/null | sed -n "3p" || true
echo "== links =="
as_user pw-link -l 2>/dev/null | grep -A1 "unified-upmix-output" || true
echo "== units =="
systemctl is-active alsa-restore-delayed.timer x3-mixer.timer 2>/dev/null || true
