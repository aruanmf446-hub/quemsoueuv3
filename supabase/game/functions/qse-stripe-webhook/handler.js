import {UUID, liveKey, paymentTools, paymentResponse, paymentError, validSignature} from '../_shared/stripe.js';
export function createWebhookHandler(config, transport = fetch, clock = () => Date.now() / 1000) {
 const t = paymentTools(config, transport);
 return async request => {
  try {
   if (request.method !== 'POST') return paymentResponse({code:'method_not_allowed'},405);
   t.ready();
   const raw = await request.text();
   if (raw.length > 1048576 || !await validSignature(raw,request.headers.get('Stripe-Signature'),config.webhookSecret,clock())) t.fail('invalid_signature',400);
   let event; try { event = JSON.parse(raw); } catch { t.fail('invalid_request',400); }
   if (!/^evt_[A-Za-z0-9]+$/.test(event?.id || '') || event.livemode !== liveKey(config.stripeKey)) t.fail('invalid_request',400);
   if (['checkout.session.completed','checkout.session.async_payment_succeeded'].includes(event.type)) {
    const id = event.data?.object?.id;
    if (!/^cs_(test_|live_)?[A-Za-z0-9]+$/.test(id || '')) t.fail('invalid_request',400);
    const session = await t.stripe('checkout/sessions/' + id);
    if (session.id !== id || session.livemode !== event.livemode) t.fail('invalid_checkout');
    if (!session.metadata?.qse_order) return paymentResponse({received:true});
    if (session.mode !== 'payment' || !UUID.test(session.metadata.qse_order)
      || session.client_reference_id !== session.metadata.qse_order) t.fail('invalid_checkout');
    if (session.payment_status !== 'paid' || session.status !== 'complete') return paymentResponse({received:true,pending:true});
    await t.rpc('qse_coin_order_complete',{p_order:session.metadata.qse_order,p_session:id,
     p_intent:session.payment_intent,p_amount:session.amount_total,p_currency:session.currency,
     p_live:session.livemode,p_event:event.id});
   } else if (event.type === 'charge.refunded' || ['charge.dispute.created','charge.dispute.funds_withdrawn','charge.dispute.closed'].includes(event.type)) {
    let chargeId = event.data?.object?.id;
    const reason = event.type === 'charge.refunded' ? 'refund' : 'dispute';
    if (reason === 'dispute') {
     if (!/^dp_[A-Za-z0-9]+$/.test(chargeId || '')) t.fail('invalid_request',400);
     const dispute = await t.stripe('disputes/' + chargeId);
     if (dispute.id !== chargeId) t.fail('invalid_checkout');
     if (dispute.status === 'won' || dispute.status === 'warning_closed') return paymentResponse({received:true});
     chargeId = dispute.charge;
    }
    if (!/^ch_[A-Za-z0-9]+$/.test(chargeId || '')) t.fail('invalid_request',400);
    const charge = await t.stripe('charges/' + chargeId);
    if (charge.id !== chargeId || charge.livemode !== event.livemode) t.fail('invalid_checkout');
    if (!/^pi_[A-Za-z0-9]+$/.test(charge.payment_intent || '')) return paymentResponse({received:true});
    const intent = await t.stripe('payment_intents/' + charge.payment_intent);
    if (intent.id !== charge.payment_intent || intent.livemode !== charge.livemode || intent.amount !== charge.amount || intent.currency !== charge.currency) t.fail('invalid_checkout');
    // Metadata lives on the canonical PaymentIntent, not a client-provided Charge.
    if (!UUID.test(intent.metadata?.qse_order || '')) return paymentResponse({received:true});
    if (reason === 'refund' && !(charge.amount_refunded > 0)) return paymentResponse({received:true});
    await t.rpc('qse_coin_order_review',{p_order:intent.metadata.qse_order,p_intent:charge.payment_intent,
     p_amount:charge.amount,p_currency:charge.currency,p_live:charge.livemode,p_reason:reason,p_event:event.id});
   }
   return paymentResponse({received:true});
  } catch (e) { return paymentError(e); }
 };
}
