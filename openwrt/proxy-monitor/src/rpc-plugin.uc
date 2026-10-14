'use strict';
import * as fs from 'fs';
import { exit_cache } from 'proxy-monitor';
let loop=null, checking=false;
try { loop=require('uloop'); } catch(e) {}

// Native rpcd-mod-ucode loader contract: explicit ubus object + method name.
// The helper reads UCI natively, avoiding a recursive call into this same rpcd.
return {
    'proxy-monitor': {
        status: {
            args: {},
            call: function() {
                let p = fs.popen('/usr/libexec/proxy-monitor-status', 'r');
                if (!p) return {};
                let raw = p.read(262144) || '';
                let rc = p.close();
                if (rc != 0) return {};
                try {
                    let d = json(raw);
                    if (type(d) != 'object' || d.backend_version != 15) return {};
                    d.rpc_backend = 'ucode';
                    d.rpc_revision = 3;
                    return d;
                }
                catch (e) { return {}; }
            }
        },
        // Authenticated, argument-free manual HTTPS reads; no proxy setting
        // changes. Deferred process keeps rpcd/session/other LuCI RPC responsive.
        exit_refresh: {
            args: {},
            call: function(request) {
                if (!loop || !fs.access('/usr/bin/curl','x')) {
                    let d=exit_cache();d.state='UNAVAILABLE';d.reason='DEPENDENCY_MISSING';
                    return {proxy_exit:d};
                }
                if (checking) {let d=exit_cache();d.state='CHECKING';return {proxy_exit:d};}
                checking=true;
                let child=loop.process('/usr/libexec/proxy-monitor-exit',[],null,function(code) {
                    checking=false;
                    let d=exit_cache();
                    if(code!=0){d.state='CHECK_FAILED';d.reason='HTTPS_OR_SOCKS_FAILED';}
                    request.reply({proxy_exit:d});
                });
                if(!child){checking=false;return {proxy_exit:{state:'UNAVAILABLE',reason:'DEPENDENCY_MISSING'}};}
                return request.defer();
            }
        }
    }
};
