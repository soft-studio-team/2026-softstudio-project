/// WebView(안 보이는 브라우저) 안에서 실행되는 상품정보 추출 스크립트.
///
/// 서버 엔진(Tier 2)이 못 얻는 것을 단말에서 얻기 위한 것이라, 페이지의 JS가
/// JSON-LD/가격을 채운 "뒤"의 렌더된 DOM에서 뽑는다. 데스크톱 프로토타입에서
/// 검증한 로직을 그대로 옮겼다:
///   1) JSON-LD(Product / ProductGroup+hasVariant) — 서버 파서가 놓치는 ProductGroup 포함
///   2) Open Graph 메타
///   3) 범용 DOM (h1 상품명, 첫 가격 "12,345원" 또는 "₩12,345")
///   4) 자라 ÷100 보정(원화를 소수점 2자리로 취급하는 자라 버그)
///
/// 결과는 JSON 문자열로 반환한다(플랫폼 간 evaluateJavascript 반환형 차이를 흡수).
const String productExtractJs = r'''
(function () {
  function asArray(v){ return v==null ? [] : (Array.isArray(v)?v:[v]); }
  function firstStr(v){
    if(v==null) return null;
    if(typeof v==='string') return v.trim()||null;
    if(Array.isArray(v)){ for(var i=0;i<v.length;i++){ var s=firstStr(v[i]); if(s) return s; } return null; }
    if(typeof v==='object') return firstStr(v.name)||firstStr(v.url)||null;
    return String(v);
  }
  function toPrice(x){
    if(x==null) return null;
    if(typeof x==='number') return x>0?Math.round(x):null;
    var s=String(x).replace(/[^0-9.]/g,'');
    if(!s) return null;
    var n=Math.round(parseFloat(s));
    return (isFinite(n)&&n>0)?n:null;
  }

  // ---- JSON-LD ----
  var nodes=[];
  var scripts=document.querySelectorAll('script[type="application/ld+json"]');
  for(var i=0;i<scripts.length;i++){
    var txt=scripts[i].textContent; if(!txt) continue;
    try{
      var stack=[JSON.parse(txt)];
      while(stack.length){
        var node=stack.pop();
        if(Array.isArray(node)){ for(var j=0;j<node.length;j++) stack.push(node[j]); }
        else if(node && typeof node==='object'){
          nodes.push(node);
          if(Array.isArray(node['@graph'])) for(var k=0;k<node['@graph'].length;k++) stack.push(node['@graph'][k]);
        }
      }
    }catch(e){}
  }
  function isProduct(node){
    var t=node['@type']; var ts=Array.isArray(t)?t:[t];
    for(var i=0;i<ts.length;i++){ if(typeof ts[i]==='string' && /product/i.test(ts[i])) return true; }
    return false;
  }
  function collectPrices(node){
    var offers=[].concat(asArray(node.offers));
    asArray(node.hasVariant).forEach(function(v){ offers=offers.concat(asArray(v.offers)); });
    var prices=[], currency=null;
    offers.forEach(function(o){
      if(!o||typeof o!=='object') return;
      if(!currency) currency=firstStr(o.priceCurrency);
      [o.price,o.lowPrice].forEach(function(p){ var n=toPrice(p); if(n) prices.push(n); });
      asArray(o.priceSpecification).forEach(function(s){ if(s){ var n=toPrice(s.price); if(n) prices.push(n); } });
    });
    return {prices:prices, currency:currency};
  }
  var ld=null;
  for(var i=0;i<nodes.length;i++){
    if(!isProduct(nodes[i])) continue;
    var nm=firstStr(nodes[i].name); if(!nm) continue;
    var cp=collectPrices(nodes[i]);
    ld={ name:nm, brand:firstStr(nodes[i].brand), image:firstStr(nodes[i].image),
         price:cp.prices.length?Math.min.apply(null,cp.prices):null, currency:cp.currency };
    break;
  }

  // ---- Open Graph ----
  function meta(keys){
    var ms=document.querySelectorAll('meta');
    for(var i=0;i<ms.length;i++){
      var key=(ms[i].getAttribute('property')||ms[i].getAttribute('name')||'').toLowerCase();
      if(keys.indexOf(key)>=0){ var c=ms[i].getAttribute('content'); if(c && c.trim()) return c.trim(); }
    }
    return null;
  }
  var ogTitle=meta(['og:title','twitter:title']);
  var ogImage=meta(['og:image','og:image:url','twitter:image']);
  var ogPrice=toPrice(meta(['product:price:amount','og:price:amount','product:sale_price:amount']));
  var ogSite=meta(['og:site_name']);

  // ---- 범용 DOM (JSON-LD/OG가 없을 때) ----
  function domName(){
    var h=document.querySelector('h1');
    if(h){ var t=(h.textContent||'').replace(/\s+/g,' ').trim(); if(t.length>=2 && t.length<=140) return t; }
    return null;
  }
  function domPrice(){
    var body=document.body?document.body.innerText:'';
    var m=/([0-9]{1,3}(?:,[0-9]{3})+)\s*원|₩\s?([0-9]{1,3}(?:,[0-9]{3})+)/.exec(body);
    return m ? toPrice(m[1]||m[2]) : null;
  }

  // ---- 조립 ----
  var host=location.hostname;
  var dn = domName();

  // 무인양품처럼 og:title 이 모든 페이지 공용("MUJI 무인양품 공식 온라인스토어")인 곳이
  // 있다. og:title 이 화면 h1 과 전혀 안 겹치면 사이트 공용 제목으로 보고 h1 을 쓴다.
  function overlaps(a,b){
    if(!a||!b) return false;
    return a.indexOf(b.slice(0,8))>=0 || b.indexOf(a.slice(0,8))>=0;
  }
  var useDomName = !!(dn && ogTitle && !overlaps(ogTitle, dn));

  var name;
  if(ld && ld.name) name = ld.name;
  else if(useDomName) name = dn;
  else name = ogTitle || dn;

  var price = (ld&&ld.price)  || ogPrice || domPrice();
  var brand = (ld&&ld.brand) || null;
  var image = (ld&&ld.image) || ogImage || null;

  // 자라: JSON-LD 원화가 실제의 1/100 → ×100 보정 (화면/OG 값에는 적용 안 함)
  if(/(^|\.)zara\.com$/.test(host) && ld && ld.price){ price = ld.price*100; }

  var source={
    name: (ld&&ld.name)?'json-ld':(useDomName?'dom':(ogTitle?'og':(name?'dom':null))),
    price:(ld&&ld.price)?'json-ld':(ogPrice?'og':(price?'dom':null)),
    image:(ld&&ld.image)?'json-ld':(ogImage?'og':null),
    brand:(ld&&ld.brand)?'json-ld':null
  };

  // 봇 검사/차단 페이지 감지 (홈 웜업 재시도 신호)
  var bodyText=document.body?document.body.innerText:'';
  var blocked=/Access Denied|잠시만 기다리십시오|Just a moment|Checking your browser|에러페이지/i.test(bodyText) && bodyText.length<1500;

  return JSON.stringify({
    name:name||null, price:(price||null), brand:brand, image:image,
    siteName:ogSite||null, hasJsonLd:!!ld, blocked:blocked,
    source:source, finalUrl:location.href
  });
})();
''';
