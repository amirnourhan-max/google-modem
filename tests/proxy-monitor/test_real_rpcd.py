"""Real ubusd + rpcd-mod-ucode registration, reload, status and ACL testing.

PM_RPCD_PREFIX is a PRIVATE build prefix from build-real-runtime.sh. No mocks
replace the registry or native loader. Only fixed filesystem/socket paths are
redirected. This is Linux daemon integration, not verified router deployment.
"""
import json, os, pathlib, signal, subprocess, time, unittest

ROOT=pathlib.Path(__file__).resolve().parents[2]
SRC=ROOT/'openwrt/proxy-monitor/src'
PREFIX=os.environ.get('PM_RPCD_PREFIX')

@unittest.skipUnless(PREFIX,'Set PM_RPCD_PREFIX to run actual daemon integration')
class RealRpcdTests(unittest.TestCase):
    def setUp(self):
        self.p=pathlib.Path(PREFIX).resolve()
        self.env={**os.environ,'LD_LIBRARY_PATH':str(self.p/'lib')+':'+os.environ.get('LD_LIBRARY_PATH','')}
        self.socket=str(self.p/'var/run/test-ubus.sock')
        pathlib.Path(self.socket).parent.mkdir(parents=True,exist_ok=True)
        self.children=[]
        self.log=open(self.p/'rpcd-integration.log','w')
        self.addCleanup(self.stop)
        self.put('etc/config/passwall2',"""config global 'main'
option enabled '1'
option node 'iran_auto_shunt'
config nodes 'iran_auto_shunt'
option protocol '_shunt'
option type 'Xray'
option default_node '29dn9fUB'
option Iran '_direct'
config nodes '29dn9fUB'
option protocol '_balancing'
option balancingStrategy 'leastLoad'
""")
        self.put('share/rpcd/acl.d/luci-app-proxy-monitor.json',json.dumps({'luci-app-proxy-monitor':{'read':{'ubus':{'proxy-monitor':['status']}}}}))
        data=(SRC/'data.uc').read_text().replace('let c = cursor(), values = {};','let c = cursor('+json.dumps(str(self.p/'etc/config'))+'), values = {};')
        data=data.replace('/tmp/proxy-monitor-exit',str(self.p/'var/run/proxy-monitor-exit'))
        self.data_path=self.put('share/ucode/proxy-monitor.uc',data)
        helper=(SRC/'status.uc').read_text().replace('#!/usr/bin/ucode','#!'+str(self.p/'bin/ucode'))
        helper=helper.replace("from 'proxy-monitor'", "from '"+str(self.data_path)+"'")
        helper=helper.replace('let ctx = cursor();','let ctx = cursor('+json.dumps(str(self.p/'etc/config'))+');')
        helper=helper.replace('/bin/ubus',str(self.p/'bin/ubus')+' -s '+self.socket)
        self.put('libexec/proxy-monitor-status',helper,0o755)
        self.native_path=self.p/'share/rpcd/ucode/proxy-monitor'
        self.native_path.unlink(missing_ok=True)
        self.legacy_path=self.p/'libexec/rpcd/proxy-monitor'
        self.legacy_path.unlink(missing_ok=True)
        self.start(self.p/'sbin/ubusd','-s',self.socket)
        self.wait(lambda:pathlib.Path(self.socket).exists())
        self.rpcd=self.start(self.p/'sbin/rpcd','-s',self.socket)
        self.wait(lambda:self.ubus('list','session').stdout.strip()=='session')
    def stop(self):
        for c in reversed(self.children):
            if c.poll() is None: c.terminate()
        for c in self.children:
            try:c.wait(timeout=3)
            except subprocess.TimeoutExpired:c.kill();c.wait()
        self.log.close()
        pathlib.Path(self.socket).unlink(missing_ok=True)
    def put(self,name,data,mode=0o644):
        p=self.p/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(data);p.chmod(mode);return p
    def start(self,*args):
        c=subprocess.Popen([str(a) for a in args],env=self.env,stdout=self.log,stderr=self.log);self.children.append(c);return c
    def ubus(self,*args):
        return subprocess.run([str(self.p/'bin/ubus'),'-s',self.socket,'-t','2',*args],env=self.env,capture_output=True,text=True,timeout=4)
    def wait(self,fn,timeout=8):
        start=time.monotonic()
        while not fn():
            if time.monotonic()-start>timeout:
                self.log.flush();self.fail((self.p/'rpcd-integration.log').read_text()[-6000:])
            time.sleep(.05)
    def deploy_native(self):
        plugin=(SRC/'rpc-plugin.uc').read_text().replace('/usr/libexec/proxy-monitor-status',str(self.p/'libexec/proxy-monitor-status'))
        plugin=plugin.replace("from 'proxy-monitor'", "from '"+str(self.data_path)+"'")
        plugin=plugin.replace('/usr/libexec/proxy-monitor-exit',str(self.p/'libexec/proxy-monitor-exit'))
        self.put('share/rpcd/ucode/proxy-monitor',plugin)
        self.rpcd.send_signal(signal.SIGHUP)
        self.wait(lambda:self.ubus('call','proxy-monitor','status').returncode==0)
    def test_direct_invocation_is_not_registration_and_native_reload_recovers(self):
        # The reported router symptom: direct staged invocation is valid,
        # nevertheless the running registry has never loaded that script.
        staged=self.put('staged/proxy-monitor',(SRC/'rpc-plugin.sh').read_text(),0o755)
        direct=subprocess.run([str(staged),'list'],capture_output=True,text=True,env=self.env,check=True)
        self.assertEqual(json.loads(direct.stdout),{'status':{}})
        missing=self.ubus('call','proxy-monitor','status')
        self.assertNotEqual(missing.returncode,0);self.assertIn('Not found',missing.stderr)
        self.deploy_native()
        result=self.ubus('call','proxy-monitor','status');self.assertEqual(result.returncode,0,result.stderr)
        d=json.loads(result.stdout)
        self.assertEqual(d['rpc_backend'],'ucode');self.assertEqual(d['rpc_revision'],3)
        self.assertEqual(d['shunt_id'],'iran_auto_shunt');self.assertEqual(d['balancer_id'],'29dn9fUB')
        self.assertTrue(d['iran_direct']);self.assertEqual(d['selected_type'],'Xray')
        # Same callback must not recurse into rpcd UCI or stall its session API.
        start=time.monotonic()
        for _ in range(5):self.assertEqual(self.ubus('call','proxy-monitor','status').returncode,0)
        self.assertLess(time.monotonic()-start,3)
        self.assertEqual(self.ubus('list','session').stdout.strip(),'session')
        self.assertNotEqual(self.ubus('call','proxy-monitor','exec','{}').returncode,0)
        access=self.ubus('call','session','access',json.dumps({'ubus_rpc_session':'0'*32,'scope':'ubus','object':'proxy-monitor','function':'status'}))
        self.assertEqual(access.returncode,0,access.stderr)
        self.assertFalse(json.loads(access.stdout)['access'])
        denied=self.ubus('call','session','access',json.dumps({'ubus_rpc_session':'0'*32,'scope':'ubus','object':'proxy-monitor','function':'exit_refresh'}))
        self.assertFalse(json.loads(denied.stdout)['access'])
    def test_manual_check_is_deferred_and_keeps_session_status_responsive(self):
        self.put('libexec/proxy-monitor-exit',"#!/bin/sh\nsleep 0.5\n",0o755)
        self.deploy_native()
        child=subprocess.Popen([str(self.p/'bin/ubus'),'-s',self.socket,'-t','3','call','proxy-monitor','exit_refresh'],env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            time.sleep(.1);self.assertIsNone(child.poll(),'manual process should still be running')
            start=time.monotonic()
            self.assertEqual(self.ubus('list','session').stdout.strip(),'session')
            self.assertEqual(self.ubus('call','proxy-monitor','status').returncode,0)
            self.assertLess(time.monotonic()-start,.4,'external check must not block rpcd')
            out,err=child.communicate(timeout=4);self.assertEqual(child.returncode,0,err)
            self.assertIn('proxy_exit',json.loads(out))
        finally:
            if child.poll() is None:child.kill();child.wait()
    def test_broken_native_plugin_is_not_silently_accepted(self):
        self.put('share/rpcd/ucode/proxy-monitor','this is not valid ucode!')
        self.rpcd.send_signal(signal.SIGHUP)
        self.wait(lambda:'proxy-monitor' in (self.p/'rpcd-integration.log').read_text())
        self.assertNotEqual(self.ubus('call','proxy-monitor','status').returncode,0)
        self.log.flush()
        self.assertIn('proxy-monitor',(self.p/'rpcd-integration.log').read_text())

if __name__=='__main__':unittest.main()
