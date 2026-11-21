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

card=$(as_user pactl list cards short | awk '/Creative/ {print $2; exit}')
if [[ -z $card ]]; then
    echo "Creative card not found. Is the X3 plugged in?" >&2
    exit 1
fi
as_user pactl set-card-profile "$card" pro-audio

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

as_user systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 2
as_user pactl set-default-sink unified-upmix
as_user pactl set-sink-volume unified-upmix 100%

# The PipeWire restart re-inits the card and resets the mixer, so restore
# the saved levels after the restart.
systemctl start alsa-restore-delayed.service
record "unit-started alsa-restore-delayed.service"

echo "Host setup complete. Run: make doctor"
