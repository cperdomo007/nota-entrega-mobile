import {readFile, mkdir, writeFile, rename} from 'node:fs/promises';
import path from 'node:path';

export const BCV_URL = 'https://www.bcv.org.ve/';
export const DOLARVZLA_URL = 'https://rates.dolarvzla.com/bcv/current.json';
const caracasDate = milliseconds => new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Caracas',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(milliseconds));
export function parseDolarVzla(data, time = Date.now()) {
  const today = caracasDate(time);
  const valid = [data?.current, data?.previous].filter(r => {
    if (!r || !/^\d{4}-\d{2}-\d{2}$/.test(r.date)) return false;
    const date=Date.parse(r.date+'T00:00:00Z');
    return Number.isFinite(date) && new Date(date).toISOString().slice(0,10)===r.date && r.date<=today && Date.parse(today+'T00:00:00Z')-date<=7*86400000;
  }).sort((a,b)=>b.date.localeCompare(a.date));
  if (!valid.length) throw new Error('No BCV rate effective for today');
  return {baseRate:decimal(units(valid[0].usd)), effectiveAt:new Date(valid[0].date+'T00:00:00-04:00').toISOString()};
}
const BINANCE = 'https://www.binance.com/bapi/c2c/v1/public/c2c/agent/';
const SCALE = 1000000n;
export function units(value) {
  const s = String(value);
  if (!/^\d{1,12}(\.\d{1,6})?$/.test(s)) throw new Error('Invalid positive decimal');
  const [whole, fraction = ''] = s.split('.');
  const n = BigInt(whole) * SCALE + BigInt(fraction.padEnd(6, '0'));
  if (n <= 0n) throw new Error('Invalid positive decimal');
  return n;
}
export function decimal(n) {
  return (n / SCALE).toString() + '.' + (n % SCALE).toString().padStart(6, '0');
}
export function parseBcv(html) {
  const block = html.match(/<div\b[^>]*\bid=["']dolar["'][^>]*>([\s\S]*?)<\/strong>/i);
  const raw = block?.[1].match(/<strong[^>]*>\s*([\d.,\s]+)/i)?.[1]?.replace(/\s/g, '').replaceAll('.', '').replace(',', '.');
  if (!raw) throw new Error('BCV USD not found');
  const date = html.match(/class=["'][^"']*date-display-single[^"']*["'][^>]*content=["']([^"']+)/i)?.[1]
    ?? html.match(/content=["']([^"']+)["'][^>]*class=["'][^"']*date-display-single/i)?.[1];
  if (!date || !Number.isFinite(Date.parse(date))) throw new Error('BCV publication date not found');
  return {baseRate: decimal(units(raw)), effectiveAt: new Date(date).toISOString()};
}
export function binanceBase(items, payment) {
  const prices = items.filter(x => x.fiat === 'VES' && x.asset === 'USDT' && x.tradeMethods?.includes(payment))
    .slice(0, 5).map(x => units(x.price)).sort((a,b) => a < b ? -1 : a > b ? 1 : 0);
  if (prices.length < 3) throw new Error('At least three eligible Binance ads required');
  const m = Math.floor(prices.length / 2);
  return {baseRate: decimal(prices.length % 2 ? prices[m] : (prices[m-1] + prices[m]) / 2n), sampleSize: prices.length};
}
async function request(fetcher, url, json = true) {
  const r = await fetcher(url, {signal: AbortSignal.timeout(12000), redirect: 'error', headers:{'User-Agent':'NotaEntrega/1.0', Accept:json?'application/json':'text/html'}});
  if (!r.ok) throw new Error('Source unavailable');
  const text = await r.text();
  if (text.length > 2000000) throw new Error('Source response too large');
  if (!json) return text;
  const result = JSON.parse(text);
  if (!url.startsWith(BINANCE)) return result;
  if (result.code !== '000000') throw new Error('Binance response rejected');
  return result.data;
}
export function createExchangeRateService({
  fetcher = fetch, now = () => Date.now(),
  cacheFile = process.env.EXCHANGE_CACHE_FILE || path.resolve('.cache/exchange-rates.json'),
  paymentMethod = process.env.BINANCE_PAYMENT_METHOD || 'PagoMovil',
  ttlMs = 300000, retryMs = 30000,
} = {}) {
  let cache = {}, loaded = false, lastAttempt = -Infinity, pending;
  const decorate = (id, value, stale) => value ? {...value, id, stale, adjustment: id === 'binance' ? '6.000000' : '0.000000',
    rate: decimal(units(value.baseRate) + (id === 'binance' ? 6n * SCALE : 0n))} : null;
  async function load() {
    if (loaded) return;
    loaded = true;
    try {
      const stored = JSON.parse(await readFile(cacheFile, 'utf8'));
      for (const id of ['bcv','binance']) {
        const v=stored[id];
        if (v && Number.isFinite(Date.parse(v.updatedAt)) && (id === 'bcv' ? [BCV_URL,DOLARVZLA_URL].includes(v.source) : v.source === BINANCE + 'ad-list') &&
            (id !== 'binance' || v.paymentMethod === paymentMethod)) {units(v.baseRate); cache[id]=v;}
      }
    } catch { /* No valid persisted quote yet. */ }
  }
  async function refresh() {
    lastAttempt=now();
    const timestamp=new Date(now()).toISOString();
    const results=await Promise.allSettled([
      (async()=>{
        try {
          const quote=parseBcv(await request(fetcher,BCV_URL,false));
          if(caracasDate(Date.parse(quote.effectiveAt))>caracasDate(now())) throw new Error('BCV rate not effective yet');
          return {...quote,source:BCV_URL,updatedAt:timestamp};
        } catch {
          return {...parseDolarVzla(await request(fetcher,DOLARVZLA_URL),now()),source:DOLARVZLA_URL,updatedAt:timestamp};
        }
      })(),
      (async()=>{
        const methods=await request(fetcher,BINANCE+'trade-methods?fiat=VES');
        if (!Array.isArray(methods) || !methods.some(m=>m.identifier===paymentMethod)) throw new Error('Payment method unavailable');
        const query=new URLSearchParams({fiat:'VES',asset:'USDT',tradeType:'BUY',limit:'5',order:'asc',tradeMethodIdentifiers:paymentMethod});
        const data=await request(fetcher,BINANCE+'ad-list?'+query);
        return {...binanceBase(data.items || [],paymentMethod), updatedAt:timestamp,source:BINANCE+'ad-list',
          tradeType:'BUY', paymentMethod,methodology:'Mediana de los primeros 5 anuncios elegibles; mínimo 3'};
      })(),
    ]);
    for (const [i,id] of ['bcv','binance'].entries()) {
      if (results[i].status==='fulfilled') cache[id]=results[i].value;
    }
    try {
      await mkdir(path.dirname(cacheFile),{recursive:true});
      const temp=cacheFile+'.tmp';
      await writeFile(temp,JSON.stringify(cache),{mode:0o600}); await rename(temp,cacheFile);
    } catch { /* Device cache also preserves previous successful quotes. */ }
    return results;
  }
  return {
    async get() {
      await load();
      const fresh=['bcv','binance'].every(id=>cache[id] && now()-Date.parse(cache[id].updatedAt)<ttlMs);
      if (!fresh && now()-lastAttempt>=retryMs) {
        pending ??= refresh().finally(()=>{pending=undefined;});
        await pending;
      } else if (pending) await pending;
      const rates={};
      for (const id of ['bcv','binance']) rates[id]=decorate(id,cache[id],!cache[id] || now()-Date.parse(cache[id].updatedAt)>=ttlMs || lastAttempt>Date.parse(cache[id].updatedAt));
      return {rates,cacheSeconds:ttlMs/1000,serverTime:new Date(now()).toISOString()};
    },
  };
}
