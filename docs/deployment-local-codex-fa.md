# دستور کار Codex CLI محلی ویندوز

Work به LAN دسترسی ندارد. متن زیر و SHA نهایی تحویل را به Codex محلی داخل LAN بدهید:

```text
Deploy the tested Proxy Monitor v15 from amirnourhan-max/google-modem on root@192.168.28.1 using this local Windows LAN access. Continue the EXISTING branch proxy-monitor-luci-theme-lightweight-v15; verify remote HEAD against the final delivery SHA. Read docs/installation-fa.md, docs/compatibility.md and docs/proxy-monitor-v15-audit-fa.md first.

Preserve recoverable local work. Use a fresh local clone if necessary. Do not modify main, recreate the remote branch, rebase, force-push, reset/clean, or change proxy/routing/DNS/watchdog/LED/network/firewall/wireless settings.

Before installation, confirm SSH/host identity, baseline internet/DNS, existing Extreme Internet Resilience and LED health using bounded read-only checks. Keep a second SSH session. Inspect actual watchdog/state schemas without executing repair/restart actions. Expected router: Google WiFi Gale, OpenWrt25.12.5 ARMv7, Passwall2 26.10.1-r2, Xray26.10.10, shunt iran_auto_shunt, balancer29dn9fUB. Stop deployment if management/baseline health cannot be confirmed; investigate read-only instead.

Follow installation-fa.md exact PowerShell transfer and remote/local SHA256 checks, then run the reviewed offline installer. Preserve its private backup and exact rollback path. Do not restart proxy, DNS, watchdog, LED, wireless, network or firewall. Only rpcd is refreshed by the installer.

Verify actual dedicated RPC registration and unauthenticated denial. Open Services > Proxy Monitor in the installed LuCI theme; test light/dark, RTL and mobile widths. Confirm duplicate Status Overview includes and Rx/Tx helper are gone; observe ~30-second visible-only requests. Compare core UCI configuration and router health before/after without printing secrets. If adapter file contracts differ, report UNKNOWN; never fabricate healthy state or modify the watchdog.

If API existed it is now token-authenticated v7. Read token only in the secure local terminal and update Android2.11 URL with ?token=... without recording it in chat/logs/GitHub. Verify unauthorized403, authorized API7/traffic.available=false and actual app/widget Refresh. Public-IP/live-node probes and traffic measurement are intentionally unavailable on the router.

Recheck SSH, internet/DNS and resilience/LED health. On monitor failure execute the exact snapshot rollback.sh and verify restoration. Do not reinstall API6 on top of v15. Report in Persian actual router installation, browser/theme, Android verification, UNKNOWN fields and exact backup/rollback path. Do not claim deployment verified from CLI output alone.
```
