#!/usr/bin/env bash
# Undo one target using its install manifest.
set -euo pipefail
source "$(dirname "$0")/common.sh"

target=${1:-}
case $target in
    host|sender|bluetooth|vinyl) ;;
    *) echo "Usage: $0 {host|sender|bluetooth|vinyl}" >&2; exit 1 ;;
esac

require_root "revert-$target"
revert_manifest "$target"
systemctl daemon-reload

case $target in
    host)
        as_user systemctl --user restart pipewire pipewire-pulse wireplumber
        ;;
    sender)
        as_user systemctl --user daemon-reload
        as_user systemctl --user restart pipewire
        ;;
    bluetooth)
        systemctl restart bluetooth
        as_user systemctl --user restart wireplumber
        ;;
esac

echo "Reverted $target."
