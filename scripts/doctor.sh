#!/usr/bin/env bash
# Check the installed state. Read-only.
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_root doctor

log "card"
as_user pactl list cards short 2>/dev/null | grep -i creative || echo "not found"
log "sinks"
as_user pactl list short sinks 2>/dev/null
log "default sink"
as_user pactl info 2>/dev/null | grep "Default Sink" || true
log "expected output"
as_user pactl list short sinks 2>/dev/null | grep -F "$X3_SINK" || echo "missing: $X3_SINK"
log "speaker volume"
amixer -c "$CARD_ID" cget numid=13 2>/dev/null | sed -n "3p" || true
log "links"
as_user pw-link -l 2>/dev/null | grep -A1 "unified-upmix-output" || true
log "units"
systemctl is-active alsa-restore-delayed.timer 2>/dev/null || true

log "greeter audio"
if ! id sddm >/dev/null 2>&1; then
    echo "sddm user not found; no greeter audio to mask"
else
    sddm_uid=$(id -u sddm)
    sddm_home=$(getent passwd sddm | cut -d: -f6)
    mask_ok=1
    for unit in "${SDDM_AUDIO_UNITS[@]}"; do
        state=$(runuser -u sddm -- env XDG_RUNTIME_DIR="/run/user/$sddm_uid" \
            systemctl --user is-enabled "$unit" 2>/dev/null || true)
        if [[ $state != masked && ! -L "$sddm_home/.config/systemd/user/$unit" ]]; then
            echo "warn: sddm $unit is ${state:-unknown}"
            mask_ok=0
        fi
    done
    if [[ $mask_ok -eq 1 ]]; then
        echo "ok: all sddm audio units are masked"
    fi
    runuser -u sddm -- env XDG_RUNTIME_DIR="/run/user/$sddm_uid" \
        systemctl --user is-active pipewire.service 2>/dev/null || true
    ps -eo user,pid,cmd | grep -E '^sddm +.*(pipewire|wireplumber)' || true
fi
