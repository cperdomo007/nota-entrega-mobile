import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createExchangeRateService,parseBcv,binanceBase,parseDolarVzla,DOLARVZLA_URL} from '../src/exchange-rates.js';
const html='<div id="dolar"><strong> 889,580000 </strong></div><span class="date-display-single" content="2026-11-02T00:00:00-04:00">date</span>';
const ads=[891,893.2,895,896,898].map(price=>({price,fiat:'VES',asset:'USDT',tradeMethods:['PagoMovil']}));
test('BCV exact parsing requires USD and publication date',()=>{
 assert.equal(parseBcv(html).baseRate,'889.580000');
 assert.throws(()=>parseBcv('<div id="euro"><strong>20</strong>'));
 assert.throws(()=>parseBcv('<div id="dolar"><strong>0</strong></div>'));
});
test('Binance median filters payment and rejects insufficient sample',()=>{
 assert.equal(binanceBase(ads,'PagoMovil').baseRate,'895.000000');
 assert.throws(()=>binanceBase(ads.slice(0,2),'PagoMovil'));
 assert.throws(()=>binanceBase(ads,'BANK'));
});
test('cache, coalescing, persisted last rate, failure and single +6 adjustment',async()=>{
 const dir=await mkdtemp(path.join(tmpdir(),'exchange-'));
 let time=Date.parse('2026-11-02T12:00:00Z'),calls=0,fail=false;
 const fetcher=async url=>{
  calls++;
  if(fail)throw new Error('offline');
  const data=url.includes('trade-methods')?[{identifier:'PagoMovil'}]:{items:ads};
  return {ok:true,text:async()=>url.includes('bcv.org')?html:JSON.stringify({code:'000000',data})};
 };
 const config={fetcher,now:()=>time,cacheFile:path.join(dir,'rates.json')};
 try {
  const service=createExchangeRateService(config);
  const [a,b]=await Promise.all([service.get(),service.get()]);
  assert.equal(a.rates.binance.rate,'901.000000');
  assert.equal(a.rates.bcv.rate,'889.580000');
  assert.equal(b.rates.binance.rate,'901.000000');
  const count=calls;await service.get();assert.equal(calls,count);
  time+=301000;fail=true;
  const stale=await service.get();assert.equal(stale.rates.binance.stale,true);
  assert.equal(stale.rates.binance.rate,'901.000000');
  const restored=await createExchangeRateService(config).get();
  assert.equal(restored.rates.binance.rate,'901.000000');assert.equal(restored.rates.binance.stale,true);
  fail=false;time+=31000;
  assert.equal((await service.get()).rates.binance.stale,false);
 }finally{await rm(dir,{recursive:true,force:true});}
});
test('initial source failure gives null quotes, never simulated rates',async()=>{
 const dir=await mkdtemp(path.join(tmpdir(),'exchange-empty-'));
 try{
 const s=createExchangeRateService({fetcher:async()=>{throw new Error('offline');},cacheFile:path.join(dir,'r.json')});
 assert.deepEqual((await s.get()).rates,{bcv:null,binance:null});
 }finally{await rm(dir,{recursive:true,force:true});}
});

test('authenticated API returns the rate contract and rejects anonymous requests',async()=>{
 const {createApp}=await import('../src/app.js');
 const {token}=await import('../src/security.js');
 let calls=0;
 const expected={rates:{bcv:null,binance:null},cacheSeconds:300};
 const app=await createApp({execute:async()=>[[{id:1,email:'test@example.com',role:'user'}]]},{requireHttps:false,exchangeRates:{get:async()=>{calls++;return expected;}}});
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 try{
  const url='http://127.0.0.1:'+server.address().port+'/api/mobile/v1/exchange-rates';
  assert.equal((await fetch(url)).status,401);assert.equal(calls,0);
  const r=await fetch(url,{headers:{Authorization:'Bearer '+token()}});
  assert.equal(r.status,200);assert.deepEqual(await r.json(),expected);assert.equal(calls,1);
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});

test('DolarVZLA chooses effective Caracas date, not a future published quote',()=>{
 const data={current:{date:'2026-11-03',usd:891.1054},previous:{date:'2026-11-02',usd:889.5754}};
 const beforeMidnight=Date.parse('2026-11-03T02:00:00Z');
 assert.equal(parseDolarVzla(data,beforeMidnight).baseRate,'889.575400');
 assert.equal(parseDolarVzla(data,Date.parse('2026-11-03T05:00:00Z')).baseRate,'891.105400');
 assert.throws(()=>parseDolarVzla({current:{date:'2026-11-03',usd:10}},beforeMidnight));
 assert.throws(()=>parseDolarVzla({current:{date:'2026-11-02',usd:0}},beforeMidnight));
 assert.throws(()=>parseDolarVzla({current:{date:'2026-02-30',usd:10}},beforeMidnight));
 assert.throws(()=>parseDolarVzla({current:{date:'2026-10-01',usd:10}},beforeMidnight));
});
test('BCV TLS failure falls back with source attribution, persistence and no surcharge',async()=>{
 const dir=await mkdtemp(path.join(tmpdir(),'exchange-fallback-'));let offline=false;
 const now=()=>Date.parse('2026-11-02T18:00:00Z');
 const fetcher=async url=>{
  if(offline || url.includes('bcv.org'))throw new Error('source unavailable');
  const data=url===DOLARVZLA_URL?{current:{date:'2026-11-03',usd:891.1054},previous:{date:'2026-11-02',usd:889.5754}}:url.includes('trade-methods')?[{identifier:'PagoMovil'}]:{items:ads};
  return {ok:true,text:async()=>JSON.stringify(url===DOLARVZLA_URL?data:{code:'000000',data})};
 };
 try{
  const config={fetcher,now,cacheFile:path.join(dir,'rates.json')};
  const r=await createExchangeRateService(config).get();
  assert.equal(r.rates.bcv.rate,'889.575400');assert.equal(r.rates.bcv.adjustment,'0.000000');
  assert.equal(r.rates.bcv.source,DOLARVZLA_URL);assert.equal(r.rates.bcv.stale,false);
  assert.equal(r.rates.binance.rate,'901.000000');offline=true;
  const restored=await createExchangeRateService({...config,now:()=>now()+301000}).get();
  assert.equal(restored.rates.bcv.rate,'889.575400');assert.equal(restored.rates.bcv.source,DOLARVZLA_URL);assert.equal(restored.rates.bcv.stale,true);
 }finally{await rm(dir,{recursive:true,force:true});}
});
