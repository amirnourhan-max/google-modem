#!/bin/sh
# Install lightweight Android API bridge for Proxy Monitor v14.4.
set -eu
umask 077
[ "$(id -u)" = 0 ] || exit 1
API=/www/cgi-bin/proxy-monitor-mobile
HELPER=/usr/libexec/proxy-monitor-status
TOKEN=/etc/proxy-monitor/mobile-token
[ -x "$HELPER" ] || { echo "ERROR: status helper missing"; exit 1; }
command -v ucode >/dev/null 2>&1 || { echo "ERROR: ucode missing"; exit 1; }
mkdir -p /root/recovery /etc/proxy-monitor /www/cgi-bin
B="$(mktemp -d /root/recovery/proxy-monitor-api-XXXXXXXX)"
[ ! -f "$API" ] || cp -p "$API" "$B/api.previous"
if [ -f "$TOKEN" ]; then
  cp -p "$TOKEN" "$B/token.previous"
else
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$TOKEN"
  printf '\n' >> "$TOKEN"
fi
chmod 0600 "$TOKEN"
cat > "$B/rollback.sh" <<'ROLLBACK'
#!/bin/sh
set -eu
B="$(CDPATH= cd "$(dirname "$0")" && pwd)"
if [ -f "$B/api.previous" ]; then cp -p "$B/api.previous" /www/cgi-bin/proxy-monitor-mobile; else rm -f /www/cgi-bin/proxy-monitor-mobile; fi
if [ -f "$B/token.previous" ]; then cp -p "$B/token.previous" /etc/proxy-monitor/mobile-token; else rm -f /etc/proxy-monitor/mobile-token; fi
echo "Previous Android API restored."
ROLLBACK
chmod 0700 "$B/rollback.sh"
cat > "$B/api.new" <<'CGI'
#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
TOKEN=/etc/proxy-monitor/mobile-token
reply() {
 printf 'Status: %s\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n%s\n' "$1" "$2"
}
[ "${REQUEST_METHOD:-GET}" = GET ] || { reply "405 Method Not Allowed" '{"error":"GET required"}'; exit 0; }
case "${REMOTE_ADDR:-}" in
  10.*|192.168.*|127.*|::1|fd*|fe80:*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;;
  *) reply "403 Forbidden" '{"error":"LAN only"}'; exit 0 ;;
esac
secret="$(cat "$TOKEN" 2>/dev/null || true)"
[ "${#secret}" = 64 ] || { reply "503 Service Unavailable" '{"error":"API token unavailable"}'; exit 0; }
case "&${QUERY_STRING:-}&" in
  *"&token=$secret&"*) ;;
  *) reply "403 Forbidden" '{"error":"Token required"}'; exit 0 ;;
esac
STATUS="$(/usr/libexec/proxy-monitor-status 2>/dev/null)" || {
 reply "503 Service Unavailable" '{"error":"Status backend unavailable"}'; exit 0;
}
printf '%s' "$STATUS" | ucode -e 'import * as fs from "fs"; let o=json(fs.stdin.read("all")); exit(type(o)=="object" && type(o.active_nodes)=="array" ? 0 : 1);' >/dev/null 2>&1 || {
 reply "503 Service Unavailable" '{"error":"Invalid status JSON"}'; exit 0;
}
printf 'Status: 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n'
printf '{"status":%s,"traffic":{"available":false,"device":"","rx_bytes":0,"tx_bytes":0},"server_time":%s}\n' "$STATUS" "$(date +%s)"
CGI
sh -n "$B/api.new"
cp "$B/api.new" "$API"
chmod 0755 "$API"
echo "Proxy Monitor v14.4 Android API installed."
echo "Rollback: sh $B/rollback.sh"
echo "Read private token from $TOKEN and append ?token=YOUR_TOKEN to Android URL."
