#!/bin/sh
set -eu

HELPER="/usr/libexec/proxy-monitor-status"
TRAFFIC="/usr/libexec/proxy-monitor-traffic"
ACL="/usr/share/rpcd/acl.d/luci-app-proxy-monitor.json"
VIEW="/www/luci-static/resources/view/status/include/00_proxy-monitor.js"
OLD_VIEW="/www/luci-static/resources/view/status/include/75_proxy-monitor.js"

rm -f "$OLD_VIEW"

cat > "$HELPER" <<'UCODE'
#!/usr/bin/ucode
'use strict';

import * as fs from 'fs';

function run(cmd) {
	let p = fs.popen(cmd, 'r');
	if (!p)
		return '';

	let out = p.read('all') || '';
	p.close();
	return trim(out);
}

function read_json(path) {
	let f = fs.open(path, 'r');
	if (!f)
		return null;

	let raw = f.read('all') || '';
	f.close();

	if (!raw)
		return null;

	try {
		return json(raw);
	}
	catch (e) {
		return null;
	}
}

function parse_json_text(raw) {
	if (!raw)
		return null;

	try {
		return json(raw);
	}
	catch (e) {
		return null;
	}
}

function shellquote(s) {
	return "'" + replace(s || '', /'/g, "'\\''") + "'";
}

function clean_node_name(tag) {
	if (!tag)
		return '';

	let i = index(tag, ':');
	if (i >= 0 && i + 1 < length(tag))
		return substr(tag, i + 1);

	return tag;
}

function endpoint_from_outbound(o) {
	if (!o || type(o) != 'object' || !o.settings || type(o.settings) != 'object')
		return null;

	let s = o.settings;

	if (type(s.vnext) == 'array' && length(s.vnext) > 0 && type(s.vnext[0]) == 'object')
		return { address: s.vnext[0].address || '', port: int(s.vnext[0].port || 0) };

	if (type(s.servers) == 'array' && length(s.servers) > 0 && type(s.servers[0]) == 'object')
		return { address: s.servers[0].address || '', port: int(s.servers[0].port || 0) };

	if (s.address)
		return { address: s.address || '', port: int(s.port || 0) };

	return null;
}

function is_proxy_proto(p) {
	return p == 'vless' || p == 'vmess' || p == 'trojan' ||
	       p == 'shadowsocks' || p == 'socks' || p == 'http';
}

function parse_ep(s) {
	/* IPv4 only; sufficient for the current PassWall2 nodes shown on this router */
	let m = match(s, /^([0-9.]+):([0-9]+)$/);
	if (!m)
		return null;

	return { ip: m[1], port: int(m[2]) };
}

function resolve4(host) {
	if (!host)
		return [];

	if (match(host, /^[0-9.]+$/))
		return [ host ];

	let cmd =
		"nslookup " + shellquote(host) + " 2>/dev/null | " +
		"awk '/^Address [0-9]+: / {print $3} /^Address: / {print $2}' | " +
		"grep -E '^[0-9]+(\\.[0-9]+){3}$' | sort -u | head -n8";

	let text = run(cmd);
	let ips = [];

	for (let line in split(text, /\n/)) {
		line = trim(line);
		if (line)
			push(ips, line);
	}

	return ips;
}

function latency_ms(ip, port) {
	if (!ip || !port)
		return '';

	/* Prefer PassWall2's tcping: it measures the actual TCP service port. */
	let t = run("if command -v tcping >/dev/null 2>&1; then tcping -p " + port + " -c 1 -t 1 " + shellquote(ip) + " 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\) ms.*/\\1/p' | head -n1; fi");
	if (t)
		return t;

	/* Fallback only when tcping is unavailable or the port probe fails. */
	t = run("ping -4 -c1 -W1 " + shellquote(ip) + " 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p' | head -n1");
	return t || '';
}

function unquote_uci(v) {
	if (!v)
		return '';

	v = trim(v);
	if (length(v) >= 2 && substr(v, 0, 1) == "'" && substr(v, length(v) - 1, 1) == "'")
		return substr(v, 1, length(v) - 2);

	return v;
}

function load_uci_nodes() {
	let text = run("uci -q show passwall2 2>/dev/null");
	let nodes = {};

	for (let line in split(text, /\n/)) {
		line = trim(line);
		if (!line)
			continue;

		let sm = match(line, /^passwall2\.([^.=]+)=nodes$/);
		if (sm && sm[1]) {
			nodes[sm[1]] = nodes[sm[1]] || {};
			continue;
		}

		let om = match(line, /^passwall2\.([^.=]+)\.([^=]+)=(.*)$/);
		if (!om || !om[1] || !nodes[om[1]])
			continue;

		nodes[om[1]][om[2]] = unquote_uci(om[3] || '');
	}

	return nodes;
}

function find_subscription_group(uci_nodes, name, address, port) {
	let best_group = '';
	let best_score = -1;

	for (let id in keys(uci_nodes)) {
		let n = uci_nodes[id];
		if (!n || type(n) != 'object')
			continue;

		let score = 0;
		if (n.remarks && name && n.remarks == name)
			score += 8;
		if (n.address && address && n.address == address)
			score += 4;
		if (n.port && port && int(n.port) == int(port))
			score += 2;

		if (score >= 6 && score > best_score) {
			best_score = score;
			best_group = n.group || '';
		}
	}

	return best_group;
}

let xray_pid = run("pidof xray 2>/dev/null | awk '{print $1}'");
let sing_pid = run("pidof sing-box 2>/dev/null | awk '{print $1}'");

let cfgpath = '/tmp/etc/passwall2/acl/acl_default.json';
if (!fs.stat(cfgpath))
	cfgpath = run("find /tmp/etc/passwall2/acl -type f -name '*.json' -size +0c 2>/dev/null | head -n1");

let cfg = cfgpath ? read_json(cfgpath) : null;

let selected_id = run("uci -q get passwall2.@global[0].tcp_node 2>/dev/null");
if (!selected_id)
	selected_id = run("uci -q get passwall2.@global[0].node 2>/dev/null");

let selected_remark = selected_id ? run("uci -q get passwall2." + selected_id + ".remarks 2>/dev/null") : '';
let selected_type = selected_id ? run("uci -q get passwall2." + selected_id + ".type 2>/dev/null") : '';
let selected_protocol = selected_id ? run("uci -q get passwall2." + selected_id + ".protocol 2>/dev/null") : '';

let public_ip = run("wget -4 -q -T 4 -O- https://api.ipify.org 2>/dev/null | head -c 64");
if (!match(public_ip, /^[0-9.]+$/))
	public_ip = '';

let country_code = '';

if (public_ip) {
	let geo_raw = run("wget -4 -q -T 4 -O- 'https://api.country.is/" + public_ip + "' 2>/dev/null");
	let geo = parse_json_text(geo_raw);

	if (geo && type(geo) == 'object' && geo.country)
		country_code = uc(geo.country);
}

let xray_version = run("if [ -x /tmp/etc/passwall2/bin/xray ]; then /tmp/etc/passwall2/bin/xray version 2>/dev/null | head -n1; elif command -v xray >/dev/null 2>&1; then xray version 2>/dev/null | head -n1; fi");
let sing_version = run("if [ -x /tmp/etc/passwall2/bin/sing-box ]; then /tmp/etc/passwall2/bin/sing-box version 2>/dev/null | head -n1; elif command -v sing-box >/dev/null 2>&1; then sing-box version 2>/dev/null | head -n1; fi");

let balancers = [];

if (cfg && cfg.routing && type(cfg.routing) == 'object' && type(cfg.routing.balancers) == 'array') {
	for (let b in cfg.routing.balancers) {
		if (!b || type(b) != 'object')
			continue;

		let strategy = '';
		let expected = null;

		if (b.strategy && type(b.strategy) == 'object') {
			strategy = b.strategy.type || '';
			if (b.strategy.settings && type(b.strategy.settings) == 'object' &&
			    b.strategy.settings.expected != null)
				expected = b.strategy.settings.expected;
		}

		push(balancers, { strategy: strategy, expected: expected });
	}
}

/* Live TCP endpoints owned by Xray / Sing-Box. */
let ep_text = run(
	"if command -v ss >/dev/null 2>&1; then " +
	"ss -Hntp 2>/dev/null | awk '/xray|sing-box/ {print $5}' | sort -u | head -n20; " +
	"elif command -v netstat >/dev/null 2>&1; then " +
	"netstat -ntp 2>/dev/null | awk '/xray|sing-box/ {print $5}' | sort -u | head -n20; fi"
);

let live_eps = [];

for (let line in split(ep_text, /\n/)) {
	line = trim(line);
	let ep = parse_ep(line);
	if (ep)
		push(live_eps, ep);
}

/*
 * Map live endpoint IP:port back to Xray outbounds.
 * This avoids requiring Xray RoutingService API.
 */
let active_nodes = [];
let seen_nodes = {};
let latency_cache = {};
let endpoint_counts = {};
let expected_nodes = 0;
let uci_nodes = load_uci_nodes();

if (length(balancers) > 0 && balancers[0].expected != null)
	expected_nodes = int(balancers[0].expected);

if (expected_nodes <= 0)
	expected_nodes = 3;

if (cfg && type(cfg.outbounds) == 'array' && length(live_eps) > 0) {
	for (let o in cfg.outbounds) {
		if (!o || type(o) != 'object' || !is_proxy_proto(o.protocol))
			continue;

		let tag = o.tag || '';
		let name = clean_node_name(tag);

		/* Skip metadata/helper outbounds which are not useful node names. */
		if (!name || index(tag, 'User:') >= 0 || name == 'Reality' || name == 'reality' || name == 'Default' || name == 'default')
			continue;

		let ep = endpoint_from_outbound(o);
		if (!ep || !ep.address || !ep.port)
			continue;

		let relevant = false;
		for (let live in live_eps) {
			if (live.port == ep.port) {
				relevant = true;
				break;
			}
		}
		if (!relevant)
			continue;

		let ips = resolve4(ep.address);
		let matched_ip = '';

		for (let live in live_eps) {
			if (live.port != ep.port)
				continue;

			for (let ip in ips) {
				if (live.ip == ip) {
					matched_ip = live.ip;
					break;
				}
			}

			if (matched_ip)
				break;
		}

		if (!matched_ip)
			continue;

		let endpoint_key = matched_ip + ':' + ep.port;
		let node_key = name + '|' + endpoint_key;

		if (seen_nodes[node_key])
			continue;

		seen_nodes[node_key] = true;
		endpoint_counts[endpoint_key] = (endpoint_counts[endpoint_key] || 0) + 1;

		if (latency_cache[endpoint_key] == null)
			latency_cache[endpoint_key] = latency_ms(matched_ip, ep.port);

		push(active_nodes, {
			name: name,
			group: find_subscription_group(uci_nodes, name, ep.address, ep.port),
			ip: matched_ip,
			port: ep.port,
			endpoint: endpoint_key,
			ping_ms: latency_cache[endpoint_key]
		});
	}
}

/* Add ambiguity counts after all candidates are known. */
for (let n in active_nodes)
	n.ambiguity = endpoint_counts[n.endpoint] || 1;

printf("%J\n", {
	public_ip: public_ip,
	country_code: country_code,
	xray_running: !!xray_pid,
	singbox_running: !!sing_pid,
	xray_version: xray_version,
	singbox_version: sing_version,
	selected_remark: selected_remark,
	selected_type: selected_type,
	selected_protocol: selected_protocol,
	balancers: balancers,
	expected_nodes: expected_nodes,
	active_nodes: active_nodes
});
UCODE

chmod 0755 "$HELPER"

# v14.4 no traffic collector.
rm -f "$TRAFFIC"

mkdir -p /usr/share/rpcd/acl.d
cat > "$ACL" <<'JSON'
{
  "luci-app-proxy-monitor": {
    "description": "Allow reading Proxy Monitor status",
    "read": {
      "cgi-io": [ "exec" ],
      "file": {
        "/usr/libexec/proxy-monitor-status": [ "exec" ]
      },
      "ubus": {
        "file": [ "exec" ]
      }
    }
  }
}
JSON

cat > "$VIEW" <<'JAVASCRIPT'
'use strict';
'require baseclass';
'require fs';
'require poll';

function callStatus() {
	return L.resolveDefault(fs.exec_direct('/usr/libexec/proxy-monitor-status', [], 'json'), {});
}

// Traffic sampling removed.

var refreshSeconds = 30;
var countdown = refreshSeconds;
var countdownLabel = null;

function updateCountdownLabel() {
	if (countdownLabel)
		countdownLabel.textContent = 'Auto refresh: ' + countdown + 's';
}

function resetCountdown() {
	countdown = refreshSeconds;
	updateCountdownLabel();
}

function style(obj) {
	return Object.keys(obj).map(function(k) { return k + ':' + obj[k]; }).join(';');
}

function card(icon, title, content, sub, accent) {
	return E('div', {
		'style': style({
			background: 'var(--background-color,transparent)',
			border: '1px solid rgba(255,255,255,.08)',
			'box-shadow': '0 10px 28px rgba(0,0,0,.25)',
			'border-radius': '18px', padding: '15px', position: 'relative', overflow: 'hidden',
			'min-height': '132px'
		})
	}, [
		E('div', { 'style': style({ position:'absolute', top:'0', left:'0', right:'0', height:'3px', background:accent || '#5b8cff' }) }),
		E('div', { 'style': 'display:flex;align-items:flex-start;gap:12px' }, [
			E('div', { 'style': 'width:42px;height:42px;border-radius:14px;display:flex;align-items:center;justify-content:center;background:rgba(255,255,255,.06);color:#fff;font-size:21px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.05);flex-shrink:0' }, [ icon ]),
			E('div', { 'style': 'min-width:0;flex:1' }, [
				E('div', { 'style': 'font-size:12px;font-weight:800;letter-spacing:.06em;color:var(--text-color,inherit);text-transform:uppercase;margin-bottom:7px' }, [ title ]),
				E('div', { 'style': 'font-size:20px;font-weight:850;color:var(--text-color,inherit);line-height:1.22;margin-bottom:6px;word-break:break-word' }, Array.isArray(content) ? content : [ content || '-' ]),
				E('div', { 'style': 'font-size:12px;color:var(--text-color,inherit);line-height:1.45' }, (sub && typeof(sub) === 'object') ? [ sub ] : [ sub || '' ])
			])
		])
	]);
}

function badge(text, ok) {
	var bg = ok ? 'rgba(22,163,74,.16)' : 'rgba(239,68,68,.16)';
	var fg = ok ? '#86efac' : '#fca5a5';
	var bd = ok ? 'rgba(34,197,94,.28)' : 'rgba(248,113,113,.28)';
	return E('span', { 'style': 'display:inline-block;padding:6px 11px;border-radius:999px;font-weight:800;font-size:13px;background:' + bg + ';color:' + fg + ';border:1px solid ' + bd + ';margin:0 7px 7px 0' }, [ text ]);
}

function profileText(d) {
	var p = [];
	if (d.selected_remark) p.push(d.selected_remark);
	if (d.selected_type) p.push(d.selected_type);
	if (d.selected_protocol) p.push(d.selected_protocol);
	return p.length ? p.join(' — ') : 'Not detected';
}

function balancerText(d) {
	if (!Array.isArray(d.balancers) || !d.balancers.length)
		return 'Fixed / Shunt';
	return d.balancers.map(function(b) {
		var s = b.strategy || 'unknown';
		if (b.expected != null) s += ' / expected=' + b.expected;
		return s;
	}).join(' | ');
}

function flagAndIp(d) {
	var out = [];
	var cc = (d.country_code || '').toLowerCase();
	if (cc) out.push(E('img', { 'src':'https://flagcdn.com/24x18/' + cc + '.png', 'alt':d.country_code, 'width':'24', 'height':'18', 'style':'vertical-align:middle;margin-right:8px;border-radius:2px;box-shadow:0 0 0 1px rgba(255,255,255,.12)' }));
	out.push(E('code', { 'style':'font-size:15px;padding:4px 8px;border-radius:9px;background:rgba(255,255,255,.06);border:1px solid var(--border-color,rgba(127,127,127,.28));color:var(--text-color,inherit)' }, [ d.public_ip || 'Unavailable' ]));
	if (d.country_code) out.push(E('span', { 'style':'margin-left:8px;color:var(--text-color,inherit);font-weight:700;font-size:13px' }, [ '(' + d.country_code + ')' ]));
	return out;
}

function cleanDisplayName(name) {
	var s = String(name || '').trim();
	if (!s) return '';
	if (/^reality$/i.test(s) || /cBqRmK-Bot/i.test(s) || /^user\s*:/i.test(s)) return '';
	/* Strip recurring subscription owner suffixes while keeping the real node title. */
	s = s.replace(/\s*[🌐👤:✅]+\s*amir60gig.*$/i, '');
	s = s.replace(/\s*amir60gig.*$/i, '');
	s = s.replace(/[\s:•|\-]+$/g, '').trim();
	return s;
}

function countryCodeFromNodeName(name) {
	var m = String(name || '').match(/(?:^|[^A-Za-z])((?:DE|IR|US|TR|NL|FI|FR|GB|UK|CA|AE|UA|RU|SG|JP|KR|HK))(?:[^A-Za-z]|$)/i);
	if (!m || !m[1]) return '';
	var cc = String(m[1]).toUpperCase();
	return cc === 'UK' ? 'GB' : cc;
}

function nodeTone(cc) {
	var tones = {
		DE:['rgba(245,158,11,.16)','rgba(245,158,11,.36)','#fde68a'], IR:['rgba(34,197,94,.16)','rgba(34,197,94,.34)','#bbf7d0'],
		US:['rgba(59,130,246,.16)','rgba(59,130,246,.34)','#bfdbfe'], TR:['rgba(244,63,94,.16)','rgba(244,63,94,.34)','#fecdd3'],
		NL:['rgba(96,165,250,.16)','rgba(96,165,250,.34)','#bfdbfe'], FI:['rgba(6,182,212,.16)','rgba(6,182,212,.34)','#a5f3fc'],
		FR:['rgba(129,140,248,.16)','rgba(129,140,248,.34)','#c7d2fe'], GB:['rgba(168,85,247,.16)','rgba(168,85,247,.34)','#ddd6fe']
	};
	return tones[cc] || ['rgba(148,163,184,.14)','rgba(148,163,184,.26)','#e2e8f0'];
}

function pingSpec(ms) {
	var n = parseFloat(ms);
	if (!isFinite(n)) return { text:'—', bg:'rgba(148,163,184,.13)', bd:'rgba(148,163,184,.25)', fg:'#cbd5e1', dot:'#94a3b8', rank:999999 };
	if (n < 100) return { text:n.toFixed(0) + ' ms', bg:'rgba(34,197,94,.15)', bd:'rgba(34,197,94,.35)', fg:'#bbf7d0', dot:'#22c55e', rank:n };
	if (n <= 200) return { text:n.toFixed(0) + ' ms', bg:'rgba(245,158,11,.15)', bd:'rgba(245,158,11,.35)', fg:'#fde68a', dot:'#f59e0b', rank:n };
	return { text:n.toFixed(0) + ' ms', bg:'rgba(239,68,68,.15)', bd:'rgba(239,68,68,.35)', fg:'#fecaca', dot:'#ef4444', rank:n };
}

function selectEstimatedNodes(d) {
	var raw = Array.isArray(d.active_nodes) ? d.active_nodes : [];
	var expected = parseInt(d.expected_nodes || 3, 10);
	if (!isFinite(expected) || expected < 1) expected = 3;
	if (expected > 8) expected = 8;

	var bestByEndpoint = {};
	raw.forEach(function(item) {
		if (typeof(item) === 'string') item = { name:item, endpoint:item, ping_ms:'' };
		var name = cleanDisplayName(item.name);
		if (!name) return;
		var endpoint = item.endpoint || ((item.ip || '') + ':' + (item.port || '')) || name;
		var p = pingSpec(item.ping_ms);
		var current = bestByEndpoint[endpoint];
		var candidate = { name:name, group:String(item.group || ''), endpoint:endpoint, ping_ms:item.ping_ms, ambiguity:parseInt(item.ambiguity || 1,10), rank:p.rank };
		/* When multiple labels share the same CDN endpoint, keep one concise representative. */
		if (!current || candidate.rank < current.rank || (candidate.rank === current.rank && candidate.name.length < current.name.length))
			bestByEndpoint[endpoint] = candidate;
	});

	var nodes = Object.keys(bestByEndpoint).map(function(k) { return bestByEndpoint[k]; });
	nodes.sort(function(a,b) { return a.rank - b.rank; });
	return nodes.slice(0, expected);
}

function pingBadge(ms) {
	var p = pingSpec(ms);
	return E('span', { 'style':'margin-left:9px;padding:3px 8px;border-radius:999px;background:' + p.bg + ';border:1px solid ' + p.bd + ';font-size:11px;font-weight:850;color:' + p.fg + ';white-space:nowrap;display:inline-flex;align-items:center;gap:5px' }, [
		E('span', { 'style':'width:6px;height:6px;border-radius:50%;background:' + p.dot + ';display:inline-block' }), p.text
	]);
}

function nodePills(d) {
	var items = selectEstimatedNodes(d);
	if (!items.length) return [ E('span', { 'style':'color:var(--text-color,inherit)' }, [ 'No live proxy node detected — open a proxied site and wait about 10 seconds.' ]) ];
	return items.map(function(item, idx) {
		var cc = countryCodeFromNodeName(item.name);
		var t = nodeTone(cc);
		var kids = [ E('span', { 'style':'font-size:11px;font-weight:900;opacity:.65;margin-right:8px' }, [ '#' + (idx + 1) ]) ];
		if (cc) kids.push(E('img', { 'src':'https://flagcdn.com/20x15/' + cc.toLowerCase() + '.png', 'alt':cc, 'width':'20', 'height':'15', 'style':'vertical-align:middle;margin-right:8px;border-radius:2px;box-shadow:0 0 0 1px rgba(255,255,255,.08)' }));
		kids.push(E('span', { 'style':'font-weight:850' }, [ item.name ]));
		if (item.group) kids.push(E('span', { 'style':'margin-left:7px;font-size:10px;font-weight:800;color:var(--text-color,inherit);opacity:.95;white-space:nowrap' }, [ '(' + item.group + ')' ]));
		kids.push(pingBadge(item.ping_ms));
		return E('span', { 'style':'display:inline-flex;align-items:center;padding:9px 12px;margin:0 8px 8px 0;border-radius:999px;background:' + t[0] + ';border:1px solid ' + t[1] + ';color:' + t[2] + ';box-shadow:0 4px 14px rgba(0,0,0,.14);max-width:100%;word-break:break-word' }, kids);
	});
}

function infoRow(label, value, icon) {
	return E('div', { 'style':'display:flex;gap:14px;padding:10px 0;border-bottom:1px solid rgba(255,255,255,.06);align-items:flex-start' }, [
		E('div', { 'style':'width:180px;max-width:180px;color:var(--text-color,inherit);font-weight:800;display:flex;align-items:center;gap:8px;flex-shrink:0' }, [ E('span', {}, [icon || '•']), E('span', {}, [label]) ]),
		E('div', { 'style':'flex:1;color:var(--text-color,inherit);line-height:1.7;word-break:break-word' }, [ value || '-' ])
	]);
}

function refreshPanel(container, button) {
	if (button) {
		button.disabled = true;
		button.textContent = '↻ Refreshing…';
	}

	return callStatus().then(function(d) {
		if (container) {
			while (container.firstChild)
				container.removeChild(container.firstChild);
			container.appendChild(heroPanel(d || {}));
		}
		resetCountdown();
	}).finally(function() {
		if (button) {
			button.disabled = false;
			button.textContent = '↻ Refresh';
		}
	});
}

function refreshNow(ev) {
	if (ev && ev.preventDefault)
		ev.preventDefault();

	var btn = ev && ev.currentTarget ? ev.currentTarget : null;
	var root = document.getElementById('proxy-monitor-status');
	return refreshPanel(root, btn);
}

function heroPanel(d) {
	var expected = parseInt(d.expected_nodes || 3,10) || 3;
	return E('div', { 'style':'background:var(--background-color,transparent);border:1px solid var(--border-color,rgba(127,127,127,.28));border-radius:22px;padding:18px;box-shadow:0 16px 40px rgba(0,0,0,.28);margin:8px 0 12px 0' }, [
		E('div', { 'style':'display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:16px' }, [
			E('div', {}, [ E('div', { 'style':'font-size:30px;font-weight:900;color:var(--text-color,inherit);line-height:1.1' }, [ 'Proxy Monitor' ]), E('div', { 'style':'color:var(--text-color,inherit);font-size:13px;margin-top:5px' }, [ 'LuCI theme • lightweight node status' ]) ]),
			E('div', { 'style':'display:flex;align-items:center;gap:8px;flex-wrap:wrap' }, [ E('button', { 'type':'button', 'class':'cbi-button cbi-button-action', 'style':'font-size:12px;color:var(--text-color,inherit);background:rgba(59,130,246,.14);border:1px solid rgba(96,165,250,.28);padding:7px 11px;border-radius:999px;cursor:pointer;font-weight:800', 'click':refreshNow }, [ '↻ Refresh' ]), E('div', { 'id':'proxy-monitor-countdown', 'style':'font-size:12px;color:var(--text-color,inherit);background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.07);padding:7px 10px;border-radius:999px;min-width:108px;text-align:center;font-variant-numeric:tabular-nums' }, [ 'Auto refresh: ' + countdown + 's' ]) ])
		]),
		E('div', { 'style':'display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:14px;margin-bottom:16px' }, [
			card('🌍','Public IPv4',flagAndIp(d),'Current router exit IP and detected country','linear-gradient(90deg,#3b82f6,#22c55e)'),
			card('⚡','Proxy Core',[ badge(d.xray_running ? 'Xray RUNNING' : 'Xray stopped',!!d.xray_running), badge(d.singbox_running ? 'Sing-Box RUNNING' : 'Sing-Box stopped',!!d.singbox_running) ],'Live runtime status','linear-gradient(90deg,#22c55e,#16a34a)'),
			card('🧭','PassWall2 Profile',profileText(d),'Selected profile / core / shunt mode','linear-gradient(90deg,#8b5cf6,#6366f1)'),
		]),
		E('div', { 'style':'background:var(--background-color,transparent);border:1px solid rgba(255,255,255,.07);border-radius:18px;padding:16px;box-shadow:inset 0 1px 0 rgba(255,255,255,.03);margin-bottom:14px' }, [
			E('div', { 'style':'display:flex;align-items:center;gap:10px;margin-bottom:10px' }, [
				E('div', { 'style':'width:34px;height:34px;border-radius:12px;background:rgba(59,130,246,.16);display:flex;align-items:center;justify-content:center;font-size:18px' }, [ '📡' ]),
				E('div', {}, [ E('div', { 'style':'font-size:15px;font-weight:900;color:var(--text-color,inherit)' }, [ 'Estimated Active Node(s)' ]), E('div', { 'style':'font-size:12px;color:var(--text-color,inherit)' }, [ 'Top live-matched endpoints, limited by expected=' + expected + '. TCP ping: green <100 ms, yellow 100–200 ms, red >200 ms.' ]) ])
			]),
			E('div', { 'style':'margin-top:8px' }, nodePills(d)),
			E('div', { 'style':'font-size:11px;color:var(--text-color,inherit);margin-top:7px;line-height:1.5' }, [ 'Note: without Xray RoutingService API, CDN/shared endpoints can make exact leastLoad selection unobservable. This panel therefore shows the strongest live-match estimate instead of claiming an exact selection.' ])
		]),
	]);
}

return baseclass.extend({
	title: _('Proxy Monitor'),
	load: callStatus,
	render: function(data) {
		countdown = refreshSeconds;
		var c = E('div', { 'id':'proxy-monitor-status' }, [ heroPanel(data || {}) ]);

		countdownLabel = c.querySelector ? c.querySelector('#proxy-monitor-countdown') : null;
		updateCountdownLabel();

		poll.add(function() {
            if (document.hidden || !document.body.contains(c)) return Promise.resolve();
            countdown--;
            if (countdown <= 0) {
                countdown = refreshSeconds;
                return refreshPanel(c, null).then(function() {
                    countdownLabel = c.querySelector('#proxy-monitor-countdown');
                    updateCountdownLabel();
                });
            }
            countdownLabel = c.querySelector('#proxy-monitor-countdown');
            updateCountdownLabel();
            return Promise.resolve();
        }, 1);

		return c;
	}
});
JAVASCRIPT

rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

echo
echo "Proxy Monitor v14.4 installed."
echo "Bandwidth collector and Runtime Details removed; theme-adaptive background."
echo "It still does NOT require Xray RoutingService API. Exact balancer selection may be ambiguous on shared CDN endpoints, so the UI labels the result as an estimate."
echo
echo "Diagnostic:"
echo "  /usr/libexec/proxy-monitor-status"

echo
echo "Refresh LuCI -> Status -> Overview. Proxy Monitor should now appear above System."
