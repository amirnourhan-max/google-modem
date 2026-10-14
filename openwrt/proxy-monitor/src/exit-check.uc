'use strict';
import * as fs from 'fs';
import { configuration, socks_route, country_info, public_ip, cache_read } from 'proxy-monitor';
// Dynamic optional dependency: syntax validation/install still works without
// this module. The RPC adapter reports DEPENDENCY_MISSING before spawning us.
const loop=require('uloop');

const cache_path='/tmp/proxy-monitor-exit.json';
const lock_path='/tmp/proxy-monitor-exit.lock';
// mkdir is atomic; no background polling. A crashed bounded check expires.
let lock=fs.lstat(lock_path);
if (lock && lock.type == 'directory' && time()-lock.mtime > 30) fs.rmdir(lock_path);
if (!fs.mkdir(lock_path,0700)) exit(0);
if (fs.lstat('/tmp/proxy-monitor-v15-install.lock')) { fs.rmdir(lock_path); exit(0); }
let work=fs.mkdtemp('/tmp/proxy-monitor-exit-XXXXXX');
if (!work) { fs.rmdir(lock_path); exit(1); }
let previous=cache_read();
let now=time();
function finish(state,reason,geo_state,last,geos) {
    let result={version:1,state:state,reason:reason,checked_at:now,geo_state:geo_state,
        last_success:last || previous.last_success || null,geo_cache:geos || previous.geo_cache || {}};
    let raw=sprintf('%J\n',result);
    if (length(raw) <= 16384 && fs.writefile(work+'/cache',raw) != null) {
        fs.chmod(work+'/cache',0600);fs.rename(work+'/cache',cache_path);
    }
}
function bounded_json(path) {
    let s=fs.lstat(path);
    if(!s || s.type != 'file' || s.size > 4096) return {};
    try { let d=json(fs.readfile(path,4097)); return type(d)=='object' ? d : {}; } catch(e) { return {}; }
}
function https(route,url) {
    let result=-1;
    let child=loop.process('/usr/bin/curl',[
        '--disable','--silent','--fail','--proto','=https','--tlsv1.2',
        '--connect-timeout','2','--max-time','5','--max-filesize','4096',
        '--proxy','socks5h://127.0.0.1:'+route.port,'--noproxy','',
        '--output',work+'/response',url
    ],{PATH:'/usr/sbin:/usr/bin:/sbin:/bin',LC_ALL:'C'},code=>{result=code;loop.end();});
    if (!child) return null;
    loop.run();
    let response=result==0 ? bounded_json(work+'/response') : null;
    fs.unlink(work+'/response');return response;
}
function check() {
    // Limit manual repeats as well as concurrent browser tabs.
    if (type(previous.checked_at)=='int' && now-previous.checked_at>=0 && now-previous.checked_at<15) return;
    let route=socks_route(configuration());
    if (!route) {finish('UNAVAILABLE','SOCKS_ROUTE_UNVERIFIED','UNAVAILABLE');return;}
    if (!fs.access('/usr/bin/curl','x')) {finish('UNAVAILABLE','DEPENDENCY_MISSING','UNAVAILABLE');return;}
    let echo=https(route,'https://api64.ipify.org?format=json');
    if (echo==null) {finish('CHECK_FAILED','HTTPS_OR_SOCKS_FAILED','UNAVAILABLE');return;}
    let ip=public_ip(echo.ip);
    if (!ip) {finish('INVALID_RESPONSE','BAD_ECHO','UNAVAILABLE');return;}
    let geos=type(previous.geo_cache)=='object' ? previous.geo_cache : {};
    let entry=type(geos[ip])=='object' ? geos[ip] : {};
    let c=type(entry.country)=='object' ? country_info(entry.country.code,'geolocation') : country_info('','unknown');
    // Positive results last for this boot/cache. Failed lookups have a 5-minute
    // negative cache; retry only on a later explicitly requested check.
    if (!c.code && !(type(entry.lookup_at)=='int' && now-entry.lookup_at>=0 && now-entry.lookup_at<300)) {
        let geo=https(route,'https://ipwho.is/'+ip+'?fields=success,ip,country,country_code');
        if (geo && geo.success==true && public_ip(geo.ip)==ip)
            c=country_info(geo.country_code,'geolocation');
        geos[ip]={country:c,lookup_at:now};
    }
    // A small bounded LRU-like geolocation cache accommodates alternating exits.
    while(length(keys(geos))>16) {
        let oldest=null;
        for(let key,val in geos) if(key!=ip && (oldest==null || val.lookup_at < geos[oldest].lookup_at)) oldest=key;
        if(oldest==null)break;delete geos[oldest];
    }
    finish('OK','NONE',c.code ? 'OK' : 'UNAVAILABLE',{
        ip:ip,country:c,checked_at:time(),route:'socks5h://127.0.0.1:'+route.port+' → '+route.profile
    },geos);
}
loop.init();
try { check(); } catch(e) { finish('CHECK_FAILED','HTTPS_OR_SOCKS_FAILED','UNAVAILABLE'); }
loop.done();
fs.unlink(work+'/response');fs.unlink(work+'/cache');fs.rmdir(work);fs.rmdir(lock_path);
