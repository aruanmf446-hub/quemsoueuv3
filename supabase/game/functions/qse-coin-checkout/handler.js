import {GAME_ORIGIN, GAME_RETURN, UUID, checkoutUrl, liveKey, paymentTools, paymentResponse, paymentError} from '../_shared/stripe.js';
export function createCheckoutHandler(config, transport = fetch) {
 const t = paymentTools(config, transport);
 return async request => {
  try {
   const origin = request.headers.get('Origin');
   if (origin && origin !== GAME_ORIGIN) return paymentResponse({code:'forbidden'},403);
   if (request.method === 'OPTIONS') return paymentResponse({});
   if (request.method !== 'POST') return paymentResponse({code:'method_not_allowed'},405);
   t.ready();
   const auth = request.headers.get('Authorization') || '';
   if (!/^Bearer \S+$/.test(auth) || auth.length > 8192) t.fail('unauthorized',401);
   const authResponse = await transport(config.gameUrl + '/auth/v1/user', {
    headers:{apikey:config.gameKey, Authorization:auth}, signal:AbortSignal.timeout(15000),
   });
   if (!authResponse.ok) t.fail('unauthorized',401);
   const user = await authResponse.json();
   if (!UUID.test(user.id)) t.fail('unauthorized',401);
   const raw = await request.text();
   if (raw.length > 4096) t.fail('invalid_request',400);
   let input; try { input = JSON.parse(raw); } catch { t.fail('invalid_request',400); }
   if (!/^[a-z0-9_]{1,64}$/.test(input?.package_id || '') || !UUID.test(input?.request_id || '') ||
     !Number.isSafeInteger(input?.expected_amount) || input.expected_amount < 50 ||
     !/^[1-9][0-9]{0,9}$/.test(input?.expected_coins || '')) t.fail('invalid_request',400);
   const order = await t.rpc('qse_coin_order_prepare', {p_user:user.id,p_package:input.package_id,
    p_request:input.request_id,p_expected_amount:input.expected_amount,p_expected_coins:input.expected_coins,p_live:liveKey(config.stripeKey)});
   if (!UUID.test(order.id) || order.user_id !== user.id || order.live_mode !== liveKey(config.stripeKey)
     || order.amount !== input.expected_amount || order.coins !== input.expected_coins || order.currency !== 'brl') t.fail('invalid_checkout');
   if (order.session_id && checkoutUrl(order.checkout_url)) return paymentResponse({order_id:order.id,url:order.checkout_url});
   const form = new URLSearchParams({mode:'payment',locale:'pt-BR',client_reference_id:order.id,
    success_url:GAME_RETURN + '?coin_order=' + order.id,cancel_url:GAME_RETURN + '?coin_order=' + order.id,
    expires_at:String(order.expires_at), 'payment_method_types[0]':'card',
    'metadata[qse_order]':order.id,'metadata[qse_user]':user.id,
    'payment_intent_data[metadata][qse_order]':order.id,
    'line_items[0][price_data][currency]':'brl',
    'line_items[0][price_data][unit_amount]':String(order.amount),
    'line_items[0][price_data][product_data][name]':order.coins + (order.reward_kind === 'deck_credits' ? ' crédito(s) de deck' : ' moedas') + ' — Quem Sou Eu V3',
    'line_items[0][quantity]':'1',
   });
   const session = await t.stripe('checkout/sessions',form,'qse-coins-' + order.id);
   if (!checkoutUrl(session.url) || !/^cs_(test_|live_)?[A-Za-z0-9]+$/.test(session.id || '') ||
     session.client_reference_id !== order.id || session.metadata?.qse_order !== order.id ||
     session.metadata?.qse_user !== user.id || session.mode !== 'payment' ||
     session.amount_total !== order.amount || session.currency !== 'brl' || session.livemode !== order.live_mode) t.fail('invalid_checkout');
   await t.rpc('qse_coin_order_bind',{p_order:order.id,p_session:session.id,p_url:session.url});
   return paymentResponse({order_id:order.id,url:session.url});
  } catch (e) { return paymentError(e); }
 };
}
