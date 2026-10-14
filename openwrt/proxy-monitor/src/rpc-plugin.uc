'use strict';
import * as fs from 'fs';

// Native rpcd-mod-ucode loader contract: explicit ubus object + method name.
// The helper reads UCI natively, avoiding a recursive call into this same rpcd.
return {
    'proxy-monitor': {
        status: {
            args: {},
            call: function() {
                let p = fs.popen('/usr/libexec/proxy-monitor-status', 'r');
                if (!p) return {};
                let raw = p.read(65536) || '';
                let rc = p.close();
                if (rc != 0) return {};
                try {
                    let d = json(raw);
                    if (type(d) != 'object' || d.backend_version != 15) return {};
                    d.rpc_backend = 'ucode';
                    d.rpc_revision = 2;
                    return d;
                }
                catch (e) { return {}; }
            }
        }
    }
};
