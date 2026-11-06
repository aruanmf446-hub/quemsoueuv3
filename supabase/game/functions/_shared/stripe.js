// No SDK/client secrets. Dependency injection keeps payment tests offline.
export const GAME_ORIGIN = 'https://aruanmf446-hub.github.io';
export const GAME_RETURN = GAME_ORIGIN + '/quemsoueuv3/';
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const checkoutUrl = value => {
 try { const u = new URL(value); return u.origin === 'https://checkout.stripe.com' && !u.username && !u.password && u.pathname.startsWith('/c/'); }
 catch { return false; }
};
export const liveKey = key => typeof key === 'string' && key.startsWith('sk_live_');
export function paymentTools(config, transport = fetch) {
 const fail = (code, status = 503) => { throw Object.assign(new Error(code), {code, status}); };
 const json = async (url, init) => {
  const r = await transport(url, {...init, signal: AbortSignal.timeout(20000)});
  if (!r.ok) fail(r.status === 429 ? 'rate_limit' : 'payment_service_unavailable', r.status === 429 ? 429 : 503);
  const data = await r.json();
  if (typeof data?.error === 'string') fail(data.error, 409);
  return data;
 };
 const rpc = (name, body) => json(config.gameUrl + '/rest/v1/rpc/' + name, {
  method:'POST', headers:{apikey:config.gameKey, Authorization:'Bearer ' + config.gameKey, 'Content-Type':'application/json'}, body:JSON.stringify(body),
 });
 const stripe = (path, body = null, idempotency = null) => json('https://api.stripe.com/v1/' + path, {
  method:body ? 'POST' : 'GET', headers:{Authorization:'Bearer ' + config.stripeKey, 'Stripe-Version':'2024-06-20',
   ...(body ? {'Content-Type':'application/x-www-form-urlencoded'} : {}),
   ...(idempotency ? {'Idempotency-Key':idempotency} : {})}, ...(body ? {body:body.toString()} : {}),
 });
 const ready = () => {
  if (!config.gameUrl || !config.gameKey || !/^sk_(live|test)_/.test(config.stripeKey || '') || !config.webhookSecret?.startsWith('whsec_')) fail('payments_unavailable');
 };
 return {fail, json, rpc, stripe, ready};
}
export function paymentResponse(data, status = 200) {
 return new Response(JSON.stringify(data), {status, headers:{'Content-Type':'application/json',
  'Cache-Control':'no-store', 'Access-Control-Allow-Origin':GAME_ORIGIN,
  'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods':'POST, OPTIONS', Vary:'Origin'}});
}
export function paymentError(error) {
 // Never return Stripe error bodies, keys, email, tokens or raw requests.
 const allowed = ['unauthorized','invalid_request','payments_unavailable','payment_review','package_unavailable',
  'price_changed','rate_limit','order_expired','idempotency_conflict','invalid_signature','invalid_checkout'];
 const code = allowed.includes(error?.code) ? error.code : 'payment_service_unavailable';
 return paymentResponse({code}, error?.status || 503);
}
export async function validSignature(raw, header, secret, now = Date.now() / 1000) {
 if (typeof header !== 'string' || header.length > 4096 || !secret) return false;
 const parts = header.split(',').map(p => p.trim().split('='));
 const times = parts.filter(p => p[0] === 't');
 if (times.length !== 1 || !/^\d+$/.test(times[0][1])) return false;
 const timestamp = Number(times[0][1]);
 if (!Number.isSafeInteger(timestamp) || Math.abs(now - timestamp) > 300) return false;
 const encoder = new TextEncoder();
 const key = await crypto.subtle.importKey('raw', encoder.encode(secret), {name:'HMAC', hash:'SHA-256'}, false, ['verify']);
 for (const [kind, hex] of parts) {
  if (kind !== 'v1' || !/^[a-f0-9]{64}$/i.test(hex || '')) continue;
  const signature = Uint8Array.from(hex.match(/../g), n => parseInt(n, 16));
  if (await crypto.subtle.verify('HMAC', key, signature, encoder.encode(timestamp + '.' + raw))) return true;
 }
 return false;
}
