"""Exercise real ucode metadata, status and manual exit-check worker.

HTTP responses are fixtures at the curl executable boundary here. A separate
test uses actual TLS + SOCKS + curl in CI, where sockets are permitted.
"""
import json, os, subprocess, unittest
from test_runtime import RouterFixture, SRC, UCODE

@unittest.skipUnless(UCODE, 'real ucode required')
class ExitTests(unittest.TestCase):
    def setUp(self):
        self.f = RouterFixture()
        self.f.config(**{'global': {'.type':'global','.index':0,'enabled':'1','node':'29dn9fUB','node_socks_port':'1070'}})
        for name,path,mode in [('data.uc','/usr/share/ucode/proxy-monitor.uc',0o644),('exit-check.uc','/usr/libexec/proxy-monitor-exit-check.uc',0o644),('exit-check.sh','/usr/libexec/proxy-monitor-exit',0o755)]:
            if (SRC/name).exists():self.f.put(path,self.f.redirect((SRC/name).read_text()),mode)
        self.f.put('/usr/bin/curl', r'''#!/usr/bin/env python3
import json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[2]
args=sys.argv[1:]
with (root/'calls.jsonl').open('a') as f: f.write(json.dumps(args)+'\n')
url=args[-1]; fixture=root/('echo.json' if 'ipify' in url else 'geo.json')
if (root/'curl-fail').exists():sys.exit(7)
pathlib.Path(args[args.index('--output')+1]).write_bytes(fixture.read_bytes())
''', 0o755)
        self.echo('8.8.4.4'); self.geo('8.8.4.4','US','United States')
    def tearDown(self): self.f.temp.cleanup()
    def echo(self,ip): self.f.root.joinpath('echo.json').write_text(json.dumps({'ip':ip}))
    def geo(self,ip,code,name): self.f.root.joinpath('geo.json').write_text(json.dumps({'success':True,'ip':ip,'country_code':code,'country':name}))
    def calls(self):
        p=self.f.root/'calls.jsonl'
        return [json.loads(s) for s in p.read_text().splitlines()] if p.exists() else []
    def worker(self):
        p=self.f.run(self.f.path('/usr/libexec/proxy-monitor-exit'))
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        return self.f.status()['proxy_exit']
    def expire_limit(self):
        p=self.f.path('/tmp/proxy-monitor-exit.json');d=json.loads(p.read_text());d['checked_at']=0;p.write_text(json.dumps(d))
    def data(self,expression):
        source=self.f.redirect("import * as d from 'proxy-monitor'; printf('%J',"+expression+");")
        p=subprocess.run([UCODE,'-e',source],capture_output=True,text=True,env=self.f.env,check=True)
        return json.loads(p.stdout)
    def test_known_unknown_flags_and_country_name_inference(self):
        self.assertEqual(self.data("d.country({country_code:'de'},'US misleading name')"),{'code':'DE','name':'Germany','flag':'🇩🇪','source':'metadata'})
        for name,code in [('US - premium','US'),('Germany Frankfurt','DE'),('هلند ویژه','NL'),('🇯🇵 Tokyo','JP')]:
            c=self.data('d.country({},'+json.dumps(name)+')'); self.assertEqual(c['code'],code);self.assertEqual(c['source'],'inferred')
        for name in ['unknown node','trust us please','US DE mixed']:
            c=self.data('d.country({},'+json.dumps(name)+')');self.assertEqual(c['flag'],'🌐');self.assertEqual(c['code'],'')
        self.assertEqual(self.data("d.country({country_code:'ZZ'},'unknown')")['source'],'unknown')
    def test_node_names_groups_and_missing_references(self):
        full='🇩🇪 Germany / Premium: '+('Long name '*20)
        self.f.config(**{'29dn9fUB':{'.type':'nodes','protocol':'_balancing','balancing_node':['n1','n2','n1','missing']},
            'n1':{'.type':'nodes','protocol':'vless','remarks':full,'group':'گروه اشتراک / اول'},
            'n2':{'.type':'nodes','protocol':'trojan','remarks':'unknown node','country_code':'JP','password':'NEVER'}})
        d=self.f.status(); nodes=d['balancer_nodes']
        self.assertEqual(len(nodes),3);self.assertEqual(nodes[0]['name'],full);self.assertEqual(nodes[0]['group'],'گروه اشتراک / اول')
        self.assertEqual(nodes[0]['country']['flag'],'🇩🇪');self.assertEqual(nodes[1]['country']['source'],'metadata')
        self.assertFalse(nodes[2]['available']);self.assertNotIn('NEVER',json.dumps(d));self.assertEqual(d['active_nodes'],[])
    def test_batch_groups_and_literal_and_or_matching(self):
        self.f.config(**{'29dn9fUB':{'.type':'nodes','protocol':'_balancing','node_add_mode':'batch','node_group':'Europe%20Premium','node_match_rule':'^DE && !slow || Tokyo$'},
            'one':{'.type':'nodes','type':'Xray','address':'example.net','port':'443','protocol':'vless','remarks':'DE fast','group':'Europe Premium'},
            'two':{'.type':'nodes','type':'Xray','address':'example.net','port':'443','protocol':'vless','remarks':'DE slow','group':'Europe Premium'},
            'three':{'.type':'nodes','type':'Xray','address':'example.net','port':'443','protocol':'vless','remarks':'JP Tokyo','group':'Europe Premium'}})
        d=self.f.status();self.assertTrue(d['balancer_nodes_supported'])
        self.assertEqual([n['id'] for n in d['balancer_nodes']],['one','three'])
        raw=self.f.root.joinpath('config.json').read_text();self.f.root.joinpath('config.json').write_text(raw.replace('Europe%20Premium','Europe+Premium'))
        self.assertEqual([n['id'] for n in self.f.status()['balancer_nodes']],['one','three'])
    def test_batch_empty_or_terms_follow_passwall_semantics(self):
        for rule,expected in [('DE ||',['one']),('|| DE',['one']),('||',[]),('   ',[]),('', ['one','two'])]:
            self.f.config(**{'29dn9fUB':{'.type':'nodes','type':'Xray','protocol':'_balancing','node_add_mode':'batch','node_group':'Europe','node_match_rule':rule},
                'one':{'.type':'nodes','type':'Xray','address':'example.net','port':'443','protocol':'vless','remarks':'DE fast','group':'Europe'},
                'two':{'.type':'nodes','type':'Xray','address':'example.net','port':'443','protocol':'vless','remarks':'US fast','group':'Europe'}})
            self.assertEqual([n['id'] for n in self.f.status()['balancer_nodes']],expected)
    def test_batch_invalid_server_address_cannot_certify_proxy_route(self):
        for address in ['not a host','https://secret.example','-bad.example','bad..example','8.8.8.999','bad;command','[::1]','2001:bad::bad::bad']:
            self.f.config(**{'global':{'.type':'global','enabled':'1','node':'29dn9fUB','node_socks_port':'1070'},
                '29dn9fUB':{'.type':'nodes','type':'Xray','protocol':'_balancing','node_add_mode':'batch','node_group':'Europe'},
                'bad':{'.type':'nodes','type':'Xray','address':address,'port':'443','protocol':'vless','remarks':'DE fast','group':'Europe'}})
            self.assertEqual(self.f.status()['balancer_nodes'],[])
            self.assertEqual(self.worker()['state'],'UNAVAILABLE');self.expire_limit()
        self.assertEqual(self.calls(),[])
    def test_invalid_private_and_non_global_addresses(self):
        invalid=['127.0.0.1','10.1.2.3','192.168.1.1','172.16.1.1','100.64.0.1','169.254.1.2','224.1.1.1','255.255.255.255','192.0.2.1','198.51.100.5','203.0.113.9','01.2.3.4','8.8.4.999','::1','fc00::1','fe80::1','ff02::1','2001:db8::1','::ffff:8.8.8.8','64:ff9b::808:808','2002:808:808::1','2001::1','2001:4860::1%eth0','bad;command']
        for ip in invalid:self.assertEqual(self.data('d.public_ip('+json.dumps(ip)+')'),'')
        for ip in ['8.8.4.4','1.1.1.1','2001:4860:4860::8888','2606:4700:4700::1111']:
            self.assertTrue(self.data('d.public_ip('+json.dumps(ip)+')'))
    def test_manual_only_cached_status_and_explicit_socks_transport(self):
        for _ in range(4):self.f.status()
        self.assertEqual(self.calls(),[])
        d=self.worker();self.assertEqual(d['state'],'OK');self.assertEqual(d['last_success']['ip'],'8.8.4.4')
        self.assertEqual(d['last_success']['country']['flag'],'🇺🇸');self.assertIn('socks5h://127.0.0.1:1070',d['last_success']['route'])
        for args in self.calls():
            self.assertEqual(args[0],'--disable');self.assertEqual(args[args.index('--proxy')+1],'socks5h://127.0.0.1:1070')
            self.assertEqual(args[args.index('--noproxy')+1],'');self.assertIn('--max-time',args);self.assertIn('--max-filesize',args)
            self.assertNotIn('--insecure',args);self.assertNotIn('--location',args)
        self.f.status(mobile=True);self.assertEqual(len(self.calls()),2)
    def test_geo_cache_unchanged_ip_and_alternating_balancer_exits(self):
        one=self.worker();self.worker();self.assertEqual(len(self.calls()),2)
        self.expire_limit();self.worker();self.assertEqual(len(self.calls()),3)
        self.expire_limit();self.echo('1.1.1.1');self.geo('1.1.1.1','AU','Australia')
        two=self.worker();self.assertEqual(two['last_success']['ip'],'1.1.1.1');self.assertEqual(two['last_success']['country']['code'],'AU')
        self.expire_limit();self.echo('8.8.4.4');three=self.worker();self.assertEqual(three['last_success']['country']['code'],'US')
        self.assertEqual(len([c for c in self.calls() if 'ipwho.is' in c[-1]]),2)
    def test_socks_failure_preserves_last_success_and_never_falls_back(self):
        first=self.worker();self.expire_limit();self.f.root.joinpath('curl-fail').touch()
        d=self.worker();self.assertEqual(d['state'],'CHECK_FAILED');self.assertEqual(d['last_success'],first['last_success'])
        self.assertEqual(len(self.calls()),3)
    def test_geo_failure_and_ipv6(self):
        self.echo('2606:4700:4700::1111');self.f.root.joinpath('geo.json').write_text('{"success":false}')
        d=self.worker();self.assertEqual(d['state'],'OK');self.assertEqual(d['last_success']['country']['source'],'unknown')
        self.assertEqual(d['geo_state'],'UNAVAILABLE');self.assertIn(':',d['last_success']['ip'])
        self.expire_limit();self.worker();self.assertEqual(len(self.calls()),3)
    def test_missing_socks_and_direct_profile_are_unavailable(self):
        self.f.config();d=self.worker();self.assertEqual(d['state'],'UNAVAILABLE');self.assertEqual(self.calls(),[])
        self.f.config(**{'global':{'.type':'global','enabled':'1','node':'_direct','node_socks_port':'1070'}})
        self.expire_limit();d=self.worker();self.assertEqual(d['state'],'UNAVAILABLE');self.assertEqual(self.calls(),[])
    def test_shunt_or_direct_fallback_cannot_be_called_verified_proxy_exit(self):
        self.f.config(**{'global':{'.type':'global','enabled':'1','node':'iran_auto_shunt','node_socks_port':'1070'}})
        self.assertEqual(self.worker()['state'],'UNAVAILABLE');self.assertEqual(self.calls(),[])
        self.f.config(**{'global':{'.type':'global','enabled':'1','node':'29dn9fUB','node_socks_port':'1070'},'29dn9fUB':{'.type':'nodes','protocol':'_balancing','fallback_node':'_direct'}})
        self.expire_limit();self.assertEqual(self.worker()['state'],'UNAVAILABLE');self.assertEqual(self.calls(),[])
    def test_empty_or_invalid_balancer_never_certifies_a_proxy_exit(self):
        for balance in [
            {'.type':'nodes','type':'Xray','protocol':'_balancing','balancing_node':[]},
            {'.type':'nodes','type':'Xray','protocol':'_balancing','node_add_mode':'batch','node_group':'no-matching-group'},
            {'.type':'nodes','type':'Xray','protocol':'_balancing','balancing_node':['broken']}
        ]:
            self.f.config(**{'global':{'.type':'global','enabled':'1','node':'29dn9fUB','node_socks_port':'1070'},'29dn9fUB':balance,
                'broken':{'.type':'nodes','protocol':'vless'}})
            self.assertEqual(self.worker()['state'],'UNAVAILABLE');self.expire_limit()
        self.assertEqual(self.calls(),[])
    def test_existing_dedicated_balancer_socks_is_preferred_to_shunt(self):
        self.f.config(**{'global':{'.type':'global','enabled':'1','node':'iran_auto_shunt','node_socks_port':'1070','socks_enabled':'1'},
            'socks1':{'.type':'socks','.index':4,'enabled':'1','node':'29dn9fUB','port':'1081'}})
        self.assertIn('127.0.0.1:1081',self.worker()['last_success']['route'])
    def test_bad_oversized_mismatched_geo_and_echo_are_rejected(self):
        for raw in ['{','[]',json.dumps({'ip':'10.0.0.1'}),'x'*5000]:
            self.f.root.joinpath('echo.json').write_text(raw);d=self.worker();self.assertEqual(d['state'],'INVALID_RESPONSE');self.expire_limit()
        self.echo('8.8.4.4');self.geo('1.1.1.1','US','United States')
        d=self.worker();self.assertEqual(d['last_success']['country']['flag'],'🌐')
    def test_uncached_api_does_not_probe_or_change_legacy_fields(self):
        d=self.f.status(mobile=True);self.assertEqual(d['api_version'],7);self.assertFalse(d['traffic']['available'])
        self.assertEqual(d['status']['public_ip'],'');self.assertEqual(d['status']['active_nodes'],[]);self.assertEqual(self.calls(),[])
        self.assertIn('proxy_exit',d['status'])
    def test_corrupt_or_private_cache_cannot_claim_success(self):
        p=self.f.path('/tmp/proxy-monitor-exit.json')
        p.parent.mkdir(parents=True,exist_ok=True)
        for raw in ['{','[]','x'*17000,json.dumps({'version':1,'state':'OK','last_success':{'ip':'10.0.0.1','checked_at':1700000000,'route':'socks5h://127.0.0.1:1070 → balance'}})]:
            p.write_text(raw);d=self.f.status()['proxy_exit'];self.assertIsNone(d['last_success']);self.assertNotEqual(d['state'],'OK')
    def test_install_and_rollback_preserve_cache_and_new_helper_files(self):
        p=self.f.path('/tmp/proxy-monitor-exit.json');p.write_text('previous-cache')
        before=self.f.path('/usr/share/ucode/proxy-monitor.uc').read_bytes()
        result=self.f.run(self.f.installer());self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        p.write_text('changed-after-install')
        result=self.f.run(self.f.backups()[0]/'rollback.sh');self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(p.read_text(),'previous-cache');self.assertEqual(self.f.path('/usr/share/ucode/proxy-monitor.uc').read_bytes(),before)
    def test_busy_manual_check_blocks_install_before_mutation(self):
        before=self.f.path('/usr/libexec/proxy-monitor-status').read_bytes()
        self.f.path('/tmp/proxy-monitor-exit.lock').mkdir()
        result=self.f.run(self.f.installer());self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.f.path('/usr/libexec/proxy-monitor-status').read_bytes(),before)
    def test_optional_uloop_missing_does_not_block_status_install(self):
        p=self.f.installer();p.write_text(p.read_text().replace("require('uloop')","require('missing-uloop-fixture')").replace("from 'uloop'","from 'missing-uloop-fixture'"))
        result=self.f.run(p);self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.f.status()['backend_version'],15)
    def test_dedicated_autoswitch_socks_cannot_claim_a_fixed_balancer_route(self):
        self.f.config(**{'global':{'.type':'global','enabled':'1','node':'iran_auto_shunt','node_socks_port':'1070','socks_enabled':'1'},
            'socks1':{'.type':'socks','.index':4,'enabled':'1','node':'29dn9fUB','port':'1081','enable_autoswitch':'1','backup_node_add_mode':'batch','backup_node_group':'backup'}})
        self.assertEqual(self.worker()['state'],'UNAVAILABLE');self.assertEqual(self.calls(),[])

