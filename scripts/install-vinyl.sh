#!/usr/bin/env bash
# Install vinyl-toggle into the user's bin directory.
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_root vinyl
start_manifest vinyl

install -d "$USER_HOME/bin"
copy_file "$REPO/bin/vinyl-toggle" "$USER_HOME/bin/vinyl-toggle" 755
chown "$USER_NAME:$USER_NAME" "$USER_HOME/bin/vinyl-toggle"

echo "Installed $USER_HOME/bin/vinyl-toggle"
