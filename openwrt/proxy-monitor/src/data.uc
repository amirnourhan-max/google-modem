'use strict';
import * as fs from 'fs';
import { cursor } from 'uci';

// Static ISO 3166-1 alpha-2 whitelist and local English labels (Intl/CLDR).
// No flag asset requests and no server-address geolocation or DNS lookups.
const countries = {
  "AD": "Andorra",
  "AE": "United Arab Emirates",
  "AF": "Afghanistan",
  "AG": "Antigua & Barbuda",
  "AI": "Anguilla",
  "AL": "Albania",
  "AM": "Armenia",
  "AO": "Angola",
  "AQ": "Antarctica",
  "AR": "Argentina",
  "AS": "American Samoa",
  "AT": "Austria",
  "AU": "Australia",
  "AW": "Aruba",
  "AX": "Åland Islands",
  "AZ": "Azerbaijan",
  "BA": "Bosnia & Herzegovina",
  "BB": "Barbados",
  "BD": "Bangladesh",
  "BE": "Belgium",
  "BF": "Burkina Faso",
  "BG": "Bulgaria",
  "BH": "Bahrain",
  "BI": "Burundi",
  "BJ": "Benin",
  "BL": "St. Barthélemy",
  "BM": "Bermuda",
  "BN": "Brunei",
  "BO": "Bolivia",
  "BQ": "Caribbean Netherlands",
  "BR": "Brazil",
  "BS": "Bahamas",
  "BT": "Bhutan",
  "BV": "Bouvet Island",
  "BW": "Botswana",
  "BY": "Belarus",
  "BZ": "Belize",
  "CA": "Canada",
  "CC": "Cocos (Keeling) Islands",
  "CD": "Congo - Kinshasa",
  "CF": "Central African Republic",
  "CG": "Congo - Brazzaville",
  "CH": "Switzerland",
  "CI": "Côte d’Ivoire",
  "CK": "Cook Islands",
  "CL": "Chile",
  "CM": "Cameroon",
  "CN": "China",
  "CO": "Colombia",
  "CR": "Costa Rica",
  "CU": "Cuba",
  "CV": "Cape Verde",
  "CW": "Curaçao",
  "CX": "Christmas Island",
  "CY": "Cyprus",
  "CZ": "Czechia",
  "DE": "Germany",
  "DJ": "Djibouti",
  "DK": "Denmark",
  "DM": "Dominica",
  "DO": "Dominican Republic",
  "DZ": "Algeria",
  "EC": "Ecuador",
  "EE": "Estonia",
  "EG": "Egypt",
  "EH": "Western Sahara",
  "ER": "Eritrea",
  "ES": "Spain",
  "ET": "Ethiopia",
  "FI": "Finland",
  "FJ": "Fiji",
  "FK": "Falkland Islands",
  "FM": "Micronesia",
  "FO": "Faroe Islands",
  "FR": "France",
  "GA": "Gabon",
  "GB": "United Kingdom",
  "GD": "Grenada",
  "GE": "Georgia",
  "GF": "French Guiana",
  "GG": "Guernsey",
  "GH": "Ghana",
  "GI": "Gibraltar",
  "GL": "Greenland",
  "GM": "Gambia",
  "GN": "Guinea",
  "GP": "Guadeloupe",
  "GQ": "Equatorial Guinea",
  "GR": "Greece",
  "GS": "South Georgia & South Sandwich Islands",
  "GT": "Guatemala",
  "GU": "Guam",
  "GW": "Guinea-Bissau",
  "GY": "Guyana",
  "HK": "Hong Kong SAR China",
  "HM": "Heard & McDonald Islands",
  "HN": "Honduras",
  "HR": "Croatia",
  "HT": "Haiti",
  "HU": "Hungary",
  "ID": "Indonesia",
  "IE": "Ireland",
  "IL": "Israel",
  "IM": "Isle of Man",
  "IN": "India",
  "IO": "British Indian Ocean Territory",
  "IQ": "Iraq",
  "IR": "Iran",
  "IS": "Iceland",
  "IT": "Italy",
  "JE": "Jersey",
  "JM": "Jamaica",
  "JO": "Jordan",
  "JP": "Japan",
  "KE": "Kenya",
  "KG": "Kyrgyzstan",
  "KH": "Cambodia",
  "KI": "Kiribati",
  "KM": "Comoros",
  "KN": "St. Kitts & Nevis",
  "KP": "North Korea",
  "KR": "South Korea",
  "KW": "Kuwait",
  "KY": "Cayman Islands",
  "KZ": "Kazakhstan",
  "LA": "Laos",
  "LB": "Lebanon",
  "LC": "St. Lucia",
  "LI": "Liechtenstein",
  "LK": "Sri Lanka",
  "LR": "Liberia",
  "LS": "Lesotho",
  "LT": "Lithuania",
  "LU": "Luxembourg",
  "LV": "Latvia",
  "LY": "Libya",
  "MA": "Morocco",
  "MC": "Monaco",
  "MD": "Moldova",
  "ME": "Montenegro",
  "MF": "St. Martin",
  "MG": "Madagascar",
  "MH": "Marshall Islands",
  "MK": "North Macedonia",
  "ML": "Mali",
  "MM": "Myanmar (Burma)",
  "MN": "Mongolia",
  "MO": "Macao SAR China",
  "MP": "Northern Mariana Islands",
  "MQ": "Martinique",
  "MR": "Mauritania",
  "MS": "Montserrat",
  "MT": "Malta",
  "MU": "Mauritius",
  "MV": "Maldives",
  "MW": "Malawi",
  "MX": "Mexico",
  "MY": "Malaysia",
  "MZ": "Mozambique",
  "NA": "Namibia",
  "NC": "New Caledonia",
  "NE": "Niger",
  "NF": "Norfolk Island",
  "NG": "Nigeria",
  "NI": "Nicaragua",
  "NL": "Netherlands",
  "NO": "Norway",
  "NP": "Nepal",
  "NR": "Nauru",
  "NU": "Niue",
  "NZ": "New Zealand",
  "OM": "Oman",
  "PA": "Panama",
  "PE": "Peru",
  "PF": "French Polynesia",
  "PG": "Papua New Guinea",
  "PH": "Philippines",
  "PK": "Pakistan",
  "PL": "Poland",
  "PM": "St. Pierre & Miquelon",
  "PN": "Pitcairn Islands",
  "PR": "Puerto Rico",
  "PS": "Palestinian Territories",
  "PT": "Portugal",
  "PW": "Palau",
  "PY": "Paraguay",
  "QA": "Qatar",
  "RE": "Réunion",
  "RO": "Romania",
  "RS": "Serbia",
  "RU": "Russia",
  "RW": "Rwanda",
  "SA": "Saudi Arabia",
  "SB": "Solomon Islands",
  "SC": "Seychelles",
  "SD": "Sudan",
  "SE": "Sweden",
  "SG": "Singapore",
  "SH": "St. Helena",
  "SI": "Slovenia",
  "SJ": "Svalbard & Jan Mayen",
  "SK": "Slovakia",
  "SL": "Sierra Leone",
  "SM": "San Marino",
  "SN": "Senegal",
  "SO": "Somalia",
  "SR": "Suriname",
  "SS": "South Sudan",
  "ST": "São Tomé & Príncipe",
  "SV": "El Salvador",
  "SX": "Sint Maarten",
  "SY": "Syria",
  "SZ": "Eswatini",
  "TC": "Turks & Caicos Islands",
  "TD": "Chad",
  "TF": "French Southern Territories",
  "TG": "Togo",
  "TH": "Thailand",
  "TJ": "Tajikistan",
  "TK": "Tokelau",
  "TL": "Timor-Leste",
  "TM": "Turkmenistan",
  "TN": "Tunisia",
  "TO": "Tonga",
  "TR": "Türkiye",
  "TT": "Trinidad & Tobago",
  "TV": "Tuvalu",
  "TW": "Taiwan",
  "TZ": "Tanzania",
  "UA": "Ukraine",
  "UG": "Uganda",
  "UM": "U.S. Outlying Islands",
  "US": "United States",
  "UY": "Uruguay",
  "UZ": "Uzbekistan",
  "VA": "Vatican City",
  "VC": "St. Vincent & Grenadines",
  "VE": "Venezuela",
  "VG": "British Virgin Islands",
  "VI": "U.S. Virgin Islands",
  "VN": "Vietnam",
  "VU": "Vanuatu",
  "WF": "Wallis & Futuna",
  "WS": "Samoa",
  "YE": "Yemen",
  "YT": "Mayotte",
  "ZA": "South Africa",
  "ZM": "Zambia",
  "ZW": "Zimbabwe"
};
const aliases = { 'uk':'GB', 'usa':'US', 'united states':'US', 'south korea':'KR', 'russia':'RU',
    'آلمان':'DE', 'هلند':'NL', 'فرانسه':'FR', 'انگلیس':'GB', 'بریتانیا':'GB', 'آمریکا':'US',
    'امریکا':'US', 'ترکیه':'TR', 'ایران':'IR', 'ژاپن':'JP', 'کانادا':'CA', 'سنگاپور':'SG',
    'روسیه':'RU', 'فنلاند':'FI', 'سوئد':'SE', 'امارات':'AE', 'استرالیا':'AU' };
export function country_code(s) {
    if (type(s) != 'string') return '';
    s = uc(trim(s)); return countries[s] ? s : '';
}
export function country_info(code, source) {
    code = country_code(code);
    return { code: code, name: code ? countries[code] : '',
        flag: code ? uchr(0x1f1e6 + ord(code, 0) - 65, 0x1f1e6 + ord(code, 1) - 65) : '🌐',
        source: code ? source : 'unknown' };
}
function bounded_word(haystack, needle) {
    // Country names are literal strings, never regular expressions.
    let words = split(haystack, /[^a-zA-Z\x80-\xff]+/);
    let joined = ' ' + join(' ', words) + ' ';
    return index(joined, ' ' + needle + ' ') >= 0;
}
export function country(metadata, name) {
    metadata = type(metadata) == 'object' ? metadata : {};
    for (let key in ['country_code', 'country_iso', 'country']) {
        let code = country_code(metadata[key]);
        if (code) return country_info(code, 'metadata');
        if (type(metadata[key]) == 'string') {
            let value = lc(trim(metadata[key]));
            if (aliases[value]) return country_info(aliases[value], 'metadata');
            for (let cc, label in countries)
                if (lc(label) == value) return country_info(cc, 'metadata');
        }
    }
    if (type(name) != 'string') return country_info('', 'unknown');
    let hits = {};
    for (let cc, label in countries) {
        if (index(name, country_info(cc, 'inferred').flag) >= 0 ||
            index(split(name, /[^A-Za-z]+/), cc) >= 0 || bounded_word(lc(name), lc(label))) hits[cc] = true;
    }
    for (let word, code in aliases)
        if (bounded_word(lc(name), word)) hits[code] = true;
    return country_info(length(keys(hits)) == 1 ? keys(hits)[0] : '', 'inferred');
}
export function display_label(s, fallback, limit) {
    // Return metadata only. Never return configuration, server URL or secrets.
    if (type(s) != 'string' || length(s) > (limit || 1024) ||
        match(s, /[[:cntrl:]]/) || match(s, /[A-Za-z][A-Za-z0-9+.-]*:\/\//) ||
        match(s, /[^ ]+:[^ ]+@/)) return fallback;
    return s || fallback;
}
export function node_id(s) { return type(s) == 'string' && match(s, /^[A-Za-z0-9_]{1,64}$/) ? s : ''; }
export function configuration() {
    let c = cursor(), values = {};
    try { values = c.get_all('passwall2') || {}; } catch (e) {}
    c.unload('passwall2'); return type(values) == 'object' ? values : {};
}
export function first_section(values, kind) {
    let result = {};
    for (let key, value in values)
        if (type(value) == 'object' && value['.type'] == kind &&
            (result['.index'] == null || value['.index'] < result['.index'])) result = value;
    return result;
}
function percent_decode(s) {
    let out='';
    for(let i=0;i<length(s);i++) {
        if(substr(s,i,1)=='%' && match(substr(s,i+1,2),/^[0-9a-fA-F]{2}$/)) {out+=chr(int(substr(s,i+1,2),16));i+=2;}
        else out+=substr(s,i,1)=='+' ? ' ' : substr(s,i,1);
    }
    return out;
}
function literal_rule(name, rule) {
    if(rule=='')return true;
    for(let group in split(rule,'||')) {
        if(!trim(group))continue;
        let yes=true;
        for(let term in split(group,'&&')) {
            term=trim(term);if(!term)continue;
            let test;
            if(substr(term,0,1)=='!')test=index(name,substr(term,1))<0 || length(term)==1;
            else if(substr(term,0,1)=='^')test=index(name,substr(term,1))==0;
            else if(substr(term,-1)=='$') {let value=substr(term,0,length(term)-1);test=substr(name,-length(value))==value;}
            else test=index(name,term)>=0;
            if(!test){yes=false;break;}
        }
        if(yes)return true;
    }
    return false;
}
function ipv6_words(s) {
    if(type(s)!='string' || length(s)>39 || !match(s,/^[0-9a-fA-F:]+$/))return null;
    let halves=split(lc(s),'::');if(length(halves)>2)return null;
    let left=halves[0] ? split(halves[0],':') : [];
    let right=length(halves)==2 && halves[1] ? split(halves[1],':') : [];
    let count=length(left)+length(right);
    if((length(halves)==1 && count!=8) || (length(halves)==2 && count>=8))return null;
    for(let word in [...left,...right])if(!match(word,/^[0-9a-f]{1,4}$/))return null;
    let words=[...left];if(length(halves)==2)for(let i=count;i<8;i++)push(words,'0');
    return map([...words,...right],word=>int(word,16));
}
function ipv4_parts(s) {
    if(type(s)!='string' || !match(s,/^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}$/))return null;
    let a=map(split(s,'.'),v=>int(v));return max(a[0],a[1],a[2],a[3])<=255 ? a : null;
}
function server_address(s) {
    if(type(s)!='string' || !length(s) || length(s)>253)return false;
    if(index(s,':')>=0)return ipv6_words(s)!=null;
    if(match(s,/^[0-9.]+$/))return ipv4_parts(s)!=null;
    if(substr(s,-1)=='.')s=substr(s,0,length(s)-1);
    for(let word in split(s,'.'))if(!match(word,/^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/))return false;
    return true;
}
export function members(balance, values) {
    if(!balance.node_add_mode || balance.node_add_mode=='manual')return {
        supported:true,ids:type(balance.balancing_node)=='array' ? balance.balancing_node :
            type(balance.balancing_node)=='string' ? split(trim(balance.balancing_node),/[ \t]+/) : [] };
    if(balance.node_add_mode!='batch' || type(balance.node_group)!='string' ||
        (balance.node_match_rule!=null && type(balance.node_match_rule)!='string'))return {supported:false,ids:[]};
    let groups=map(split(trim(balance.node_group),/[ \t]+/),g=>lc(percent_decode(g))), ids=[];
    let rule=balance.node_match_rule || '';
    for(let key,n in values) {
        if(type(n)!='object' || n['.type']!='nodes' || !n.type || !n.remarks || n.chain_proxy ||
            index(['_balancing','_shunt','_iface','_urltest'],n.protocol)>=0 ||
            !((server_address(n.address) && (n.port || n.hysteria_hop || n.hysteria2_hop)) || (n.protocol=='hysteria2' && n.hysteria2_realms)))continue;
        if(index(groups,lc(n.group || 'default'))>=0 && literal_rule(n.remarks,rule))push(ids,key);
    }
    return {supported:true,ids:ids};
}
function port(s) { return type(s) == 'string' && match(s, /^[0-9]{1,5}$/) && int(s) > 0 && int(s) <= 65535 ? int(s) : 0; }
function proxy_route(values, id, seen) {
    if (!node_id(id) || seen[id]) return false;
    let n = values[id]; if (type(n) != 'object') return false;
    if (n['.type'] != 'nodes' || index(['Xray','Sing-Box','sing-box'],n.type)<0 || n.chain_proxy) return false;
    if(length(keys(seen))>=8)return false;
    seen={...seen};seen[id] = true;
    if (n.protocol == '_balancing') {
        if (n.fallback_node && !proxy_route(values, n.fallback_node, seen)) return false;
        let selection=members(n,values);
        if(!selection.supported || !length(selection.ids))return false;
        for(let member in selection.ids) {
            if(type(values[member])!='object' || values[member].protocol=='_balancing' || !proxy_route(values,member,seen))return false;
        }
        return true;
    }
    return index(['vless','vmess','trojan','shadowsocks','socks','http','hysteria2','tuic','wireguard'], n.protocol) >= 0 &&
        server_address(n.address) && port(n.port)>0;
}
export function socks_route(values) {
    let g = first_section(values, 'global');
    let selected = node_id(g.node) || node_id(g.tcp_node);
    let node = type(values[selected]) == 'object' ? values[selected] : {};
    let balancer = node.protocol == '_shunt' ? node_id(node.default_node) : selected;
    // Prefer an existing dedicated SOCKS attached directly to this Balancer.
    // Shunt can route a probe DIRECT, so main Shunt SOCKS is not certified.
    if (g.socks_enabled == '1') {
        let candidates = [];
        for (let key, n in values)
            if (type(n) == 'object' && n['.type'] == 'socks' && n.enabled == '1' && n.node == balancer &&
                !n.autoswitch_backup_node && !n.autoswitch && (n.enable_autoswitch==null || n.enable_autoswitch=='0') &&
                !n.username && !n.password && port(n.port) &&
                type(values[balancer]) == 'object' && values[balancer].protocol == '_balancing' && proxy_route(values,balancer,{}))
                push(candidates, { port: port(n.port), profile: balancer, order: n['.index'] || 0 });
        sort(candidates, (a,b) => a.order - b.order);
        if (length(candidates)) return candidates[0];
    }
    if (g.enabled == '1' && port(g.node_socks_port) && proxy_route(values,selected,{}))
        return { port: port(g.node_socks_port), profile: selected };
    return null;
}
export function public_ip(s) {
    if (type(s) != 'string' || length(s) > 45) return '';
    let a=ipv4_parts(s);
    if (a) {
        let x=a[0], y=a[1], z=a[2];
        if (max(a[0],a[1],a[2],a[3]) > 255 || x == 0 || x == 10 || x == 127 || x >= 224 ||
            (x == 100 && y >= 64 && y <= 127) || (x == 169 && y == 254) ||
            (x == 172 && y >= 16 && y <= 31) || (x == 192 && (y == 168 || (y == 0 && (z == 0 || z == 2)) || (y == 88 && z == 99))) ||
            (x == 198 && (y == 18 || y == 19 || (y == 51 && z == 100))) || (x == 203 && y == 0 && z == 113)) return '';
        return s;
    }
    // Conservative global IPv6 unicast only; reject embedded IPv4, zone IDs,
    // transition mechanisms, local/reserved and documentation ranges.
    let words=ipv6_words(s);if(!words)return '';
    if (words[0] < 0x2000 || words[0] >= 0x4000 || words[0] == 0x2002 ||
        (words[0] == 0x2001 && (words[1] < 0x0200 || words[1] == 0x0db8)) ||
        (words[0] == 0x3fff && words[1] < 0x1000)) return '';
    let best=-1, bestlen=1;
    for (let i=0;i<8;i++) {
        let j=i;while(j<8 && words[j] == 0) j++;
        if(j-i>bestlen){best=i;bestlen=j-i;} if(j>i)i=j-1;
    }
    let printable=map(words,w=>sprintf('%x',w));
    return best < 0 ? join(':',printable) : join(':',slice(printable,0,best))+'::'+join(':',slice(printable,best+bestlen));
}
export function cache_read() {
    let path='/tmp/proxy-monitor-exit.json', stat=fs.lstat(path);
    if (!stat || stat.type != 'file' || stat.size > 16384 || stat.uid != 0) return {};
    try { let d=json(fs.readfile(path,16385)); return type(d) == 'object' && d.version == 1 ? d : {}; } catch(e) { return {}; }
}
export function exit_cache() {
    let d=cache_read(), last=d.last_success, safe=null;
    if (type(last) == 'object' && public_ip(last.ip) && type(last.checked_at) == 'int' && last.checked_at > 0 &&
        type(last.route) == 'string' && match(last.route,/^socks5h:\/\/127\.0\.0\.1:[0-9]{1,5} → [A-Za-z0-9_]{1,64}$/)) {
        let c=type(last.country) == 'object' ? country_info(last.country.code,'geolocation') : country_info('','unknown');
        safe={ip:public_ip(last.ip),country:c,checked_at:last.checked_at,route:last.route};
    }
    let state=index(['OK','CHECK_FAILED','INVALID_RESPONSE','UNAVAILABLE'],d.state)>=0 ? d.state : 'NOT_CHECKED';
    if(state=='OK' && !safe)state='INVALID_RESPONSE';
    return { state:state,
        checked_at:type(d.checked_at) == 'int' ? d.checked_at : null,
        reason:index(['SOCKS_ROUTE_UNVERIFIED','DEPENDENCY_MISSING','HTTPS_OR_SOCKS_FAILED','BAD_ECHO','NONE'],d.reason)>=0 ? d.reason : 'NONE',
        geo_state:d.geo_state == 'OK' ? 'OK' : 'UNAVAILABLE', last_success:safe };
}
