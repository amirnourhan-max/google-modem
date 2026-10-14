'use strict';
'require view';
'require rpc';
'require poll';

var callStatus = rpc.declare({ object: 'proxy-monitor', method: 'status', expect: { '': {} } });
function fetchStatus() {
    return callStatus().then(function(d) {
        return d && !Array.isArray(d) && typeof d === 'object' && d.backend_version === 15 ? d : {};
    }).catch(function() { return {}; });
}
function state(value, yes, no) {
    return E('span', { 'class': 'pm-badge' }, [
        typeof value === 'boolean' ? (value ? yes : no) : _('UNKNOWN')
    ]);
}
function text(value) {
    return typeof value === 'string' && value.length && value.length <= 128 ? value : _('UNKNOWN');
}
function field(label, value, technical) {
    return E('div', { 'class': 'pm-field' }, [
        E('span', { 'class': 'pm-label' }, [ label ]),
        E('span', { 'class': 'pm-value', 'dir': technical ? 'ltr' : 'auto' }, [value == null ? _('UNKNOWN') : value])
    ]);
}
function card(title, items) {
    return E('section', { 'class': 'cbi-section pm-card' }, [E('h3', {}, [title]), E('div', {}, items)]);
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
        '@media(max-width:600px){#proxy-monitor .pm-grid{grid-template-columns:minmax(0,1fr)}#proxy-monitor .pm-field{flex-wrap:wrap;gap:.3rem}#proxy-monitor .pm-value{max-width:100%}}'
    ]));
}
function panel(d) {
    d = d || {};
    var enabled = state(d.passwall_enabled, _('Enabled in UCI'), _('Disabled in UCI'));
    var sing = state(d.singbox_running, _('Running'), d.singbox_installed === true ? _('Inactive / standby') : _('UNAVAILABLE'));
    var xray = state(d.xray_running, _('Running'), d.xray_installed === true ? _('Stopped / inactive') : _('UNAVAILABLE'));
    return E('div', { 'class': 'pm-grid' }, [
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
return view.extend({
    load: fetchStatus,
    render: function(d) {
        installStyles();
        var inFlight = null;
        var body = E('div', { 'id': 'proxy-monitor-panel' }, [panel(d)]);
        var content = E('div', { 'id': 'proxy-monitor' }, [
            E('div', { 'class': 'pm-header' }, [E('h2', {}, [_('Proxy Monitor')]),
                E('button', { 'type': 'button', 'class': 'cbi-button cbi-button-action', 'click': function() { return refresh(); } }, [_('Refresh status')])]),
            body,
            E('p', { 'class': 'pm-help' }, [_('Local read-only indicators; configuration and process presence do not prove connectivity. Shared health is published by the existing watchdog. No traffic sampling or connectivity probes. Automatic refresh: 30 seconds while visible.')])
        ]);
        function refresh() {
            if (inFlight) return inFlight;
            inFlight = fetchStatus().then(function(result) {
                while (body.firstChild) body.removeChild(body.firstChild);
                body.appendChild(panel(result));
            }).finally(function() { inFlight = null; });
            return inFlight;
        }
        var tick = function() {
            if (!document.body.contains(content)) { poll.remove(tick); return Promise.resolve(); }
            if (document.hidden) return Promise.resolve();
            return refresh();
        };
        poll.add(tick, 30);
        return content;
    },
    handleSaveApply: null, handleSave: null, handleReset: null
});
