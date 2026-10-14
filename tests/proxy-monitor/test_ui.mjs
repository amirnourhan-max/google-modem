// Execute the actual include; no production logic is mirrored here.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const code=readFileSync(new URL('../../openwrt/proxy-monitor/src/proxy-monitor.js',import.meta.url),'utf8');
const E=(tag,attrs={},children=[])=>({tag,attrs,children});
const document={hidden:false,getElementById:()=>false,head:{appendChild:()=>{}}};
const rpc={declare:spec=>()=>Promise.resolve(spec.method==='status'?{backend_version:15}:{proxy_exit:{state:'OK'}})};
const implementation=new Function('baseclass','rpc','E','_','document',code)({extend:o=>o},rpc,E,s=>s,document);
const root=implementation.render({backend_version:15,balancer_nodes:[{id:'one',name:'Full DE node name',group:'Full group',country:{code:'DE',name:'Germany',source:'inferred'}}],proxy_exit:{state:'OK',last_success:{ip:'8.8.4.4',country:{code:'US',name:'United States',source:'geolocation'},checked_at:1700000000,route:'socks5h://127.0.0.1:1070 → balance'}}});
function walk(n){if(!n||typeof n!=='object')return [];return [n,...n.children.flatMap(walk)];}
const nodes=walk(root);
assert(nodes.some(n=>n.attrs.id==='proxy-monitor-nodes'),'configured Balancer section missing');
assert(nodes.some(n=>n.attrs.id==='proxy-monitor-exit'),'manual exit-IP section missing');
function strings(n){return typeof n==='string'?n:n&&n.children?n.children.map(strings).join(' '):'';}
const text=strings(root);
for(const value of ['🇩🇪','🇺🇸','inferred','Full DE node name','Full group','8.8.4.4','Observed proxy exit IP — last check'])assert(text.includes(value),value);
assert(nodes.filter(n=>n.tag==='button').length===2);
console.log('PASS: actual LuCI include parses; node flags/labels/groups; observed exit card; two explicit refresh controls');
