#!/usr/bin/ucode
'use strict';
import * as fs from 'fs';
import { cursor } from 'uci';

// Only fixed local commands. UCI values are never shell arguments.
function command(cmd) {
    let p = fs.popen(cmd, 'r');
    if (!p) return '';
    let out = p.read(262144) || '';
    let rc = p.close();
    return rc == 0 ? trim(out) : '';
}
function read(path, limit) {
    let s = fs.stat(path);
    if (!s || s.type != 'file' || s.size > (limit || 4096)) return '';
    let f = fs.open(path, 'r');
    if (!f) return '';
    let out = f.read(limit || 4096) || '';
    f.close();
    return trim(out);
}
function object(raw) {
    try { let d = json(raw); return type(d) == 'object' ? d : {}; }
    catch (e) { return {}; }
}
function id(s) { return type(s) == 'string' && match(s, /^[A-Za-z0-9_]{1,64}$/) ? s : ''; }
function label(s, fallback) {
    // Remarks are display metadata, never URLs, credentials or configuration dumps.
    if (type(s) != 'string' || length(s) > 96 || match(s, /[[:cntrl:]:\/@=]/)) return fallback;
    return s || fallback;
}
function enum_value(s, allowed) { return index(allowed, s) >= 0 ? s : 'UNKNOWN'; }
function flag(s) { return s == '1' ? true : s == '0' ? false : null; }
function number(s) {
    return type(s) == 'string' && match(s, /^[0-9]{1,8}$/) ? int(s) : null;
}

// Native read-only UCI. Calling uci.get over ubus from a synchronous rpcd
// ucode callback would recurse into the same daemon and can deadlock.
let values = {};
let ctx = cursor();
try { values = ctx.get_all('passwall2') || {}; }
catch (e) { values = {}; }
ctx.unload('passwall2');
if (type(values) != 'object') values = {};
let global = {};
let apps = {};
for (let key, val in values)
    if (type(val) == 'object' && val['.type'] == 'global' &&
        (global['.index'] == null || val['.index'] < global['.index'])) global = val;
for (let key, val in values)
    if (type(val) == 'object' && val['.type'] == 'global_app' &&
        (apps['.index'] == null || val['.index'] < apps['.index'])) apps = val;
let selected = id(global.node) || id(global.tcp_node);
let node = type(values[selected]) == 'object' ? values[selected] : {};
let protocol = enum_value(node.protocol, ['_shunt', '_balancing', '_iface', 'vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http', 'hysteria2', 'tuic', 'wireguard']);
let candidate = protocol == '_shunt' ? id(node.default_node) : protocol == '_balancing' ? selected : '';
let balancer = type(values[candidate]) == 'object' && values[candidate].protocol == '_balancing' ? candidate : '';
let balance = balancer ? values[balancer] : {};
let core = enum_value(node.type, ['Xray', 'Sing-Box', 'sing-box']);

// One /proc scan per request; no stored PID, probing or continuous collector.
let procs = fs.glob('/proc/[0-9]*/comm');
let names = {};
for (let path in (procs || [])) {
    let name = read(path, 128);
    if (name) names[name] = true;
}
let proc_observable = !!read('/proc/self/comm', 128) && length(keys(names)) > 0;
function executable_path(s) {
    return type(s) == 'string' && match(s, /^\/[A-Za-z0-9_.+\/-]{1,255}$/) ? s : '';
}
function running(name, custom) {
    if (!proc_observable) return null;
    let parts = split(executable_path(custom), '/');
    return !!names[name] || !!names[parts[length(parts) - 1]];
}
function installed(name, custom) {
    if (executable_path(custom) && fs.access(custom, 'x')) return true;
    for (let dir in ['/usr/bin/', '/usr/sbin/', '/bin/', '/sbin/'])
        if (fs.access(dir + name, 'x')) return true;
    return false;
}
// Native rpcd callbacks are synchronous; bound the other-daemon request so
// unavailable procd cannot stall LuCI for the CLI's default 30-second timeout.
let services = object(command('/bin/ubus -t 1 call service list 2>/dev/null'));
function service_running(name) {
    if (type(services[name]) != 'object' || type(services[name].instances) != 'object') return null;
    let observed = 0;
    let unknown = false;
    for (let key, inst in services[name].instances) {
        if (type(inst) == 'object' && type(inst.running) == 'bool') {
            if (inst.running) return true;
            observed++;
        }
        else unknown = true;
    }
    return observed > 0 && !unknown ? false : null;
}
let passwall_running = service_running('passwall2');
let health_path = '/var/run/internet-health/state';
let health_raw = read(health_path);
let health = object(health_raw);
let hs = fs.stat(health_path);
let age = hs ? max(0, time() - hs.mtime) : null;
let health_state = enum_value(health.status || health.state || health_raw, ['healthy', 'ok', 'online', 'degraded', 'offline', 'failed']);
if (age == null || age > 180) health_state = 'UNKNOWN';
let cron = read('/etc/crontabs/root', 65536);
let scheduled = false;
for (let line in split(cron, '\n')) {
    line = trim(split(line, '#')[0]);
    if (index(split(line, /[ \t]+/), '/root/recovery/internet-watchdog.sh') >= 0)
        scheduled = true;
}
let watchdog = scheduled && !fs.stat('/root/recovery/watchdog.disabled') && running('crond') == true;
let event = enum_value(health.last_event, ['recovered', 'proxy_restart', 'dns_restart', 'fallback_enabled', 'fallback_disabled', 'cooldown', 'healthy']);
let led = enum_value(read('/var/run/internet-led-status/state') || read('/var/run/internet-led-status/current'), ['green', 'red', 'blue', 'yellow', 'orange', 'off', 'online', 'offline', 'healthy', 'degraded']);

let result = {
    backend_version: 15, schema_version: 1, sampled_at: time(),
    passwall_enabled: flag(global.enabled), passwall_running: passwall_running,
    xray_running: running('xray', apps.xray_file), xray_installed: installed('xray', apps.xray_file),
    singbox_running: running('sing-box', apps.sing_box_file), singbox_installed: installed('sing-box', apps.sing_box_file),
    selected_node: selected, selected_name: label(node.remarks, selected),
    selected_protocol: protocol, selected_type: core,
    shunt_id: protocol == '_shunt' ? selected : '',
    balancer_id: balancer, balancer_name: label(balance.remarks, balancer),
    balancer_strategy: enum_value(balance.balancingStrategy || balance.strategy, ['random', 'roundRobin', 'leastPing', 'leastLoad']),
    iran_direct: protocol == '_shunt' && type(node.Iran) == 'string' ? node.Iran == '_direct' : null,
    private_direct: protocol == '_shunt' && type(node.PrivateIP) == 'string' ? node.PrivateIP == '_direct' : null,
    encrypted_dns_process: running('https-dns-proxy'), smartdns_process: running('smartdns'), dnsmasq_process: running('dnsmasq'),
    watchdog_active: cron ? watchdog : null, watchdog_scheduled: cron ? scheduled : null,
    failure_count: number(read('/root/recovery/always-on-watchdog.state')),
    resilience_mode: enum_value(read('/root/recovery/resilience-mode'), ['normal', 'fallback', 'degraded', 'emergency', 'extreme', 'zapret2']),
    led_state: led, led_service_running: service_running('internet-led-status'),
    shared_health: health_state, shared_health_age: age,
    last_recovery_event: event,
    // Legacy Android 2.11 fields: unknown observations remain empty, never invented.
    selected_remark: label(node.remarks, selected), public_ip: '', country_code: '',
    expected_nodes: 0, active_nodes: [], balancers: []
};
if (ARGV[0] == '--mobile')
    printf('%J\n', { api_version: 7, status: result,
        traffic: { available: false, device: '', rx_bytes: 0, tx_bytes: 0 }, server_time: time() });
else printf('%J\n', result);
