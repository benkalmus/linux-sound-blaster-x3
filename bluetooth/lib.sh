#!/usr/bin/env bash
# Shared setup for the bluetooth agent harness.

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
STUB=$HERE/bluez_stub.py
AGENT=$REPO/bin/bluetooth-auto-agent

LOG_DIR=${LOG_DIR:-$(mktemp -d)}
STUB_LOG=$LOG_DIR/stub.log
AGENT_LOG=$LOG_DIR/agent.log
pids=()

LAST_PID=

start_stub() {
  env "$@" STUB_LOG="$STUB_LOG" \
    DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    /usr/bin/python3 -u "$STUB" >"$LOG_DIR/stub.out" 2>&1 &
  LAST_PID=$!
  pids+=("$LAST_PID")
}

start_agent() {
  DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    /usr/bin/python3 -u "$AGENT" >"$AGENT_LOG" 2>&1 &
  LAST_PID=$!
  pids+=("$LAST_PID")
}

stop_all() {
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}

fail() {
  echo "FAIL: $*" >&2
  echo "--- stub calls ---" >&2
  cat "$STUB_LOG" >&2 2>/dev/null || true
  echo "--- stub output ---" >&2
  cat "$LOG_DIR/stub.out" >&2 2>/dev/null || true
  echo "--- agent output ---" >&2
  cat "$AGENT_LOG" >&2 2>/dev/null || true
  stop_all
  exit 1
}

expect_line() {
  grep -qx -- "$1" "$2" || fail "missing line in ${2##*/}: $1"
}

expect_count() {
  local found
  found=$(grep -cx -- "$1" "$3" || true)
  [[ $found -eq $2 ]] || fail "expected $2 of '$1' in ${3##*/}, found $found"
}

expect_text() {
  grep -q -- "$1" "$2" || fail "missing text in ${2##*/}: $1"
}

expect_order() {
  awk -v first="$1" -v second="$2" '
    $0 == first {seen = 1; next}
    seen && $0 == second {found = 1}
    END {exit !found}
  ' "$3" || fail "expected '$2' after '$1' in ${3##*/}"
}
