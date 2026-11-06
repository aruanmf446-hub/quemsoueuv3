import {test} from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {createCheckoutHandler} from '../../supabase/game/functions/qse-coin-checkout/handler.js';
import {createWebhookHandler} from '../../supabase/game/functions/qse-stripe-webhook/handler.js';
import {validSignature} from '../../supabase/game/functions/_shared/stripe.js';
globalThis.crypto ??= webcrypto;
const USER='00000000-0000-4000-8000-000000000001',ORDER='00000000-0000-4000-8000-000000000002',REQ='00000000-0000-4000-8000-000000000003';
const GAME='https://shuzporktifgiotvnpbz.supabase.co',NOW=1804500000;
const config={gameUrl:GAME,gameKey:'service-fixture',stripeKey:'sk_test_fixture',webhookSecret:'whsec_fixture'};
const quote={id:ORDER,user_id:USER,coins:'500',amount:990,currency:'brl',live_mode:false,expires_at:NOW+3600,session_id:null};
const session={id:'cs_test_fixture',url:'https://checkout.stripe.com/c/pay/fixture',livemode:false,mode:'payment',metadata:{qse_order:ORDER,qse_user:USER},client_reference_id:ORDER,amount_total:990,currency:'brl',payment_status:'paid',status:'complete',payment_intent:'pi_fixture'};
const body={package_id:'fixture_only',request_id:REQ,expected_amount:990,expected_coins:'500'};
function fixture(options={}) {
 const calls=[];
 const transport=async(url,init={})=>{
  calls.push({url,init});
  const json=(data,status=200)=>new Response(JSON.stringify(data),{status});
  if(url===GAME+'/auth/v1/user')return json({id:USER},options.authStatus||200);
  if(url.endsWith('/qse_coin_order_prepare'))return json(options.quote||quote);
  if(url.endsWith('/qse_coin_order_bind'))return json({id:ORDER});
  if(url.endsWith('/qse_coin_order_complete')||url.endsWith('/qse_coin_order_review'))return json(options.rpcError||{status:'test_paid'});
  if(url==='https://api.stripe.com/v1/checkout/sessions'||url.endsWith('/checkout/sessions/cs_test_fixture'))return json({...session,...options.session});
  if(url.endsWith('/disputes/dp_fixture'))return json({id:'dp_fixture',charge:'ch_fixture',status:options.disputeStatus||'needs_response'});
  if(url.endsWith('/charges/ch_fixture'))return json({id:'ch_fixture',amount:990,currency:'brl',livemode:false,payment_intent:'pi_fixture',amount_refunded:options.noRefund?0:990});
  if(url.endsWith('/payment_intents/pi_fixture'))return json({id:'pi_fixture',amount:990,currency:'brl',livemode:false,metadata:options.unrelated?{}:{qse_order:ORDER}});
  throw new Error('Unexpected destination: '+url);
 };
 return {calls,checkout:createCheckoutHandler({...config,...options.config},transport),webhook:createWebhookHandler({...config,...options.config},transport,()=>NOW)};
}
const rpcCalls=(f,name)=>f.calls.filter(c=>c.url.endsWith('/'+name));
const request=(data=body,headers={})=>new Request(GAME+'/functions/v1/qse-coin-checkout',{method:'POST',headers:{Authorization:'Bearer user-fixture',...headers},body:JSON.stringify(data)});
async function sign(raw,time=NOW,secret=config.webhookSecret) {
 const bytes=new TextEncoder(),key=await crypto.subtle.importKey('raw',bytes.encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 return 't='+time+',v1='+Buffer.from(await crypto.subtle.sign('HMAC',key,bytes.encode(time+'.'+raw))).toString('hex');
}
async function webhookRequest(type='checkout.session.completed',object={id:session.id},overrides={}) {
 const raw=JSON.stringify({id:'evt_fixture',type,livemode:false,data:{object},...overrides});
 return new Request(GAME+'/functions/v1/qse-stripe-webhook',{method:'POST',headers:{'Stripe-Signature':await sign(raw)},body:raw});
}
test('no merchant secrets: checkout disabled without creating orders',async()=>{
 const f=fixture({config:{stripeKey:''}}),r=await f.checkout(request());assert.equal(r.status,503);assert.equal(f.calls.length,0);
});
test('foreign origin and missing/invalid sessions cannot create payments',async()=>{
 let f=fixture();assert.equal((await f.checkout(request(body,{Origin:'https://evil.example'}))).status,403);assert.equal(f.calls.length,0);
 f=fixture({authStatus:401});assert.equal((await f.checkout(request())).status,401);assert.equal(rpcCalls(f,'qse_coin_order_prepare').length,0);
});
test('malformed amount or nonce rejected before order',async()=>{
 for(const data of [{...body,expected_amount:9.9},{...body,expected_coins:'-500'},{...body,request_id:'bad'}]){
  const f=fixture();assert.equal((await f.checkout(request(data))).status,400);assert.equal(rpcCalls(f,'qse_coin_order_prepare').length,0);
 }
});
test('server quote, authenticated identity, stable Stripe idempotency, fixed return URL',async()=>{
 const f=fixture(),r=await f.checkout(request({...body,user_id:'attacker',success_url:'https://evil.example',coins:999999}));
 assert.equal(r.status,200);assert.deepEqual(await r.json(),{order_id:ORDER,url:session.url});
 const prepare=JSON.parse(rpcCalls(f,'qse_coin_order_prepare')[0].init.body);assert.equal(prepare.p_user,USER);
 const call=f.calls.find(c=>c.url==='https://api.stripe.com/v1/checkout/sessions'),form=new URLSearchParams(call.init.body);
 assert.equal(call.init.headers['Idempotency-Key'],'qse-coins-'+ORDER);assert.equal(form.get('line_items[0][price_data][unit_amount]'),'990');
 assert.equal(form.get('success_url'),'https://aruanmf446-hub.github.io/quemsoueuv3/?coin_order='+ORDER);
 assert.equal(form.get('payment_intent_data[metadata][qse_order]'),ORDER);assert.equal(rpcCalls(f,'qse_coin_order_bind').length,1);
 assert.equal(rpcCalls(f,'qse_coin_order_complete').length,0,'checkout never credits coins');
});
test('bound retry reuses checkout; no second Stripe session',async()=>{
 const f=fixture({quote:{...quote,session_id:session.id,checkout_url:session.url}});assert.equal((await f.checkout(request())).status,200);
 assert.equal(f.calls.some(c=>c.url.startsWith('https://api.stripe.com')),false);
});
test('price mismatch and unsafe checkout URLs never returned',async()=>{
 for(const options of [{quote:{...quote,amount:1000}},{session:{url:'https://checkout.stripe.com.evil.example/c/pay/x'}},{session:{livemode:true}},{session:{metadata:{qse_order:REQ,qse_user:USER}}}]) {
  const f=fixture(options);assert.notEqual((await f.checkout(request())).status,200);assert.equal(rpcCalls(f,'qse_coin_order_bind').length,0);
 }
});
test('price changed by server surfaced, without Stripe calls',async()=>{
 const f=fixture({quote:{error:'price_changed'}}),r=await f.checkout(request());assert.equal(r.status,409);assert.equal((await r.json()).code,'price_changed');
 assert.equal(f.calls.some(c=>c.url.startsWith('https://api.stripe.com')),false);
});
test('Stripe signatures use exact raw payload, rotation signatures and freshness',async()=>{
 const raw='{"hello":"ação"}',sig=await sign(raw);
 assert.equal(await validSignature(raw,sig,config.webhookSecret,NOW),true);
 assert.equal(await validSignature(raw+' ',sig,config.webhookSecret,NOW),false);
 assert.equal(await validSignature(raw,await sign(raw,NOW-301),config.webhookSecret,NOW),false);
 assert.equal(await validSignature(raw,await sign(raw,NOW+301),config.webhookSecret,NOW),false);
 assert.equal(await validSignature(raw,sig,config.webhookSecret+'wrong',NOW),false);
 assert.equal(await validSignature(raw,sig+',v1='+'0'.repeat(64),config.webhookSecret,NOW),true);
 assert.equal(await validSignature(raw,'t='+NOW+','+sig,config.webhookSecret,NOW),false);
});
test('invalid signature has zero side effects',async()=>{
 const f=fixture(),r=await f.webhook(new Request(GAME,{method:'POST',headers:{'Stripe-Signature':'wrong'},body:'{}'}));
 assert.equal(r.status,400);assert.equal(f.calls.length,0);
});
test('signed webhook retrieves canonical session, then completes server-side',async()=>{
 const f=fixture(),r=await f.webhook(await webhookRequest());assert.equal(r.status,200);
 const args=JSON.parse(rpcCalls(f,'qse_coin_order_complete')[0].init.body);
 assert.deepEqual(args,{p_order:ORDER,p_session:session.id,p_intent:'pi_fixture',p_amount:990,p_currency:'brl',p_live:false,p_event:'evt_fixture'});
 assert.equal(f.calls[0].url,'https://api.stripe.com/v1/checkout/sessions/'+session.id);
});
test('unpaid, wrong live mode and unrelated Stripe sessions cannot credit',async()=>{
 for(const options of [{session:{payment_status:'unpaid'}},{session:{livemode:true}},{session:{metadata:{}}}]){
  const f=fixture(options);await f.webhook(await webhookRequest());assert.equal(rpcCalls(f,'qse_coin_order_complete').length,0);
 }
 const f=fixture();assert.equal((await f.webhook(await webhookRequest('checkout.session.completed',{id:session.id},{livemode:true}))).status,400);assert.equal(f.calls.length,0);
});
test('database failure requests webhook retry and leaks no error details',async()=>{
 const f=fixture({rpcError:{error:'SECRET INTERNAL DETAIL'}}),r=await f.webhook(await webhookRequest());
 assert.notEqual(r.status,200);assert.equal((await r.json()).code,'payment_service_unavailable');
});
test('canonical refunds and disputes enter manual review',async()=>{
 for(const [type,id,reason] of [['charge.refunded','ch_fixture','refund'],['charge.dispute.created','dp_fixture','dispute']]) {
  const f=fixture(),r=await f.webhook(await webhookRequest(type,{id}));assert.equal(r.status,200);
  const args=JSON.parse(rpcCalls(f,'qse_coin_order_review')[0].init.body);assert.equal(args.p_order,ORDER);assert.equal(args.p_reason,reason);
  assert.equal(rpcCalls(f,'qse_coin_order_complete').length,0);
 }
});
test('unrelated refunds, no actual refund and won disputes do not create holds',async()=>{
 for(const [options,type,id] of [[{unrelated:true},'charge.refunded','ch_fixture'],[{noRefund:true},'charge.refunded','ch_fixture'],[{disputeStatus:'won'},'charge.dispute.closed','dp_fixture']]){
  const f=fixture(options);assert.equal((await f.webhook(await webhookRequest(type,{id}))).status,200);assert.equal(rpcCalls(f,'qse_coin_order_review').length,0);
 }
});
test('unrelated valid event acknowledged without any network mutation',async()=>{
 const f=fixture();assert.equal((await f.webhook(await webhookRequest('customer.created',{id:'cus_fixture'}))).status,200);assert.equal(f.calls.length,0);
});
