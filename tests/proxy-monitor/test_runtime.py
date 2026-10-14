"""Execute real ucode and shell in a redirected, disposable filesystem.

Only dependency edges (ubus, rpcd, procfs) are fixtures, not backend logic.
No test flags or filesystem overrides are included in production code.
"""
import json, os, pathlib, shutil, subprocess, tempfile, time, unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'openwrt/proxy-monitor/src'
UCODE = os.environ.get('UCODE', shutil.which('ucode') or '')

class RouterFixture:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.env = os.environ.copy()
        self.prefixes = ['/usr/libexec', '/usr/share/ucode', '/usr/share/luci', '/usr/share/rpcd', '/usr/lib/rpcd', '/usr/bin', '/usr/sbin',
                         '/www', '/root/recovery', '/etc/proxy-monitor', '/etc/crontabs',
                         '/etc/init.d/rpcd', '/var/run', '/proc', '/tmp/luci', '/tmp/proxy-monitor', '/bin/ubus']
        self.put('/usr/bin/ucode', '#!/bin/sh\nexec '+UCODE+' "$@"\n', 0o755)
        self.put('/usr/lib/rpcd/ucode.so', 'fixture-module-sentinel')
        self.put('/uci.uc', '''import * as fs from 'fs';
export function cursor() {
    return { get_all: function(config) {
        try { let d=json(fs.readfile('ROOT/config.json')); return type(d.values) == 'object' ? d.values : {}; }
        catch(e) { return {}; }
    }, unload: function(config) {} };
}
'''.replace('ROOT',str(self.root)))
        self.put('/bin/ubus', '''#!/bin/sh
[ "$1" != -t ] || shift 2
case "$1:$2:$3" in
  call:uci:get) cat "ROOT/config.json" ;;
  call:service:list) cat "ROOT/service.json" ;;
  call:proxy-monitor:status)
    if [ -f "ROOT/delay-registration" ] && [ "$(date +%s)" -le "$(cat ROOT/rpc-ready-after)" ]; then
        echo 'Command failed: Not found' >&2; exit 4
    fi
    "ROOT/usr/bin/ucode" "ROOT/rpc-call.uc" ;;
  *) exit 1 ;;
esac
'''.replace('ROOT', str(self.root)), 0o755)
        self.put('/rpc-call.uc', '''import * as fs from 'fs';
let api = loadstring(fs.readfile('ROOT/usr/share/rpcd/ucode/proxy-monitor'))();
printf('%J\\n', api['proxy-monitor'].status.call());
'''.replace('ROOT',str(self.root)))
        self.put('/etc/init.d/rpcd', '''#!/bin/sh
[ "$1" = restart ] || exit 99
echo restart >> "ROOT/restarts"
if [ -f "ROOT/delay-registration" ]; then date +%s > "ROOT/rpc-ready-after"; fi
if [ -f "ROOT/fail-restart" ]; then rm "ROOT/fail-restart"; exit 1; fi
'''.replace('ROOT', str(self.root)), 0o755)
        self.root.joinpath('config.json').write_text('{}')
        self.root.joinpath('service.json').write_text('{}')
        self.root.joinpath('tmp').mkdir()
        self.put('/proc/1/comm', 'xray\n')
        self.put('/proc/2/comm', 'crond\n')
        self.put('/proc/self/comm', 'ucode\n')
        self.put('/usr/bin/xray', '#!/bin/sh\nexit 0\n', 0o755)
        self.put('/usr/bin/sing-box', '#!/bin/sh\nexit 0\n', 0o755)
        if (SRC/'data.uc').exists():self.put('/usr/share/ucode/proxy-monitor.uc', self.redirect((SRC/'data.uc').read_text()))
        self.put('/usr/libexec/proxy-monitor-status', self.redirect((SRC/'status.uc').read_text()), 0o755)

    def path(self, p): return self.root / p.lstrip('/')
    def put(self, path, data, mode=0o644):
        p = self.path(path); p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(data); p.chmod(mode); return p
    def redirect(self, source):
        # Longest first, a single substitution prevents nested double prefixes.
        import re
        source = source.replace("'/root/recovery/internet-watchdog.sh'", "'__CRON_COMMAND__'")
        source = re.sub('|'.join(re.escape(p) for p in sorted(self.prefixes, key=len, reverse=True)),
                        lambda m: str(self.root)+m[0], source)
        source = source.replace("'__CRON_COMMAND__'", "'/root/recovery/internet-watchdog.sh'")
        source = source.replace("from 'uci'", "from '"+str(self.root)+"/uci.uc'")
        source = source.replace("from 'proxy-monitor'", "from '"+str(self.path('/usr/share/ucode/proxy-monitor.uc'))+"'")
        source = source.replace('PATH=/usr/sbin:/usr/bin:/sbin:/bin',
                                'PATH='+str(self.root)+'/usr/bin:'+str(self.root)+'/bin:'+os.environ['PATH'])
        # PATH was redirected above; replace its generated form too.
        source = source.replace('PATH='+str(self.root)+'/usr/sbin:'+str(self.root)+'/usr/bin:/sbin:/bin',
                                'PATH='+str(self.root)+'/usr/bin:'+str(self.root)+'/bin:'+os.environ['PATH'])
        return source
    def run(self, path, *args, env=None):
        return subprocess.run(['sh', str(path), *args], env=env or self.env, capture_output=True, text=True, timeout=40)
    def status(self, mobile=False):
        p = subprocess.run([UCODE, str(self.path('/usr/libexec/proxy-monitor-status')), *(['--mobile'] if mobile else [])],
                           env=self.env, capture_output=True, text=True, timeout=5)
        if p.returncode: raise AssertionError(p.stderr)
        return json.loads(p.stdout)
    def config(self, **overrides):
        values = {'global': {'.type':'global', '.index':0, 'enabled':'1', 'node':'iran_auto_shunt'},
                  'iran_auto_shunt': {'.type':'nodes', 'protocol':'_shunt', 'type':'Xray', 'remarks':'مسیر ایران',
                                      'default_node':'29dn9fUB', 'Iran':'_direct', 'PrivateIP':'_direct'},
                  '29dn9fUB': {'.type':'nodes', 'protocol':'_balancing', 'type':'Xray','balancingStrategy':'leastLoad','balancing_node':['default_member']},
                  'default_member':{'.type':'nodes','type':'Xray','protocol':'vless','address':'example.net','port':'443','remarks':'Default member'}}
        for key, value in overrides.items(): values[key] = value
        self.root.joinpath('config.json').write_text(json.dumps({'values':values}))
        self.root.joinpath('service.json').write_text(json.dumps({'passwall2':{'instances':{'main':{'running':True}}}}))
    def installer(self):
        return self.put('/installer.sh', self.redirect((ROOT/'openwrt/proxy-monitor/install-proxy-monitor-v15.sh').read_text()))
    def backups(self): return sorted(self.path('/root/recovery').glob('proxy-monitor-v15-*'))

@unittest.skipUnless(UCODE, 'Set UCODE to a real ucode executable')
class RuntimeTests(unittest.TestCase):
    def setUp(self): self.f = RouterFixture()
    def tearDown(self): self.f.temp.cleanup()
    def test_status_routing_and_inactive_optional_engine(self):
        self.f.config(); d=self.f.status()
        self.assertTrue(d['xray_running']); self.assertFalse(d['singbox_running'])
        self.assertTrue(d['singbox_installed']); self.assertTrue(d['passwall_running'])
        self.assertEqual(d['shunt_id'], 'iran_auto_shunt'); self.assertEqual(d['balancer_id'], '29dn9fUB')
        self.assertEqual(d['balancer_strategy'], 'leastLoad'); self.assertTrue(d['iran_direct'])
    def test_missing_optional_components_and_partial_or_bad_configuration(self):
        self.f.path('/proc/1/comm').unlink(); self.f.path('/usr/bin/xray').unlink()
        for raw in ['', '{', '[]', '{"values":null}', '{"values":{"g":{".type":"global","enabled":"future","node":123}}}']:
            self.f.root.joinpath('config.json').write_text(raw)
            d=self.f.status(); self.assertIsNone(d['passwall_enabled']); self.assertFalse(d['xray_running'])
            self.assertEqual(d['shared_health'], 'UNKNOWN'); self.assertIsNone(d['failure_count'])
    def test_missing_procfs_or_malformed_procd_is_unknown(self):
        self.f.path('/proc/self/comm').unlink()
        self.f.root.joinpath('service.json').write_text('{"passwall2":{"instances":{"main":{}}}}')
        d=self.f.status()
        self.assertIsNone(d['xray_running']); self.assertIsNone(d['singbox_running'])
        self.assertIsNone(d['passwall_running'])
    def test_future_schema_changes_degrade_to_unknown(self):
        self.f.config(global_future={'enabled':'1','selection':'new-layout'})
        self.f.root.joinpath('config.json').write_text('{"configuration":{"new-schema":true}}')
        d=self.f.status(); self.assertEqual(d['selected_protocol'], 'UNKNOWN')
        self.assertIsNone(d['iran_direct']); self.assertEqual(d['balancer_id'], '')
    def test_legacy_tcp_node_alias_keeps_profile(self):
        self.f.config(**{'global':{'.type':'global','.index':0,'enabled':'1','tcp_node':'iran_auto_shunt'}})
        self.assertEqual(self.f.status()['selected_node'],'iran_auto_shunt')
    def test_custom_executable_paths_survive_core_rename(self):
        p=self.f.put('/opt/custom/future-xray', '#!/bin/sh\n', 0o755)
        self.f.config(apps={'.type':'global_app','.index':0,'xray_file':str(p)})
        self.f.path('/usr/bin/xray').unlink()
        self.f.put('/proc/1/comm','future-xray\n')
        d=self.f.status(); self.assertTrue(d['xray_installed']); self.assertTrue(d['xray_running'])
    def test_no_credentials_or_commands_escape_configuration(self):
        self.f.config(iran_auto_shunt={'protocol':'_shunt', 'remarks':'https://secret:password@proxy/',
            'default_node':'$(touch /tmp/pwn)', 'password':'NEVER_EXPOSE', 'private_key':'SECRET_KEY'})
        data=json.dumps(self.f.status())
        for secret in ['NEVER_EXPOSE','SECRET_KEY','password@','$(touch']: self.assertNotIn(secret,data)
    def test_shared_health_fresh_stale_and_malformed(self):
        p=self.f.put('/var/run/internet-health/state', '{"status":"healthy","last_event":"recovered","secret":"HIDDEN"}')
        self.assertEqual(self.f.status()['shared_health'],'healthy')
        os.utime(p,(time.time()-200,time.time()-200)); self.assertEqual(self.f.status()['shared_health'],'UNKNOWN')
        p.write_text('{'); self.assertEqual(self.f.status()['shared_health'],'UNKNOWN')
        self.f.put('/root/recovery/always-on-watchdog.state','0')
        self.assertEqual(self.f.status()['failure_count'],0)
    def test_commented_cron_is_not_active_watchdog(self):
        self.f.put('/etc/crontabs/root','   # * * * * * /root/recovery/internet-watchdog.sh\n')
        self.assertFalse(self.f.status()['watchdog_scheduled'])
        self.f.put('/etc/crontabs/root','* * * * * /root/recovery/internet-watchdog.sh\n')
        self.assertTrue(self.f.status()['watchdog_scheduled'])
        self.assertTrue(self.f.status()['watchdog_active'])
    def test_mobile_json_retains_android_shape_without_collection(self):
        self.f.config(); d=self.f.status(mobile=True)
        self.assertEqual(d['api_version'],7); self.assertFalse(d['traffic']['available'])
        s=d['status']
        for k in ['xray_running','singbox_running','selected_remark','selected_type','selected_protocol',
                  'public_ip','country_code','expected_nodes','active_nodes']: self.assertIn(k,s)
        self.assertEqual(d['traffic']['rx_bytes'],0)
    def test_install_idempotent_and_rollback_exact_snapshot(self):
        old={'/www/cgi-bin/proxy-monitor-mobile':'old-api', '/usr/libexec/proxy-monitor-traffic':'old-traffic',
             '/www/luci-static/resources/view/status/include/00_proxy-monitor.js':'old-view'}
        for p, s in old.items(): self.f.put(p,s,0o755)
        before=self.f.path('/usr/libexec/proxy-monitor-status').read_bytes()
        installer=self.f.installer()
        one=self.f.run(installer); self.assertEqual(one.returncode,0,one.stdout+one.stderr)
        first=self.f.backups()[0]; token=self.f.path('/etc/proxy-monitor/mobile-token').read_bytes()
        self.assertEqual(self.f.path('/etc/proxy-monitor/mobile-token').stat().st_mode & 0o777,0o600)
        two=self.f.run(installer); self.assertEqual(two.returncode,0,two.stdout+two.stderr)
        self.assertEqual(len(self.f.backups()),2)
        self.assertEqual(self.f.path('/etc/proxy-monitor/mobile-token').read_bytes(),token)
        self.assertFalse(self.f.path('/usr/libexec/proxy-monitor-traffic').exists())
        rollback=self.f.run(first/'rollback.sh'); self.assertEqual(rollback.returncode,0,rollback.stderr)
        for p,s in old.items(): self.assertEqual(self.f.path(p).read_text(),s)
        self.assertEqual(self.f.path('/usr/libexec/proxy-monitor-status').read_bytes(),before)
        self.assertFalse(self.f.path('/etc/proxy-monitor/mobile-token').exists())
    def test_failed_rpc_restart_triggers_automatic_restore(self):
        before=self.f.path('/usr/libexec/proxy-monitor-status').read_bytes()
        self.f.root.joinpath('fail-restart').touch()
        result=self.f.run(self.f.installer())
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.f.path('/usr/libexec/proxy-monitor-status').read_bytes(),before)
        self.assertFalse(self.f.path('/usr/libexec/rpcd/proxy-monitor').exists())
        self.assertFalse(self.f.path('/usr/share/rpcd/ucode/proxy-monitor').exists())
    def test_native_loader_and_overview_files_only(self):
        self.f.put('/usr/libexec/rpcd/proxy-monitor','legacy-exec-plugin',0o755)
        self.f.put('/www/luci-static/resources/view/services/proxy-monitor.js','legacy-services-view')
        self.f.put('/usr/share/luci/menu.d/luci-app-proxy-monitor.json','{}')
        result=self.f.run(self.f.installer())
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertTrue(self.f.path('/www/luci-static/resources/view/status/include/00_proxy-monitor.js').exists())
        self.assertTrue(self.f.path('/usr/share/rpcd/ucode/proxy-monitor').exists())
        self.assertFalse(self.f.path('/usr/libexec/rpcd/proxy-monitor').exists())
        self.assertFalse(self.f.path('/www/luci-static/resources/view/services/proxy-monitor.js').exists())
        self.assertFalse(self.f.path('/usr/share/luci/menu.d/luci-app-proxy-monitor.json').exists())
    def test_asynchronous_rpcd_start_does_not_trigger_false_rollback(self):
        self.f.root.joinpath('delay-registration').touch()
        result=self.f.run(self.f.installer())
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    def test_failed_deployment_write_restores_already_updated_files(self):
        before=self.f.path('/usr/libexec/proxy-monitor-status').read_bytes()
        real_cp=shutil.which('cp')
        marker=self.f.root/'fail-copy'; marker.touch()
        self.f.put('/usr/bin/cp', '#!/bin/sh\ncase "$2" in */stage/*/www/*) if [ -f "'+str(marker)+'" ]; then rm "'+str(marker)+'"; exit 1; fi ;; esac\nexec '+real_cp+' "$@"\n',0o755)
        result=self.f.run(self.f.installer())
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.f.path('/usr/libexec/proxy-monitor-status').read_bytes(),before)
        self.assertFalse(self.f.path('/usr/libexec/rpcd/proxy-monitor').exists())
    def test_symlink_ancestor_is_rejected_before_live_mutation(self):
        outside=self.f.root/'outside'; outside.mkdir()
        self.f.path('/www').symlink_to(outside,target_is_directory=True)
        result=self.f.run(self.f.installer())
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(list(outside.iterdir()),[])
    def test_manual_rollback_respects_installation_lock(self):
        self.assertEqual(self.f.run(self.f.installer()).returncode,0)
        self.f.path('/tmp/proxy-monitor-v15-install.lock').mkdir()
        result=self.f.run(self.f.backups()[0]/'rollback.sh')
        self.assertNotEqual(result.returncode,0)
    def test_mobile_auth_lan_and_request_method(self):
        self.assertEqual(self.f.run(self.f.installer(),'--mobile-api').returncode,0)
        token=self.f.path('/etc/proxy-monitor/mobile-token').read_text().strip()
        def get(remote='192.168.28.2', query='', method='GET'):
            env={**self.f.env,'REMOTE_ADDR':remote,'QUERY_STRING':query,'REQUEST_METHOD':method}
            return self.f.run(self.f.path('/www/cgi-bin/proxy-monitor-mobile'),env=env).stdout
        self.assertIn('403 Forbidden',get())
        self.assertIn('403 Forbidden',get(query='token=wrong'))
        self.assertIn('403 Forbidden',get(remote='8.8.8.8',query='token='+token))
        self.assertIn('405 Method Not Allowed',get(query='token='+token,method='POST'))
        result=get(query='token='+token+'&fresh=1')
        self.assertIn('200 OK',result); self.assertEqual(json.loads(result.split('\n\n',1)[1])['api_version'],7)
        self.f.put('/usr/libexec/proxy-monitor-status', '#!/bin/sh\nprintf "{broken"\n',0o755)
        self.assertIn('503 Service Unavailable',get(query='token='+token))

if __name__=='__main__': unittest.main()
