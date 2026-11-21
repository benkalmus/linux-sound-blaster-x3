#!/usr/bin/env bash
# Install the Bluetooth main config, auto-accept agent, and routing.
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_root bluetooth
start_manifest bluetooth

install -d /etc/bluetooth
install -d /etc/wireplumber/wireplumber.conf.d
install -d /var/lib/sddm/.config/wireplumber/wireplumber.conf.d

link_config "$REPO/configs/bluetooth-main.conf" /etc/bluetooth/main.conf
link_config "$REPO/configs/51-no-seat-monitoring.conf" /etc/wireplumber/wireplumber.conf.d/51-no-seat-monitoring.conf
link_config "$REPO/configs/60-bluetooth-route.conf" /etc/wireplumber/wireplumber.conf.d/60-bluetooth-route.conf
copy_file "$REPO/configs/51-sddm-no-bluetooth.conf" /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-bluetooth.conf

link_config "$REPO/bin/bluetooth-auto-agent" /usr/local/bin/bluetooth-auto-agent
link_config "$REPO/bin/bluetooth-toggle" /usr/local/bin/bluetooth-toggle
link_config "$REPO/configs/bluetooth-auto-agent.service" /etc/systemd/system/bluetooth-auto-agent.service

systemctl daemon-reload
enable_unit bluetooth-auto-agent.service
systemctl restart bluetooth
as_user systemctl --user restart wireplumber

echo "Bluetooth setup complete. Toggle with: bluetooth-toggle"
