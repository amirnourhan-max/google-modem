"""Actual curl + verified TLS + local SOCKS5h transport, private fixtures only.

No public IP service is contacted. --resolve sends any accidental direct
fallback to a closed localhost port; SOCKS5h instead sends provider hostnames
to our SOCKS server. Provider body changes simulate leastLoad connections.
"""
import json, os, pathlib, select, socket, socketserver, ssl, struct, subprocess, threading, unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import test_exit
from test_runtime import SRC, UCODE

@unittest.skipUnless(UCODE,'real ucode required')
class NetworkTests(unittest.TestCase):
    def setUp(self):
        self.unit=test_exit.ExitTests();self.unit.setUp();self.addCleanup(self.unit.tearDown)
        self.f=self.unit.f;self.ip='8.8.4.4';self.fail_socks=False;self.socks_hosts=[];self.http_hosts=[]
        try:
            sock=socket.socket();sock.bind(('127.0.0.1',0));sock.close()
        except PermissionError:
            if os.environ.get('PM_RPCD_PREFIX'):raise
            self.skipTest('Local sandbox forbids socket binding; CI runs this test')
        cert=self.f.root/'cert.pem';key=self.f.root/'key.pem'
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=api64.ipify.org','-addext','subjectAltName=DNS:api64.ipify.org,DNS:ipwho.is'],check=True,capture_output=True)
        owner=self
        class HTTP(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_GET(self):
                host=self.headers['Host'];owner.http_hosts.append(host)
                body={'ip':owner.ip} if host=='api64.ipify.org' else {'success':True,'ip':owner.ip,'country_code':'US' if ':' not in owner.ip else 'DE','country':'United States' if ':' not in owner.ip else 'Germany'}
                raw=json.dumps(body).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        self.https=ThreadingHTTPServer(('127.0.0.1',0),HTTP)
        context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
        self.https.socket=context.wrap_socket(self.https.socket,server_side=True)
        self.start(self.https)
        def readn(s,n):
            data=b''
            while len(data)<n:
                chunk=s.recv(n-len(data))
                if not chunk:raise EOFError()
                data+=chunk
            return data
        class SOCKS(socketserver.BaseRequestHandler):
            def handle(self):
                s=self.request;s.settimeout(7)
                try:
                    version,count=readn(s,2);readn(s,count);s.sendall(b'\x05\x00')
                    ver,cmd,res,kind=readn(s,4)
                    if (ver,cmd,kind)!=(5,1,3):raise AssertionError('SOCKS5h must remotely resolve hostname')
                    host=readn(s,readn(s,1)[0]).decode();port=struct.unpack('!H',readn(s,2))[0]
                    owner.socks_hosts.append((host,port))
                    if owner.fail_socks:s.sendall(b'\x05\x05\x00\x01'+b'\x00'*6);return
                    with socket.create_connection(('127.0.0.1',owner.https.server_port),timeout=5) as target:
                        s.sendall(b'\x05\x00\x00\x01'+b'\x00'*6)
                        while True:
                            ready,_,_=select.select([s,target],[],[],7)
                            if not ready:return
                            for origin in ready:
                                data=origin.recv(8192)
                                if not data:return
                                (target if origin is s else s).sendall(data)
                except (EOFError,OSError):pass
        class Server(socketserver.ThreadingTCPServer):allow_reuse_address=True;daemon_threads=True
        self.socks=Server(('127.0.0.1',0),SOCKS);self.start(self.socks)
        self.f.config(**{'global':{'.type':'global','enabled':'1','node':'29dn9fUB','node_socks_port':str(self.socks.server_address[1])}})
        worker=self.f.redirect((SRC/'exit-check.uc').read_text()).replace(str(self.f.path('/usr/bin/curl')),'/usr/bin/curl')
        worker=worker.replace("'--disable','--silent'","'--disable','--cacert',"+json.dumps(str(cert))+",'--resolve','api64.ipify.org:443:127.0.0.1','--resolve','ipwho.is:443:127.0.0.1','--silent'")
        self.f.put('/usr/libexec/proxy-monitor-exit-check.uc',worker)
        self.f.env['NO_PROXY']='*';self.f.env['ALL_PROXY']='http://invalid.invalid:1'
    def start(self,server):
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        def cleanup():server.shutdown();server.server_close();thread.join(timeout=3)
        self.addCleanup(cleanup)
    def test_actual_tls_socks_ipv4_ipv6_and_no_environment_bypass(self):
        first=self.unit.worker();self.assertEqual(first['state'],'OK');self.assertEqual(first['last_success']['ip'],'8.8.4.4')
        self.unit.expire_limit();self.ip='2606:4700:4700::1111'
        second=self.unit.worker();self.assertEqual(second['last_success']['ip'],self.ip);self.assertEqual(second['last_success']['country']['code'],'DE')
        self.assertEqual(self.socks_hosts,[('api64.ipify.org',443),('ipwho.is',443)]*2)
        self.assertEqual(self.http_hosts,['api64.ipify.org','ipwho.is']*2)
    def test_actual_socks_failure_never_falls_back_and_tls_is_verified(self):
        first=self.unit.worker();self.unit.expire_limit();self.fail_socks=True
        failed=self.unit.worker();self.assertEqual(failed['state'],'CHECK_FAILED');self.assertEqual(failed['last_success'],first['last_success'])
        self.assertEqual(len(self.http_hosts),2)
        self.unit.expire_limit();self.fail_socks=False
        p=self.f.path('/usr/libexec/proxy-monitor-exit-check.uc')
        import re
        p.write_text(re.sub(r"'--cacert',\s*\"[^\"]+\",",'',p.read_text()))
        rejected=self.unit.worker();self.assertEqual(rejected['state'],'CHECK_FAILED');self.assertEqual(len(self.http_hosts),2)
