#!/usr/bin/env bash
# Shared helpers for the install and revert scripts.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../config.conf
source "$REPO/config.conf"

USER_NAME=${SUDO_USER:-$USER}
USER_UID=$(id -u "$USER_NAME")
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

MANIFEST_DIR=/var/lib/linux-sound-blaster-x3
MANIFEST=

require_root() {
    [[ $EUID -eq 0 ]] || { echo "Run: sudo make $1" >&2; exit 1; }
}

as_user() {
    if [[ $EUID -eq 0 ]]; then
        runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR="/run/user/$USER_UID" "$@"
    else
        "$@"
    fi
}

start_manifest() {
    install -d "$MANIFEST_DIR"
    MANIFEST="$MANIFEST_DIR/$1.manifest"
    : > "$MANIFEST"
}

record() {
    printf '%s\n' "$*" >> "$MANIFEST"
}

backup() {
    local dest=$1
    if [[ -e $dest && ! -L $dest ]]; then
        local bak
        bak="$dest.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dest" "$bak"
        record "backup $dest $bak"
    fi
}

link() {
    local src=$1
    local dest=$2
    backup "$dest"
    ln -snf "$src" "$dest"
    record "linked $dest"
}

render() {
    local src=$1
    local dest=$2
    local tmp
    tmp=$(mktemp "$(dirname "$dest")/.render.XXXXXX")
    sed \
        -e "s|@HOST_ADDR@|$HOST_ADDR|g" \
        -e "s|@SENDER_NAME@|$SENDER_NAME|g" \
        -e "s|@VBAN_PORT@|$VBAN_PORT|g" \
        -e "s|@X3_SINK@|$X3_SINK|g" \
        -e "s|@CARD_ID@|$CARD_ID|g" \
        -e "s|@USER_NAME@|$USER_NAME|g" \
        -e "s|@USER_UID@|$USER_UID|g" \
        "$src" > "$tmp"
    chmod 644 "$tmp"
    backup "$dest"
    mv "$tmp" "$dest"
    record "rendered $dest"
}

copy_file() {
    local src=$1
    local dest=$2
    backup "$dest"
    install -m 644 "$src" "$dest"
    record "copied $dest"
}

copy_exec() {
    local src=$1
    local dest=$2
    backup "$dest"
    install -m 755 "$src" "$dest"
    record "copied $dest"
}

enable_unit() {
    local unit=$1
    if systemctl is-enabled --quiet "$unit"; then
        systemctl enable --now "$unit"
        record "unit-was-enabled $unit"
    else
        systemctl enable --now "$unit"
        record "unit-enabled $unit"
    fi
}

start_unit() {
    local unit=$1
    if systemctl is-active --quiet "$unit"; then
        systemctl start "$unit"
        record "unit-was-active $unit"
    else
        systemctl start "$unit"
        record "unit-started $unit"
    fi
}

revert_manifest() {
    local target=$1
    local manifest="$MANIFEST_DIR/$target.manifest"
    if [[ ! -f $manifest ]]; then
        echo "No manifest for $target. Nothing to revert."
        return
    fi
    while read -r kind a _; do
        case $kind in
            unit-enabled)
                systemctl disable --now "$a" || true
                ;;
            unit-started)
                systemctl stop "$a" || true
                ;;
            unit-was-enabled|unit-was-active)
                : # the unit existed before the install; leave it alone
                ;;
            linked|rendered|copied)
                local bak
                bak=$(ls -1t "$a".bak.* 2>/dev/null | head -1 || true)
                if [[ -n $bak ]]; then
                    mv "$bak" "$a"
                else
                    rm -f "$a"
                fi
                ;;
        esac
    done < <(tac "$manifest")
    rm -f "$manifest"
}
