#!/usr/bin/env python3
"""Browser fixture with the real LuCI view and supplied real theme CSS.

Run: python3 build-preview.py /path/to/bootstrap/cascade.css /tmp/preview.html
No network or private router data is used by this page.
"""
import pathlib, sys
root = pathlib.Path(__file__).resolve().parents[2]
css = pathlib.Path(sys.argv[1]).read_text()
js = (root/'openwrt/proxy-monitor/src/proxy-monitor.js').read_text()
html = '''<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Proxy Monitor v15 — browser fixture</title><style>CSS</style>
<body><main style="margin:20px auto;max-width:1100px;padding:16px">
<div><button id="dark">Dark / Light</button><button id="mobile">Mobile / Desktop</button><button id="partial">Partial JSON</button><button id="healthy">Healthy fixture</button><button id="check">Run checks</button></div>
<pre id="checks">Not run</pre><div id="surface"></div></main><script>
const sample={backend_version:15,passwall_enabled:true,passwall_running:true,xray_running:true,xray_installed:true,singbox_running:false,singbox_installed:true,selected_name:'مسیر ایران',selected_type:'Xray',shunt_id:'iran_auto_shunt',balancer_id:'29dn9fUB',balancer_strategy:'leastLoad',iran_direct:true,private_direct:true,encrypted_dns_process:true,smartdns_process:true,dnsmasq_process:true,watchdog_active:true,resilience_mode:'normal',failure_count:0,led_state:'green',shared_health:'healthy',last_recovery_event:'recovered'};
let data=sample, requests=0, registered=[], interval=0;
function E(tag,attrs={},children=[]) { const el=document.createElement(tag); Object.entries(attrs).forEach(([k,v])=>typeof v==='function'?el.addEventListener(k,v):el.setAttribute(k,v));children.forEach(v=>el.append(v instanceof Node?v:document.createTextNode(String(v))));return el; }
const translate=s=>({'Proxy services':'سرویس‌های پروکسی','Routing configuration':'پیکربندی مسیرها','DNS process indicators':'وضعیت پردازش DNS','Recovery and shared health':'بازیابی و سلامت مشترک','Refresh status':'تازه‌سازی وضعیت'}[s]||s);
const view={extend:v=>v},rpc={declare:()=>()=>{requests++;return Promise.resolve(data)}},poll={add:(f,t)=>{registered.push(f);interval=t},remove:f=>{registered=registered.filter(v=>v!==f)}};
const implementation=(function(view,rpc,poll,E,_) { VIEW })(view,rpc,poll,E,translate);
async function render() { document.getElementById('surface').replaceChildren(implementation.render(await implementation.load())); }
document.getElementById('dark').onclick=()=>document.documentElement.dataset.darkmode=document.documentElement.dataset.darkmode==='true'?'false':'true';
document.getElementById('mobile').onclick=()=>{const s=document.getElementById('surface');s.style.width=s.style.width?'':'360px';s.style.maxWidth='100%'};
document.getElementById('partial').onclick=()=>{data={backend_version:15,xray_running:'false',failure_count:null};render()};
document.getElementById('healthy').onclick=()=>{data=sample;render()};
document.getElementById('check').onclick=async()=>{
 const results=[];const check=(s,v)=>results.push((v?'PASS ':'FAIL ')+s);
 check('DOM badges preserved',document.querySelectorAll('.pm-badge').length>5&&!document.getElementById('surface').textContent.includes('[object'));
 check('No horizontal overflow',document.getElementById('surface').scrollWidth<=document.getElementById('surface').clientWidth+1);
 check('30 second interval',interval===30);
 check('Technical values LTR',Array.from(document.querySelectorAll('[dir="ltr"]')).length>8);
 check('Scoped stylesheet',Array.from(document.querySelectorAll('#proxy-monitor-theme-style')).length===1);
 document.getElementById('checks').textContent=results.join('\\n');
};render();
</script></body></html>'''.replace('CSS',css).replace('VIEW',js)
pathlib.Path(sys.argv[2]).write_text(html)
