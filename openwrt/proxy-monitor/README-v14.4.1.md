# Proxy Monitor — stable v14.4.1

This directory contains the active LuCI installer, the Android-compatible router endpoint restoration installer, and one retained rollback baseline.

## Current files

- `install-proxy-monitor-v14.4.1.sh` — LuCI Status → Overview; three top cards, active node estimation, LuCI-compatible background; no Download/Upload card, Runtime Details, or browser-side traffic sampling. **Reinstalling LuCI does not remove Android's on-demand traffic helper.**
- `restore-android-api-v6-for-v14.4.sh` — restores the original Android-facing `/cgi-bin/proxy-monitor-mobile` v6 response contract, including `?fresh=1`, `status.active_nodes` and on-demand traffic counters; no tokens or Android APK changes. Backs up its old API and helper under `/root/recovery/` with a rollback script.
- `install-proxy-monitor-v14.3.sh` — preserved legacy baseline for recovery only.

The superseded `install-proxy-monitor-v14.4.sh` and experimental token-only `fix-android-api-v14.4.sh` were removed from this development branch to prevent accidental deployment of conflicting versions. They remain in Git history.

## Deployment

Repository is private: use GitHub authenticated **Download raw** followed by SFTP via Termius, not anonymous wget.

```sh
sh -n /tmp/install-proxy-monitor-v14.4.1.sh
sh -n /tmp/restore-android-api-v6-for-v14.4.sh

# Only if an installation or recovery is needed, not when the system is already working:
sh /tmp/install-proxy-monitor-v14.4.1.sh
sh /tmp/restore-android-api-v6-for-v14.4.sh
```

The LuCI installer restarts **rpcd** and **uhttpd**; the mobile API restoration does not restart either. Neither intentionally restarts Passwall2, Xray, WAN, SSH, Wi-Fi, or the watchdog.

## Verification (read-only)

```sh
sh -n /tmp/install-proxy-monitor-v14.4.1.sh
sh -n /tmp/restore-android-api-v6-for-v14.4.sh
/usr/libexec/proxy-monitor-status
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/cgi-bin/proxy-monitor-mobile
```

A `200` indicates the Android endpoint answered on loopback. On the existing Android APK, keep the same router URL (`http://192.168.28.1/cgi-bin/proxy-monitor-mobile`) and refresh.

## Safety and limitations

- No Android source, APK, widget, screen, or stored settings need to change; **do not remove Android Upload/Download** just because LuCI no longer displays them.
- The Android traffic helper is executed on-demand, not polled by the LuCI Overview.
- Active node selection is an estimate using current observed connections, *not* authoritative proof of a balancer's exact Xray backend.
- The legacy API uses LAN source-IP restriction but no authentication. Ensure uhttpd is not exposed on WAN, especially with port forwards or IPv6; a private address alone is not equivalent to authentication.
- Do not delete router backups, v15 snapshots, or change `main` during source cleanup.
- Source is organized and the changes are committed, but actual runtime success depends on the current router; do not claim verification without checking the live status/Android refresh.
