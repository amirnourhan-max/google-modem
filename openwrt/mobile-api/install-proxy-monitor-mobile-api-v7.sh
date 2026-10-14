#!/bin/sh
# Companion v15 installer must be copied to the same directory.
set -eu
BASE="$(CDPATH= cd "$(dirname "$0")" && pwd)"
INSTALLER="$BASE/install-proxy-monitor-v15.sh"
[ -f "$INSTALLER" ] || { echo 'Copy install-proxy-monitor-v15.sh beside this file first.'; exit 1; }
exec sh "$INSTALLER" --mobile-api
