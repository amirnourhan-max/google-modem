#!/usr/bin/env python3
"""Run the actual unmodified LuCI Overview host with the real v15 include.

Only HTTP/RPC, generic DOM helpers and the System data are fixture boundaries.
The host's sorting, hide/show, poll_status and include load/render are real code.
"""
import pathlib,sys
root=pathlib.Path(__file__).resolve().parents[2]
css=pathlib.Path(sys.argv[1]).read_text()
include=(root/'openwrt/proxy-monitor/src/proxy-monitor.js').read_text()
host=(root/'tests/proxy-monitor/overview-host.js').read_text()
html='''<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Proxy Monitor v15 — actual Overview host fixture</title><style>__CSS__</style>
<body><main style="margin:20px auto;max-width:1100px;padding:16px">
<div><button id="dark">Dark / Light</button><button id="partial">Partial JSON</button><button id="healthy">Healthy fixture</button><button id="check">Run checks</button></div>
<pre id="checks">Not run</pre><div id="surface"></div></main><script>
const sample={backend_version:15,passwall_enabled:true,passwall_running:true,xray_running:true,xray_installed:true,singbox_running:false,singbox_installed:true,selected_name:'مسیر ایران',selected_type:'Xray',shunt_id:'iran_auto_shunt',balancer_id:'29dn9fUB',balancer_strategy:'leastLoad',iran_direct:true,private_direct:true,encrypted_dns_process:true,smartdns_process:true,dnsmasq_process:true,watchdog_active:true,resilience_mode:'normal',failure_count:0,led_state:'green',shared_health:'healthy',last_recovery_event:'recovered'};
let data=sample,requests=0,registered=[],clock=100000;
Date.now=()=>clock;
function E(tag,attrs={},children=[]) {
 if(Array.isArray(tag)){const f=document.createDocumentFragment();tag.forEach(x=>f.append(x));return f;}
 if(attrs instanceof Node||Array.isArray(attrs)||typeof attrs==='string'){children=attrs;attrs={};}
 const el=document.createElement(tag);
 Object.entries(attrs||{}).forEach(([k,v])=>typeof v==='function'?el.addEventListener(k,v):el.setAttribute(k,v));
 (Array.isArray(children)?children:[children]).forEach(v=>{if(v!=null)el.append(v instanceof Node?v:document.createTextNode(String(v)))});return el;
}
const translate=s=>({'Proxy services':'سرویس‌های پروکسی','Routing configuration':'پیکربندی مسیرها','DNS process indicators':'وضعیت پردازش DNS','Recovery and shared health':'بازیابی و سلامت مشترک','Refresh status':'تازه‌سازی وضعیت'}[s]||s);
const baseclass={extend:v=>v},view={extend:v=>v};
const rpc={declare:()=>()=>{requests++;return Promise.resolve(data)}};
const poll={add:(f,t)=>{registered.push(f)},remove:f=>{registered=registered.filter(v=>v!==f)}};
const dom={content:(el,content)=>el.replaceChildren(...(Array.isArray(content)?content:[content]))};
const network={flushCache:()=>Promise.resolve()};
const ui={createHandlerFn:(obj,name,...args)=>ev=>obj[name](...args,ev)};
const fs={list:()=>Promise.resolve([{type:'file',name:'10_system.js'},{type:'file',name:'00_proxy-monitor.js'}])};
let implementation=(function(baseclass,rpc,E,_) { __INCLUDE__ })(baseclass,rpc,E,translate);
const system={title:'System',load:()=>Promise.resolve({}),render:()=>E('table',{'class':'table'},[E('tr',{'class':'tr'},[E('td',{'class':'td'},['Hostname']),E('td',{'class':'td'},['OpenWrt — synthetic fixture'])])])};
let modules={'view.status.include.00_proxy-monitor':implementation,'view.status.include.10_system':system};
const L={resource:p=>'/luci-static/resources/'+p,resolveDefault:(p,fallback)=>Promise.resolve(p).catch(()=>fallback),require:n=>Promise.resolve(modules[n]),bind:(f,obj,...args)=>f.bind(obj,...args)};
const overview=(function(view,dom,poll,fs,network,ui,E,L,_) { __HOST__ })(view,dom,poll,fs,network,ui,E,L,translate);
let includes;
async function render() { includes=await overview.load();document.getElementById('surface').replaceChildren(await overview.render(includes)); }
document.getElementById('dark').onclick=()=>document.documentElement.dataset.darkmode=document.documentElement.dataset.darkmode==='true'?'false':'true';
document.getElementById('partial').onclick=async()=>{data={backend_version:15,xray_running:'false',failure_count:null};clock+=31000;await registered[0]()};
document.getElementById('healthy').onclick=async()=>{data=sample;clock+=31000;await registered[0]()};
document.getElementById('check').onclick=()=>{
 const results=[];const check=(s,v)=>results.push((v?'PASS ':'FAIL ')+s);
 check('DOM badges preserved',document.querySelectorAll('.pm-badge').length>5&&!document.getElementById('surface').textContent.includes('[object'));
 check('No horizontal overflow',document.getElementById('surface').scrollWidth<=document.getElementById('surface').clientWidth+1);
 check('Above System via sorted Overview includes',Array.from(document.querySelectorAll('.cbi-title h3')).map(v=>v.textContent).join('|').startsWith('Proxy MonitorHide|SystemHide'));
 check('Only host poll registered',registered.length===1);
 check('Technical values LTR',document.querySelectorAll('[dir="ltr"]').length>8);
 check('Scoped stylesheet',document.querySelectorAll('#proxy-monitor-theme-style').length===1);
 document.getElementById('checks').textContent=results.join('\\n');
};render();
</script></body></html>'''
pathlib.Path(sys.argv[2]).write_text(html.replace('__CSS__',css).replace('__INCLUDE__',include).replace('__HOST__',host))
