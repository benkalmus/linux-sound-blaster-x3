#!/usr/bin/env bash
# Install the VBAN sender on the source machine.
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_root sender
start_manifest sender

install -d /etc/pipewire/pipewire.conf.d
install -d /etc/pipewire/client.conf.d
install -d /etc/pipewire/pipewire-pulse.conf.d

render "$REPO/configs/vban-send.conf" /etc/pipewire/pipewire.conf.d/vban-send.conf
link_config "$REPO/configs/pipewire-pulse-upmix.conf" /etc/pipewire/pipewire-pulse.conf.d/upmix.conf
link_config "$REPO/configs/client-upmix.conf" /etc/pipewire/client.conf.d/upmix.conf

install -d "$USER_HOME/.config/systemd/user/pipewire.service.d"
link_config "$REPO/configs/pipewire-recovery.conf" "$USER_HOME/.config/systemd/user/pipewire.service.d/override.conf"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config/systemd/user/pipewire.service.d"

as_user systemctl --user daemon-reload
as_user systemctl --user restart pipewire

echo "Sender setup complete. Route audio to 'Opti VBAN 5.1'."
