#!/bin/sh
# Existing Android 2.11 accepts a URL containing ?token=..., no APK change needed.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
reply() {
    printf 'Status: %s\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n%s\n' "$1" "$2"
}
[ "${REQUEST_METHOD:-}" = GET ] || { reply '405 Method Not Allowed' '{"error":"GET only"}'; exit 0; }
case "${REMOTE_ADDR:-}" in
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|127.*|::1|fd*|fe80:*) ;;
    *) reply '403 Forbidden' '{"error":"LAN only"}'; exit 0 ;;
esac
TOKEN="$(cat /etc/proxy-monitor/mobile-token 2>/dev/null)"
[ "${#TOKEN}" -eq 64 ] || { reply '503 Service Unavailable' '{"error":"API token unavailable"}'; exit 0; }
case "$TOKEN" in *[!a-f0-9]*) reply '503 Service Unavailable' '{"error":"API token invalid"}'; exit 0 ;; esac
case "&${QUERY_STRING:-}&" in
    *"&token=$TOKEN&"*) ;;
    *) reply '403 Forbidden' '{"error":"Authentication required"}'; exit 0 ;;
esac
DATA="$(/usr/libexec/proxy-monitor-status --mobile 2>/dev/null)" || {
    reply '503 Service Unavailable' '{"error":"Status unavailable"}'; exit 0;
}
[ -n "$DATA" ] || { reply '503 Service Unavailable' '{"error":"Status unavailable"}'; exit 0; }
if ! printf '%s\n' "$DATA" | /usr/bin/ucode -e 'import * as fs from "fs"; try { let d=json(fs.stdin.read("all")); exit(d.api_version == 7 && type(d.status) == "object" && type(d.traffic) == "object" ? 0 : 1); } catch(e) { exit(1); }'; then
    reply '503 Service Unavailable' '{"error":"Invalid status response"}'; exit 0;
fi
reply '200 OK' "$DATA"
