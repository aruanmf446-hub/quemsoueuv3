-- Real GAME functions and tables, synthetic users. Always ROLLBACK; no Stripe charge.
begin;
do $test$
declare u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); req uuid:=gen_random_uuid();
 d uuid:=gen_random_uuid(); o jsonb; oid uuid; r jsonb; failed boolean:=false; initial_coins bigint;
begin
 assert not (select enabled from qse_v3.coin_store_settings);
 assert not (select cosmetics_enabled or deck_credits_required from qse_v3.commerce_settings);
 assert not exists(select 1 from qse_v3.coin_packages where active);
 assert not exists(select 1 from qse_v3.cosmetic_products where active);
 assert not has_table_privilege('authenticated','qse_v3.deck_credit_balances','UPDATE');
 assert not has_table_privilege('authenticated','qse_v3.player_cosmetics','INSERT');
 assert not has_function_privilege('anon','public.qse_cosmetic_purchase(text,uuid,bigint)','EXECUTE');
 insert into auth.users(id) values(u),(other_user);
 perform qse_v3.ensure_player(u); perform qse_v3.ensure_player(other_user);
 perform set_config('request.jwt.claim.sub',u::text,true);
 assert public.qse_cosmetic_shop()->>'deck_credits'='0';
 assert public.qse_cosmetic_purchase('cowboy_style_1',req,100)->>'error'='sales_disabled';
 assert public.qse_coin_order_prepare(u,'coins_100',req,1000,100,false)->>'error'='payments_unavailable';
 -- Free creation continues while the credit policy is off.
 insert into public.qse_creator_decks(id,owner_id,name) values(d,u,'QA deck');
 assert not exists(select 1 from qse_v3.deck_credit_spends where deck_id=d);
 delete from public.qse_creator_decks where id=d;
 update qse_v3.commerce_settings set cosmetics_enabled=true,deck_credits_required=true;
 update qse_v3.cosmetic_products set active=true where id='cowboy_style_1';
 assert public.qse_cosmetic_purchase('cowboy_style_1',req,100)->>'error'='insufficient_funds';
 perform qse_v3.post_wallet_entry(u,gen_random_uuid(),'coins',1000,'qa_commerce');
 r:=public.qse_cosmetic_purchase('cowboy_style_1',req,100);
 assert r->>'owned'='true' and r->>'coins_after'='900';
 assert public.qse_cosmetic_purchase('cowboy_style_1',gen_random_uuid(),100)->>'already_owned'='true';
 assert (select coins=900 from qse_v3.wallets where user_id=u);
 assert public.qse_cosmetic_purchase('cowboy_style_2',req,100)->>'error'='idempotency_conflict';
 assert public.qse_variation_equip('cowboy','style_1')->>'style_id'='style_1';
 assert public.qse_cosmetic_shop()->'equipped'->>'cowboy'='style_1';
 perform set_config('request.jwt.claim.sub',other_user::text,true);
 assert public.qse_variation_equip('cowboy','style_1')->>'error'='not_owned';
 perform set_config('request.jwt.claim.sub',u::text,true);
 -- Existing free and earned characters cannot be sold.
 insert into qse_v3.cosmetic_products values('qa_free','QA free','skin','cowboy',null,200,true);
 assert public.qse_cosmetic_purchase('qa_free',gen_random_uuid(),200)->>'error'='protected_character';
 -- Emote is universal per account, with the real approved animation key.
 update qse_v3.emote_products set active=true where id='samba';
 assert public.qse_emote_purchase('samba',gen_random_uuid(),50)->>'owned'='true';
 assert public.qse_emote_purchase('samba',gen_random_uuid(),50)->>'already_owned'='true';
 assert (select coins=850 from qse_v3.wallets where user_id=u);
 -- Both package kinds follow the same verified order pipeline; test never grants real value.
 update qse_v3.coin_store_settings set enabled=true,live_mode=false;
 update qse_v3.coin_packages set active=true where id='deck_credit';
 o:=public.qse_coin_order_prepare(u,'deck_credit',gen_random_uuid(),1000,1,false);oid:=(o->>'id')::uuid;
 assert o->>'reward_kind'='deck_credits';
 begin update qse_v3.coin_packages set reward_kind='coins' where id='deck_credit';
 exception when others then failed:=sqlerrm='package_kind_immutable'; end;
 assert failed;failed:=false;
 perform public.qse_coin_order_bind(oid,'cs_test_credits','https://checkout.stripe.com/c/pay/fixture');
 perform public.qse_coin_order_complete(oid,'cs_test_credits','pi_testcredits',1000,'brl',false,'evt_testcredits');
 assert not exists(select 1 from qse_v3.deck_credit_balances where user_id=u);
 update qse_v3.coin_store_settings set live_mode=true;
 o:=public.qse_coin_order_prepare(u,'deck_credit',gen_random_uuid(),1000,1,true);oid:=(o->>'id')::uuid;
 perform public.qse_coin_order_bind(oid,'cs_live_credits','https://checkout.stripe.com/c/pay/fixture');
 perform public.qse_coin_order_complete(oid,'cs_live_credits','pi_livecredits',1000,'brl',true,'evt_livecredits');
 assert public.qse_coin_order_complete(oid,'cs_live_credits','pi_livecredits',1000,'brl',true,'evt_again')->>'duplicate'='true';
 assert (select credits=1 from qse_v3.deck_credit_balances where user_id=u);
 assert (select coins=850 from qse_v3.wallets where user_id=u);
 insert into public.qse_creator_decks(id,owner_id,name) values(d,u,'QA deck');
 assert (select credits=0 from qse_v3.deck_credit_balances where user_id=u);
 update public.qse_creator_decks set name='QA deck edited' where id=d;
 assert (select count(*)=1 from qse_v3.deck_credit_spends where user_id=u);
 begin insert into public.qse_creator_decks(owner_id,name) values(u,'QA second deck');
 exception when others then failed:=sqlerrm='insufficient_deck_credits'; end;
 assert failed;
 assert (select count(*)=1 from public.qse_creator_decks where owner_id=u);
 -- Closing sales preserves ownership and equipment, blocks new spending.
 update qse_v3.commerce_settings set cosmetics_enabled=false;
 assert public.qse_variation_equip('cowboy','original')->>'style_id'='original';
 assert public.qse_variation_equip('cowboy','style_1')->>'style_id'='style_1';
end;
$test$;
select 'COMMERCE_BACKEND PASS: ACL, disabled state, real ledger/ownership, protected skins, universal emote, credits, webhook idempotency, deck consumption' result;
rollback;
