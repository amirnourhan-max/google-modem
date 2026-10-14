#!/bin/sh
# Dedicated read-only rpcd object. No file.exec permission or user command input.
case "${1:-}" in
    list) printf '%s\n' '{"status":{}}' ;;
    call) [ "${2:-}" = status ] || exit 1; exec /usr/libexec/proxy-monitor-status ;;
    *) exit 1 ;;
esac
