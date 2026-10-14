#!/bin/sh
# Restore the original Android v2.11 LAN-only API v6 contract for Proxy Monitor v14.4.
# Does NOT modify any Android source, APK, widgets or settings.
set -eu
umask 077
[ "$(id -u)" = 0 ] || { echo "Run as root"; exit 1; }
API="/www/cgi-bin/proxy-monitor-mobile"
TRAFFIC="/usr/libexec/proxy-monitor-traffic"
HELPER="/usr/libexec/proxy-monitor-status"
CACHE="/tmp/proxy-monitor-mobile-status.json"
LOCK="/tmp/proxy-monitor-mobile-status.lock"
[ -x "$HELPER" ] || { echo "ERROR: Proxy Monitor status helper missing"; exit 1; }
mkdir -p /root/recovery /usr/libexec /www/cgi-bin
B="$(mktemp -d /root/recovery/proxy-monitor-android-v6-XXXXXXXX)"
[ ! -f "$API" ] || cp -p "$API" "$B/api.previous"
[ ! -f "$TRAFFIC" ] || cp -p "$TRAFFIC" "$B/traffic.previous"
cat > "$B/rollback.sh" <<'ROLLBACK'
#!/bin/sh
set -eu
B="$(CDPATH= cd "$(dirname "$0")" && pwd)"
if [ -f "$B/api.previous" ]; then cp -p "$B/api.previous" /www/cgi-bin/proxy-monitor-mobile; else rm -f /www/cgi-bin/proxy-monitor-mobile; fi
if [ -f "$B/traffic.previous" ]; then cp -p "$B/traffic.previous" /usr/libexec/proxy-monitor-traffic; else rm -f /usr/libexec/proxy-monitor-traffic; fi
echo "Previous mobile API and traffic helper restored."
ROLLBACK
chmod 0700 "$B/rollback.sh"
# Legacy bandwidth information remains on-demand for Android only.
# LuCI v14.4.1 has no bandwidth card, sampling loop or collector calls.
cat > "$TRAFFIC" <<'TRAFFIC_SCRIPT'
#!/bin/sh
dev="$(ip -4 route show default 2>/dev/null | awk 'NR==1 { for (i=1; i<=NF; i++) if ($i == "dev") { print $(i+1); exit } }')"
if [ -z "$dev" ] && command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
    for net in wan wwan; do
        dev="$(ubus call "network.interface.$net" status 2>/dev/null | jsonfilter -e '@.l3_device' 2>/dev/null)"
        [ -n "$dev" ] && break
    done
fi
rx=0; tx=0
if [ -n "$dev" ] && [ -r "/sys/class/net/$dev/statistics/rx_bytes" ]; then
    rx="$(cat "/sys/class/net/$dev/statistics/rx_bytes" 2>/dev/null || echo 0)"
    tx="$(cat "/sys/class/net/$dev/statistics/tx_bytes" 2>/dev/null || echo 0)"
fi
case "$rx" in *[!0-9]*|'') rx=0 ;; esac
case "$tx" in *[!0-9]*|'') tx=0 ;; esac
printf '{"device":"%s","rx_bytes":%s,"tx_bytes":%s}\n' "$dev" "$rx" "$tx"
TRAFFIC_SCRIPT
chmod 0755 "$TRAFFIC"

mkdir -p /www/cgi-bin

cat > "$API" <<'CGI'
#!/bin/sh

CACHE="/tmp/proxy-monitor-mobile-status.json"
LOCK="/tmp/proxy-monitor-mobile-status.lock"
CACHE_TTL=10

reply_json() {
    code="$1"
    body="$2"
    printf 'Status: %s\r\n' "$code"
    printf 'Content-Type: application/json; charset=utf-8\r\n'
    printf 'Cache-Control: no-store\r\n'
    printf 'X-Content-Type-Options: nosniff\r\n'
    printf '\r\n'
    printf '%s\n' "$body"
}

refresh_status_cache() {
    tmp="${CACHE}.$$"
    if /usr/libexec/proxy-monitor-status > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv -f "$tmp" "$CACHE"
    else
        rm -f "$tmp"
    fi
    rmdir "$LOCK" 2>/dev/null || true
}

[ "${REQUEST_METHOD:-GET}" = "GET" ] || {
    reply_json '405 Method Not Allowed' '{"error":"GET only"}'
    exit 0
}

FORCE_FRESH=0
case "&${QUERY_STRING:-}&" in
    *'&fresh=1&'*) FORCE_FRESH=1 ;;
esac

# LAN-only safety belt. OpenWrt firewall should already block WAN access to uhttpd,
# but the mobile endpoint also rejects obviously non-private IPv4 callers.
REMOTE="${REMOTE_ADDR:-}"
case "$REMOTE" in
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|127.*|::1|fd*|fe80:*) ;;
    *)
        reply_json '403 Forbidden' '{"error":"LAN only"}'
        exit 0
        ;;
esac

# The full status helper can spend several seconds on public-IP lookups and TCP
# probes. Normal requests use the fast cache; fresh=1 performs one synchronous
# refresh so a user-triggered refresh returns current data.
NOW="$(date +%s)"
MTIME="$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)"
case "$NOW:$MTIME" in *[!0-9:]*|:*) NOW=0; MTIME=0 ;; esac

if [ "$FORCE_FRESH" -eq 1 ]; then
    LOCK_MTIME="$(stat -c %Y "$LOCK" 2>/dev/null || echo 0)"
    case "$LOCK_MTIME" in *[!0-9]*|'') LOCK_MTIME=0 ;; esac
    LOCK_AGE=$((NOW - LOCK_MTIME))
    if [ -d "$LOCK" ] && { [ "$LOCK_MTIME" -eq 0 ] || [ "$LOCK_AGE" -ge 90 ]; }; then
        rmdir "$LOCK" 2>/dev/null || true
    fi

    WAITED=0
    while [ -d "$LOCK" ] && [ "$WAITED" -lt 90 ]; do
        sleep 1
        WAITED=$((WAITED + 1))
    done

    if mkdir "$LOCK" 2>/dev/null; then
        refresh_status_cache
    fi
    STATUS="$(cat "$CACHE" 2>/dev/null || true)"
elif [ -s "$CACHE" ]; then
    STATUS="$(cat "$CACHE" 2>/dev/null || true)"
    AGE=$((NOW - MTIME))

    if [ "$MTIME" -eq 0 ] || [ "$AGE" -ge "$CACHE_TTL" ]; then
        LOCK_MTIME="$(stat -c %Y "$LOCK" 2>/dev/null || echo 0)"
        case "$LOCK_MTIME" in *[!0-9]*|'') LOCK_MTIME=0 ;; esac
        LOCK_AGE=$((NOW - LOCK_MTIME))
        if [ -d "$LOCK" ] && { [ "$LOCK_MTIME" -eq 0 ] || [ "$LOCK_AGE" -ge 90 ]; }; then
            rmdir "$LOCK" 2>/dev/null || true
        fi

        if mkdir "$LOCK" 2>/dev/null; then
            (refresh_status_cache) </dev/null >/dev/null 2>&1 &
        fi
    fi
else
    # Cold-start fallback. The installer normally pre-warms this cache.
    if mkdir "$LOCK" 2>/dev/null; then
        refresh_status_cache
    fi
    STATUS="$(cat "$CACHE" 2>/dev/null || true)"
fi

TRAFFIC="$(/usr/libexec/proxy-monitor-traffic 2>/dev/null || true)"

[ -n "$STATUS" ] || STATUS='{}'
[ -n "$TRAFFIC" ] || TRAFFIC='{}'

printf 'Status: 200 OK\r\n'
printf 'Content-Type: application/json; charset=utf-8\r\n'
printf 'Cache-Control: no-store\r\n'
printf 'X-Content-Type-Options: nosniff\r\n'
printf '\r\n'
printf '{"status":%s,"traffic":%s,"server_time":%s}\n' "$STATUS" "$TRAFFIC" "$(date +%s)"
CGI

chmod 0755 "$API"

echo "Preparing the first status snapshot (this may take a few seconds)..."
TMP="${CACHE}.$$"
if /usr/libexec/proxy-monitor-status > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
    mv -f "$TMP" "$CACHE"
else
    rm -f "$TMP"
fi
rmdir "$LOCK" 2>/dev/null || true

# CGI script is served from existing uhttpd; no network-facing service restart.

LAN_IP="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
[ -n "$LAN_IP" ] || LAN_IP="192.168.28.1"

echo
echo "============================================================="
echo " Proxy Monitor Mobile API v6 installed (no token + manual fresh refresh)"
echo "============================================================="
echo "URL:   http://$LAN_IP/cgi-bin/proxy-monitor-mobile"
echo
echo "Enter the URL in the Android app. No token is required."
echo "No scheduled refresh runs. The app requests fresh data only when you tap Refresh."
echo "Security: keep uhttpd/LuCI closed on WAN; this endpoint is LAN-only."
echo
echo "Remove API:"
echo "  sh $0 uninstall"

echo "Rollback: sh $B/rollback.sh"
