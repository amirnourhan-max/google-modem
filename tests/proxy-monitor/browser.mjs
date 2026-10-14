import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';

// Real browser, real view source, real upstream Bootstrap stylesheet.
// DOM/rpc/poll fixture boundaries are in build-preview.py, never production.
const html = readFileSync(process.argv[2], 'utf8');
const server = createServer((req,res) => {res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(html)});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser = await chromium.launch({headless:true});
mkdirSync('test-results',{recursive:true});
const report=[];
try {
 for (const width of [360,768,1366]) for (const dark of [false,true]) {
  const page = await browser.newPage({viewport:{width,height:1000}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.locator('#proxy-monitor').waitFor();
  if(dark) await page.locator('#dark').click();
  await page.locator('#check').click();
  const result=await page.locator('#checks').innerText();
  assert(!result.includes('FAIL'),result);assert.equal(errors.length,0,errors.join('\n'));
  assert(await page.locator('#surface').innerText().then(s=>s.includes('Inactive / standby')));
  const throttle=await page.evaluate(async()=>{
   const start=requests;const root=document.getElementById('proxy-monitor');
   for(let i=0;i<5;i++){clock+=5000;await registered[0]();}
   const cached=requests===start;
   clock+=5000;await registered[0]();
   return cached&&requests===start+1&&root===document.getElementById('proxy-monitor')&&document.querySelectorAll('#proxy-monitor').length===1;
  });assert(throttle,'Overview frequent polling must use 30-second gate and stable DOM');
  // Capture native text/background contrast, including the status badges.
  const colors=await page.evaluate(()=>{
   const el=document.querySelector('.pm-badge');
   const fg=getComputedStyle(el).color, bg=getComputedStyle(document.body).backgroundColor;
   const channel=s=>s.match(/[\d.]+/g).slice(0,3).map(Number).map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4});
   const lum=c=>{let [r,g,b]=channel(c);return .2126*r+.7152*g+.0722*b};
   const a=lum(fg),b=lum(bg);return {fg,bg,contrast:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)};
  });
  assert(colors.contrast>=4.5,JSON.stringify(colors));
  await page.screenshot({path:`test-results/bootstrap-${dark?'dark':'light'}-${width}-rtl.png`,fullPage:true});
  // Partial schema must not fabricate stopped/error values from string booleans.
  await page.locator('#partial').click();
  await page.locator('#proxy-monitor-panel').getByText('UNKNOWN',{exact:true}).first().waitFor();
  assert(!await page.locator('#surface').innerText().then(s=>s.includes('[object')));
  // Poll no-op while hidden; the page fixture exposes only the dependency edges.
  const hidden=await page.evaluate(async()=>{
   const before=requests;
   Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});
   clock+=60000;
   await registered[registered.length-1]();
   const after=requests;
   Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});
   return before===after;
  });assert(hidden);
  const collapsed=await page.evaluate(async()=>{
   const before=requests;includes[0].hide=true;clock+=60000;
   await registered[0]();includes[0].hide=false;return before===requests;
  });assert(collapsed);
  await page.locator('#proxy-monitor button').click();
  report.push({width,dark,result,colors,hidden,collapsed,throttle});
  await page.close();
 }
 // Undefined color tokens: inherited theme text remains readable.
 const fallback = await browser.newPage({viewport:{width:360,height:900}});
 await fallback.goto(`http://127.0.0.1:${server.address().port}`);
 await fallback.locator('#proxy-monitor').waitFor();
 await fallback.evaluate(()=>{
  document.querySelector('style').remove();
  document.body.style.color='#eee';document.body.style.backgroundColor='#222';
 });
 await fallback.locator('#check').click();
 assert(!(await fallback.locator('#checks').innerText()).includes('FAIL'));
 await fallback.screenshot({path:'test-results/fallback-no-tokens-360-rtl.png',fullPage:true});
 await fallback.close();
 writeFileSync('test-results/browser-report.json',JSON.stringify(report,null,2));
 console.log('PASS: 6 native Bootstrap light/dark/RTL Overview layouts; before System; 30s request gate; hidden/collapsed suspension; fallback; partial JSON; contrast ≥4.5');
} finally { await browser.close(); server.close(); }
