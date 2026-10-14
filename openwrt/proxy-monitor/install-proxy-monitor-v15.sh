#!/bin/sh
# Proxy Monitor v15 - offline, lightweight LuCI installation for OpenWrt.
# Owns only the files listed here; does not change routing, firewall or proxy services.
set -eu

HELPER=/usr/libexec/proxy-monitor-status
VIEW=/www/luci-static/resources/view/services/proxy-monitor.js
MENU=/usr/share/luci/menu.d/luci-app-proxy-monitor.json
ACL=/usr/share/rpcd/acl.d/luci-app-proxy-monitor.json
OLD0=/www/luci-static/resources/view/status/include/00_proxy-monitor.js
OLD75=/www/luci-static/resources/view/status/include/75_proxy-monitor.js
TRAFFIC=/usr/libexec/proxy-monitor-traffic

if [ "$(id -u)" -ne 0 ]; then
	echo "ERROR: root is required"; exit 1
fi
if ! command -v ucode >/dev/null 2>&1; then
	echo "ERROR: ucode is required; no changes made"; exit 1
fi
B=/root/recovery/proxy-monitor-v15-$(date +%Y%m%d-%H%M%S)
mkdir -p "$B/originals"
for p in "$HELPER" "$VIEW" "$MENU" "$ACL" "$OLD0" "$OLD75" "$TRAFFIC"; do
	if [ -f "$p" ]; then
		mkdir -p "$B/originals$(dirname "$p")"
		cp -p "$p" "$B/originals$p"
	fi
done

cat > "$B/rollback.sh" <<'ROLLBACK'
#!/bin/sh
set -eu
B="$(CDPATH= cd "$(dirname "$0")" && pwd)"
for p in \
 /usr/libexec/proxy-monitor-status \
 /www/luci-static/resources/view/services/proxy-monitor.js \
 /usr/share/luci/menu.d/luci-app-proxy-monitor.json \
 /usr/share/rpcd/acl.d/luci-app-proxy-monitor.json \
 /www/luci-static/resources/view/status/include/00_proxy-monitor.js \
 /www/luci-static/resources/view/status/include/75_proxy-monitor.js \
 /usr/libexec/proxy-monitor-traffic
do
	if [ -f "$B/originals$p" ]; then
		mkdir -p "$(dirname "$p")"
		cp -p "$B/originals$p" "$p"
	else
		rm -f "$p"
	fi
done
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart
echo "Proxy Monitor restored from: $B"
ROLLBACK
chmod 0700 "$B/rollback.sh"

mkdir -p "$(dirname "$HELPER")" "$(dirname "$VIEW")" "$(dirname "$MENU")" "$(dirname "$ACL")"

cat > "$HELPER" <<'UCODE'
#!/usr/bin/ucode
'use strict';

/* Read-only, local-only status source. No bandwidth counters, ping or HTTP probes. */
import * as fs from 'fs';

function command(cmd) {
	let p = fs.popen(cmd, 'r');
	if (!p) return '';
	let s = p.read('all') || '';
	p.close();
	return trim(s);
}
function read(path) {
	let f = fs.open(path, 'r');
	if (!f) return '';
	let s = f.read('all') || '';
	f.close();
	return trim(s);
}
function exists(path) { return !!fs.stat(path); }
function process_running(name) {
	if (!match(name, /^[A-Za-z0-9_-]+$/)) return false;
	return command('pidof ' + name + ' 2>/dev/null') != '';
}
function uci_node(id, property) {
	if (!match(id, /^[A-Za-z0-9_-]+$/) || !match(property, /^[A-Za-z0-9_-]+$/))
		return '';
	return command('uci -q get passwall2.' + id + '.' + property + ' 2>/dev/null');
}
function safe_state(s) {
	if (!match(s, /^[A-Za-z0-9_-]{1,40}$/)) return 'unknown';
	return s;
}

let selected = command("uci -q get 'passwall2.@global[0].node' 2>/dev/null");
let enabled = command("uci -q get 'passwall2.@global[0].enabled' 2>/dev/null") == '1';
let proto = uci_node(selected, 'protocol');
let balancer = (proto == '_shunt') ? uci_node(selected, 'default_node') : (proto == '_balancing' ? selected : '');
let strategy = uci_node(balancer, 'balancingStrategy') || uci_node(balancer, 'strategy') || 'unknown';
let counter = read('/root/recovery/always-on-watchdog.state');
if (!match(counter, /^[0-9]{1,8}$/)) counter = 'unknown';
let cron = read('/etc/crontabs/root');
let watchdog = index(cron, '/root/recovery/internet-watchdog.sh') >= 0 &&
               !exists('/root/recovery/watchdog.disabled');
let mode = safe_state(read('/root/recovery/resilience-mode'));
let led = safe_state(read('/var/run/internet-led-status/state'));
if (led == 'unknown') led = safe_state(read('/var/run/internet-led-status/current'));
let xray = process_running('xray');
let sing = process_running('sing-box');
let doh = process_running('https-dns-proxy');
let smart = process_running('smartdns');
let dnsmasq = process_running('dnsmasq');

printf('%J\n', {
	backend_version: 15,
	passwall_enabled: enabled,
	xray_running: xray,
	singbox_running: sing,
	singbox_installed: exists('/usr/bin/sing-box') || exists('/usr/sbin/sing-box'),
	selected_node: selected,
	selected_name: uci_node(selected, 'remarks') || selected,
	selected_protocol: proto,
	balancer_id: balancer,
	balancer_name: uci_node(balancer, 'remarks') || balancer,
	balancer_strategy: strategy,
	iran_direct: uci_node(selected, 'Iran') == '_direct',
	private_direct: uci_node(selected, 'PrivateIP') == '_direct',
	encrypted_dns_process: doh,
	smartdns_process: smart,
	dnsmasq_process: dnsmasq,
	watchdog_active: watchdog,
	failure_count: counter,
	resilience_mode: mode,
	led_state: led,
	shared_health_available: exists('/var/run/internet-health/state')
});
UCODE
chmod 0755 "$HELPER"

cat > "$VIEW" <<'LUCIJS'
'use strict';
'require view';
'require fs';
'require poll';

var refreshSeconds = 30;

function fetchStatus() {
	return L.resolveDefault(fs.exec_direct('/usr/libexec/proxy-monitor-status', [], 'json'), {});
}

function statusText(ok, yes, no) {
	return ok ? yes : no;
}

function statusBadge(label, ok, neutral) {
	return E('span', { 'class': 'pm-badge ' + (neutral ? 'pm-neutral' : ok ? 'pm-good' : 'pm-bad') }, [ label ]);
}

function field(label, value) {
	return E('div', { 'class': 'pm-field' }, [
		E('span', { 'class': 'pm-label' }, [ label ]),
		E('span', { 'class': 'pm-value' }, [ value == null || value === '' ? '—' : String(value) ])
	]);
}

function card(title, items) {
	return E('section', { 'class': 'cbi-section pm-card' }, [
		E('h3', { 'class': 'pm-heading' }, [ title ]),
		E('div', { 'class': 'pm-rows' }, items)
	]);
}

function installStyles() {
	if (document.getElementById('proxy-monitor-theme-style')) return;
	var css = [
		'#proxy-monitor{color:inherit;max-width:100%;overflow-wrap:anywhere}',
		'#proxy-monitor .pm-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:12px}',
		'#proxy-monitor .pm-card{min-width:0;margin:0;padding:14px;border:1px solid var(--border-color,rgba(127,127,127,.30));background:var(--background-color,transparent);color:inherit;border-radius:10px;box-sizing:border-box}',
		'#proxy-monitor .pm-heading{font-size:1.05rem;margin:0 0 12px;font-weight:650;color:inherit}',
		'#proxy-monitor .pm-field{display:flex;gap:12px;justify-content:space-between;align-items:start;border-bottom:1px solid var(--border-color,rgba(127,127,127,.2));padding:8px 0;min-width:0}',
		'#proxy-monitor .pm-field:last-child{border-bottom:0}',
		'#proxy-monitor .pm-label{opacity:.72;min-width:0}',
		'#proxy-monitor .pm-value{font-weight:600;text-align:end;overflow-wrap:anywhere;min-width:0;unicode-bidi:plaintext}',
		'#proxy-monitor .pm-badge{display:inline-block;border-radius:999px;padding:3px 9px;border:1px solid currentColor;font-size:.9em}',
		'#proxy-monitor .pm-good{color:var(--success-color,#14853b)}',
		'#proxy-monitor .pm-bad{color:var(--danger-color,#b43434)}',
		'#proxy-monitor .pm-neutral{color:inherit;opacity:.72}',
		'#proxy-monitor .pm-header{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;gap:10px;margin:0 0 15px}',
		'#proxy-monitor .pm-help{margin:13px 0 0;opacity:.72;font-size:.92em;line-height:1.5}',
		'@media(max-width:600px){#proxy-monitor .pm-field{flex-direction:column;gap:3px}#proxy-monitor .pm-value{text-align:start}}'
	].join('\n');
	document.head.appendChild(E('style', { 'id':'proxy-monitor-theme-style', 'type':'text/css' }, [ css ]));
}

function panel(d) {
	d = d || {};
	var currentCore = [
		field(_('Passwall2'), statusBadge(statusText(d.passwall_enabled, _('Enabled'), _('Disabled')), d.passwall_enabled)),
		field(_('Xray'), statusBadge(statusText(d.xray_running, _('Running'), _('Stopped')), d.xray_running)),
		field(_('sing-box'), d.singbox_running ?
			statusBadge(_('Running'), true) :
			statusBadge(d.singbox_installed ? _('Standby') : _('Not installed'), false, true)),
		field(_('Selected profile'), d.selected_name || _('Unknown')),
		field(_('Profile type'), d.selected_protocol || _('Unknown'))
	];
	var routing = [
		field(_('Iran rule'), statusBadge(d.iran_direct ? _('DIRECT configured') : _('Unverified'), d.iran_direct, !d.iran_direct)),
		field(_('Private/LAN'), statusBadge(d.private_direct ? _('DIRECT configured') : _('Unverified'), d.private_direct, !d.private_direct)),
		field(_('Balancer'), d.balancer_name || _('Not detected')),
		field(_('Balancing strategy'), d.balancer_strategy || _('Unknown'))
	];
	var dns = [
		field(_('Encrypted DNS process'), statusBadge(d.encrypted_dns_process ? _('Running') : _('Stopped'), d.encrypted_dns_process)),
		field(_('SmartDNS process'), statusBadge(d.smartdns_process ? _('Running') : _('Stopped'), d.smartdns_process)),
		field(_('dnsmasq process'), statusBadge(d.dnsmasq_process ? _('Running') : _('Stopped'), d.dnsmasq_process))
	];
	var recovery = [
		field(_('Watchdog'), statusBadge(d.watchdog_active ? _('Active') : _('Disabled'), d.watchdog_active)),
		field(_('Resilience mode'), d.resilience_mode || _('Unknown')),
		field(_('Consecutive failures'), d.failure_count || _('Unknown')),
		field(_('LED state'), d.led_state || _('Unknown')),
		field(_('Shared health data'), d.shared_health_available ? _('Available') : _('Unavailable'))
	];
	return E('div', { 'class':'pm-grid' }, [
		card(_('Proxy cores'), currentCore),
		card(_('Routing'), routing),
		card(_('Local DNS services'), dns),
		card(_('Automatic recovery'), recovery)
	]);
}

return view.extend({
	load: fetchStatus,
	render: function(d) {
		installStyles();
		var content = E('div', { 'id':'proxy-monitor' }, [
			E('div', { 'class':'pm-header' }, [
				E('h2', {}, [ _('Proxy Monitor') ]),
				E('button', {
					'class':'cbi-button cbi-button-action',
					'type':'button',
					'click':function() { return refresh(); }
				}, [ _('Refresh status') ])
			]),
			E('div', { 'id':'proxy-monitor-panel' }, [ panel(d) ]),
			E('p', { 'class':'pm-help' }, [
				_('Read-only monitoring. Values are local process/configuration indicators, not proof of successful internet access. Connectivity probes are owned by the existing watchdog. No upload/download collection is performed.')
			])
		]);
		function refresh() {
			return fetchStatus().then(function(result) {
				var el = content.querySelector('#proxy-monitor-panel');
				if (el) el.replaceChildren(panel(result));
			});
		}
		poll.add(function() {
			if (document.hidden || !document.body.contains(content)) return Promise.resolve();
			return refresh();
		}, refreshSeconds);
		return content;
	}
});

LUCIJS
chmod 0644 "$VIEW"

cat > "$MENU" <<'JSONMENU'
{
  "admin/services/proxy-monitor": {
    "title": "Proxy Monitor",
    "order": 80,
    "action": { "type": "view", "path": "services/proxy-monitor" },
    "depends": { "acl": [ "luci-app-proxy-monitor" ] }
  }
}
JSONMENU

cat > "$ACL" <<'JSONACL'
{
  "luci-app-proxy-monitor": {
    "description": "Read-only Proxy Monitor status",
    "read": {
      "cgi-io": [ "exec" ],
      "file": { "/usr/libexec/proxy-monitor-status": [ "exec" ] },
      "ubus": { "file": [ "exec" ] }
    }
  }
}
JSONACL

# Remove legacy overview injection and bandwidth collector, not system traffic accounting.
rm -f "$OLD0" "$OLD75" "$TRAFFIC"

# Validate status output before refreshing LuCI; failure restores the previous deployment.
if ! "$HELPER" | grep -q '"backend_version":15'; then
	echo "ERROR: status backend validation failed; restoring original files..."
	"$B/rollback.sh"
	exit 1
fi
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart
echo "Proxy Monitor v15 installed: Services > Proxy Monitor"
echo "Removed per-second Rx/Tx sampling, traffic cards, and live node ping loops."
echo "Backup and rollback: $B/rollback.sh"
echo "No proxy, DNS, firewall, SSH or wireless service was restarted."
