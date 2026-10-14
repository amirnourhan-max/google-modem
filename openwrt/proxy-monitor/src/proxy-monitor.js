'use strict';
'require baseclass';
'require rpc';

var callStatus = rpc.declare({ object: 'proxy-monitor', method: 'status', expect: { '': {} } });
var callExitRefresh = rpc.declare({ object: 'proxy-monitor', method: 'exit_refresh', expect: { '': {} } });
var exitChecking = false;
var isoCodes = 'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW';
var cachedStatus = {}, lastRefresh = -Infinity, inFlight = null;
function fetchStatus(force) {
    if (inFlight) return inFlight;
    if (!force && Date.now() - lastRefresh < 30000) return Promise.resolve(cachedStatus);
    inFlight = callStatus().then(function(d) {
        return d && !Array.isArray(d) && typeof d === 'object' && d.backend_version === 15 ? d : {};
    }).catch(function() { return {}; }).then(function(d) {
        cachedStatus = d; lastRefresh = Date.now(); return d;
    }).finally(function() { inFlight = null; });
    return inFlight;
}
function state(value, yes, no) {
    return E('span', { 'class': 'pm-badge' }, [
        typeof value === 'boolean' ? (value ? yes : no) : _('UNKNOWN')
    ]);
}
function text(value, limit) {
    return typeof value === 'string' && value.length && value.length <= (limit || 1024) ? value : _('UNKNOWN');
}
function field(label, value, technical) {
    return E('div', { 'class': 'pm-field' }, [
        E('span', { 'class': 'pm-label' }, [ label ]),
        E('span', { 'class': 'pm-value', 'dir': technical ? 'ltr' : 'auto' }, [value == null ? _('UNKNOWN') : value])
    ]);
}
function card(title, items, id) {
    var attrs = { 'class': 'cbi-section pm-card' };
    if (id) attrs.id = id;
    return E('section', attrs, [E('h3', {}, [title]), E('div', {}, items)]);
}
function countryText(c) {
    c = c && typeof c === 'object' ? c : {};
    var code = typeof c.code === 'string' && /^[A-Z]{2}$/.test(c.code) && (' ' + isoCodes + ' ').indexOf(' ' + c.code + ' ') >= 0 ? c.code : '';
    var flag = code ? String.fromCodePoint(0x1f1e6 + code.charCodeAt(0) - 65, 0x1f1e6 + code.charCodeAt(1) - 65) : '🌐';
    return E('span', { 'dir': 'auto' }, [ flag + ' ' + (code ? text(c.name,128) + ' (' + code + ')' : _('UNKNOWN')),
        c.source === 'inferred' ? ' — ' + _('inferred from node name') : c.source === 'metadata' ? ' — ' + _('configured server country') : '' ]);
}
function balancerNodes(d) {
    var nodes = Array.isArray(d.balancer_nodes) ? d.balancer_nodes.slice(0,128) : [];
    var rows = nodes.map(function(n) {
        n = n && typeof n === 'object' ? n : {};
        return E('div', { 'class': 'pm-node' }, [
            E('strong', { 'dir': 'auto' }, [text(n.name)]),
            E('div', { 'dir': 'auto' }, [ _('Subscription group') + ': ' + text(n.group,512) ]),
            E('div', {}, [countryText(n.country)]),
            n.available === false ? E('span', { 'class': 'pm-badge' }, [_('UNAVAILABLE')]) : ''
        ]);
    });
    return card(_('Active Balancer Nodes'), [
        E('p', {}, [_('Configured members; the exact node serving a connection is not observable.')]),
        E('div', {}, rows.length ? rows : [_('UNKNOWN / no configured members available')]),
        d.balancer_nodes_supported === false ? E('p', {}, [_('UNAVAILABLE: unsupported node-selection schema')]) : '',
        d.balancer_nodes_truncated === true ? E('p', {}, [_('List limited to 128 members')]) : ''
    ], 'proxy-monitor-nodes');
}
function checkTime(value) {
    return typeof value === 'number' && Number.isInteger(value) && value > 0 ? new Date(value * 1000).toLocaleString() : _('UNKNOWN');
}
function exitCard(d, refreshExit) {
    var x = d.proxy_exit && typeof d.proxy_exit === 'object' ? d.proxy_exit : {};
    var last = x.last_success && typeof x.last_success === 'object' ? x.last_success : {};
    var states = { OK: _('Successful last check'), CHECK_FAILED: _('Last check failed'),
        INVALID_RESPONSE: _('Invalid IP response'), UNAVAILABLE: _('UNAVAILABLE'), NOT_CHECKED: _('Not checked'), CHECKING: _('Checking') };
    var reasons = { SOCKS_ROUTE_UNVERIFIED: _('No existing SOCKS route proven to avoid DIRECT; a Shunt or direct fallback cannot certify a proxy exit.'),
        DEPENDENCY_MISSING: _('Optional curl with HTTPS/SOCKS and ucode-mod-uloop are required for manual checks.'),
        HTTPS_OR_SOCKS_FAILED: _('HTTPS or SOCKS failed; no direct-WAN fallback was used.'), BAD_ECHO: _('The endpoint did not return a valid global IP address.') };
    return card(_('Proxy Exit IP'), [
        E('p', {}, [_('Observed proxy exit IP — last check')]),
        field(_('Public IPv4 / IPv6'), text(last.ip,45), true),
        field(_('Exit IP country'), countryText(last.country)),
        field(_('Last successful check'), checkTime(last.checked_at)),
        field(_('Connection status'), exitChecking ? states.CHECKING : states[x.state] || _('UNKNOWN')),
        field(_('Last attempt'), checkTime(x.checked_at)),
        field(_('Route used for last successful check'), text(last.route,192), true),
        last.ip && x.geo_state !== 'OK' ? E('p', {}, [_('Country lookup unavailable; the IP check and geolocation are separate.')]) : '',
        reasons[x.reason] ? E('p', {}, [reasons[x.reason]]) : '',
        E('button', { 'type': 'button', 'class': 'cbi-button cbi-button-action', 'disabled': exitChecking ? '' : null,
            'click': function() { return refreshExit(); } }, [_('Check proxy exit IP')]),
        E('p', { 'class': 'pm-help' }, [_('Manual check only. leastLoad may use different nodes for different connections; this is not a permanent exit or an active-node identification. Cached observations survive failed checks until reboot.')])
    ], 'proxy-monitor-exit');
}
function installStyles() {
    if (document.getElementById('proxy-monitor-theme-style')) return;
    // Native section/button styling owns colors and typography. Bootstrap tokens
    // are confirmed upstream; older/other themes fall back to inherited styling.
    document.head.appendChild(E('style', { 'id': 'proxy-monitor-theme-style' }, [
        '#proxy-monitor{color:inherit;font-family:inherit;max-width:100%;overflow-wrap:anywhere}' +
        '#proxy-monitor .pm-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1rem}' +
        '#proxy-monitor .pm-card{min-width:0;margin:0;padding:1rem;box-sizing:border-box;border:1px solid var(--border-color-medium,rgba(127,127,127,.4));border-radius:.3rem}' +
        '#proxy-monitor .pm-card h3{color:inherit;margin:0 0 .8rem;font-size:1.05rem}' +
        '#proxy-monitor .pm-field{display:flex;justify-content:space-between;align-items:flex-start;gap:1rem;padding:.5rem 0;border-bottom:1px solid var(--border-color-low,rgba(127,127,127,.3))}' +
        '#proxy-monitor .pm-field:last-child{border-bottom:0}' +
        '#proxy-monitor .pm-value{min-width:0;max-width:65%;text-align:end;overflow-wrap:anywhere;font-weight:600;unicode-bidi:isolate}' +
        '#proxy-monitor .pm-badge{display:inline-block;font-size:.9em;border:1px solid currentColor;border-radius:.3rem;padding:.1rem .4rem;color:inherit}' +
        '#proxy-monitor .pm-header{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;gap:1rem;margin-bottom:1rem}' +
        '#proxy-monitor .pm-help{margin-top:1rem;line-height:1.6}' +
        '#proxy-monitor .pm-node{padding:.65rem 0;border-bottom:1px solid var(--border-color-low,rgba(127,127,127,.3));line-height:1.7;unicode-bidi:isolate}' +
        '#proxy-monitor .pm-node:last-child{border-bottom:0}' +
        '#proxy-monitor-nodes{grid-column:1/-1}' +
        '@media(max-width:600px){#proxy-monitor .pm-grid{grid-template-columns:minmax(0,1fr)}#proxy-monitor .pm-field{flex-wrap:wrap;gap:.3rem}#proxy-monitor .pm-value{max-width:100%}}'
    ]));
}
function panel(d, refreshExit) {
    d = d || {};
    var enabled = state(d.passwall_enabled, _('Enabled in UCI'), _('Disabled in UCI'));
    var sing = state(d.singbox_running, _('Running'), d.singbox_installed === true ? _('Inactive / standby') : _('UNAVAILABLE'));
    var xray = state(d.xray_running, _('Running'), d.xray_installed === true ? _('Stopped / inactive') : _('UNAVAILABLE'));
    return E('div', { 'class': 'pm-grid' }, [
        balancerNodes(d), exitCard(d, refreshExit),
        card(_('Proxy services'), [
            field('Passwall2', enabled, true), field(_('Passwall2 procd instance'), state(d.passwall_running, _('Running'), _('Stopped')), true),
            field('Xray', xray, true), field('sing-box', sing, true),
            field(_('Selected profile'), text(d.selected_name)), field(_('Core configured'), text(d.selected_type), true)
        ]),
        card(_('Routing configuration'), [
            field(_('Shunt ID'), text(d.shunt_id), true), field(_('Balancer ID'), text(d.balancer_id), true),
            field(_('Balancer strategy'), text(d.balancer_strategy), true),
            field(_('Iran rule'), state(d.iran_direct, _('DIRECT configured'), _('Other route configured'))),
            field(_('Private/LAN rule'), state(d.private_direct, _('DIRECT configured'), _('Other route configured'))),
            field(_('Exact active balancer node'), _('UNKNOWN'), true)
        ]),
        card(_('DNS process indicators'), [
            field('https-dns-proxy', state(d.encrypted_dns_process, _('Running'), _('Stopped')), true),
            field('SmartDNS', state(d.smartdns_process, _('Running'), _('Stopped')), true),
            field('dnsmasq', state(d.dnsmasq_process, _('Running'), _('Stopped')), true)
        ]),
        card(_('Recovery and shared health'), [
            field(_('Watchdog scheduled + crond'), state(d.watchdog_active, _('Scheduled'), _('Not confirmed'))),
            field(_('Resilience mode'), text(d.resilience_mode), true),
            field(_('Failure counter'), typeof d.failure_count === 'number' && Number.isInteger(d.failure_count) && d.failure_count >= 0 ? '' + d.failure_count : _('UNKNOWN'), true),
            field(_('Last published recovery event'), text(d.last_recovery_event), true),
            field(_('RGB LED published state'), text(d.led_state), true),
            field(_('RGB LED procd instance'), state(d.led_service_running, _('Running'), _('Stopped')), true),
            field(_('Shared health (published, ≤180s)'), text(d.shared_health), true)
        ])
    ]);
}
return baseclass.extend({
    title: _('Proxy Monitor'),
    load: function() {
        if (document.hidden || this.hide) return Promise.resolve(cachedStatus);
        return fetchStatus(false);
    },
    render: function(d) {
        installStyles();
        // Overview owns polling/rendering. Return the same DOM root to avoid
        // duplicate handlers, timers and widget IDs on its frequent ticks.
        if (this.content) { this.update(d); return this.content; }
        var self = this;
        this.lastData = d;
        var body = E('div', { 'id': 'proxy-monitor-panel' }, [panel(d, refreshExit)]);
        var content = E('div', { 'id': 'proxy-monitor' }, [
            E('div', { 'class': 'pm-header' }, [
                E('button', { 'type': 'button', 'class': 'cbi-button cbi-button-action', 'click': function() { return refresh(); } }, [_('Refresh status')])]),
            body,
            E('p', { 'class': 'pm-help' }, [_('Local read-only indicators; configuration and process presence do not prove connectivity. Shared health is published by the existing watchdog. No traffic sampling or automatic connectivity probes. Status refresh: 30 seconds while visible; external IP checks require the separate manual button.')])
        ]);
        this.update = function(result) {
            if (self.lastData === result) return;
            self.lastData = result;
            while (body.firstChild) body.removeChild(body.firstChild);
            body.appendChild(panel(result, refreshExit));
        };
        function refresh() {
            return fetchStatus(true).then(function(result) { self.update(result); });
        }
        function refreshExit() {
            if (exitChecking) return Promise.resolve();
            exitChecking = true;
            self.lastData = null; self.update(cachedStatus);
            return callExitRefresh().then(function(result) {
                var x = result && result.proxy_exit && typeof result.proxy_exit === 'object' ? result.proxy_exit : { state: 'CHECK_FAILED' };
                cachedStatus = Object.assign({}, cachedStatus, {proxy_exit:x});
            }).catch(function() {
                cachedStatus = Object.assign({}, cachedStatus, {proxy_exit:Object.assign({}, cachedStatus.proxy_exit || {}, {state:'CHECK_FAILED'})});
            }).finally(function() { exitChecking = false; self.lastData = null; self.update(cachedStatus); });
        }
        this.content = content;
        return content;
    }
});
