#!/usr/bin/env bash
# Install the VBAN receiver on the machine with the X3.
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_root host
start_manifest host

# Remove the hardcoded X3 mixer units from earlier installs.
systemctl disable --now x3-mixer.timer 2>/dev/null || true
systemctl stop x3-mixer.service 2>/dev/null || true
rm -f /etc/systemd/system/x3-mixer.service /etc/systemd/system/x3-mixer.timer

install -d /etc/pipewire/pipewire.conf.d
install -d /etc/pipewire/client.conf.d
install -d /etc/pipewire/pipewire-pulse.conf.d
install -d /etc/wireplumber/wireplumber.conf.d
install -d /etc/NetworkManager/dispatcher.d
install -d /var/lib/sddm/.config/wireplumber/wireplumber.conf.d

# The greeter must never own the X3 or bind the VBAN port. Mask its audio
# units before the card check, then release the card.
if ! id sddm >/dev/null 2>&1; then
    log "sddm user not found; skipping greeter audio mask"
else
    sddm_uid=$(id -u sddm)
    if [[ -d /run/user/$sddm_uid ]]; then
        log "masking the sddm greeter audio units"
        runuser -u sddm -- env XDG_RUNTIME_DIR="/run/user/$sddm_uid" \
            systemctl --user mask "${SDDM_AUDIO_UNITS[@]}"
        for unit in "${SDDM_AUDIO_UNITS[@]}"; do
            record "masked-user sddm $unit"
        done
        log "stopping the sddm greeter audio units"
        runuser -u sddm -- env XDG_RUNTIME_DIR="/run/user/$sddm_uid" \
            systemctl --user stop "${SDDM_AUDIO_UNITS[@]}" || true
    else
        sddm_home=$(getent passwd sddm | cut -d: -f6)
        sddm_mask_dir="$sddm_home/.config/systemd/user"
        log "sddm user manager is not running; writing masks to $sddm_mask_dir"
        install -d "$sddm_mask_dir"
        for unit in "${SDDM_AUDIO_UNITS[@]}"; do
            ln -snf /dev/null "$sddm_mask_dir/$unit"
            record "linked $sddm_mask_dir/$unit"
        done
        chown -R sddm: "$sddm_mask_dir"
    fi
fi

log "restarting the user audio stack"
as_user systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 2

log "setting the X3 card to pro-audio"
card=$(as_user pactl list cards short | awk '/Creative/ {print $2; exit}')
if [[ -z $card ]]; then
    echo "Creative card not found. Is the X3 plugged in?" >&2
    exit 1
fi
as_user pactl set-card-profile "$card" pro-audio

log "installing the host configs"
render "$REPO/configs/unified-upmix-sink.conf" /etc/pipewire/pipewire.conf.d/unified-upmix-sink.conf
render "$REPO/configs/vban-recv.conf" /etc/pipewire/pipewire.conf.d/vban-recv.conf
link_config "$REPO/configs/pipewire-pulse-upmix.conf" /etc/pipewire/pipewire-pulse.conf.d/upmix.conf
link_config "$REPO/configs/client-upmix.conf" /etc/pipewire/client.conf.d/upmix.conf
link_config "$REPO/configs/61-vban-route.conf" /etc/wireplumber/wireplumber.conf.d/61-vban-route.conf

copy_file "$REPO/configs/51-sddm-no-alsa.conf" /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-alsa.conf

link_config "$REPO/configs/alsa-restore-delayed.service" /etc/systemd/system/alsa-restore-delayed.service
link_config "$REPO/configs/alsa-restore-delayed.timer" /etc/systemd/system/alsa-restore-delayed.timer

render "$REPO/configs/99-restart-pipewire" /etc/NetworkManager/dispatcher.d/99-restart-pipewire 755

systemctl daemon-reload
enable_unit alsa-restore-delayed.timer

log "restarting the audio stack with the new config"
as_user systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 2
as_user pactl set-default-sink unified-upmix
as_user pactl set-sink-volume unified-upmix 100%

log "restoring the X3 mixer"
# The PipeWire restart re-inits the card and resets the mixer, so restore
# the saved levels after the restart.
systemctl start alsa-restore-delayed.service
record "unit-started alsa-restore-delayed.service"

log "host setup complete; run: sudo make doctor"
