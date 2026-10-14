#!/bin/sh
# One manual check, never a daemon. Bound every child output file (32 KiB).
umask 077
ulimit -f 32 || exit 1
exec /usr/bin/ucode /usr/libexec/proxy-monitor-exit-check.uc
