-- Real GAME ledger/stock. Synthetic identities; never retain test data.
begin;
do $test$
declare u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); buy_id uuid:=gen_random_uuid(); receipt uuid:=gen_random_uuid(); r jsonb;
begin
 assert not (select active from qse_v3.ability_refill_settings);
 assert not has_table_privilege('authenticated','qse_v3.ability_refill_stock','UPDATE');
 assert not has_table_privilege('authenticated','qse_v3.ability_refill_stock','TRUNCATE');
 assert not has_table_privilege('authenticated','qse_v3.ability_refill_purchases','TRUNCATE');
 assert not has_table_privilege('authenticated','qse_v3.ability_refill_deliveries','TRUNCATE');
 assert not has_function_privilege('anon','public.qse_ability_refill_buy(uuid,bigint)','EXECUTE');
 insert into auth.users(id) values(u),(v);
 perform qse_v3.ensure_player(u);perform qse_v3.ensure_player(v);
 perform set_config('request.jwt.claim.sub',u::text,true);
 assert public.qse_ability_refills()->>'quantity'='0';
 assert public.qse_ability_refill_buy(buy_id,10)->>'error'='sales_disabled';
 update qse_v3.commerce_settings set cosmetics_enabled=true;
 update qse_v3.ability_refill_settings set active=true;
 assert public.qse_ability_refill_buy(buy_id,10)->>'error'='insufficient_funds';
 perform qse_v3.post_wallet_entry(u,gen_random_uuid(),'coins',30,'qa_refills');
 assert public.qse_ability_refill_buy(buy_id,9)->>'error'='price_changed';
 assert public.qse_ability_refill_buy(buy_id,10)->>'purchased'='true';
 assert public.qse_ability_refill_buy(buy_id,10)->>'already_purchased'='true';
 assert (select coins=20 from qse_v3.wallets where user_id=u);
 assert public.qse_ability_refills()->>'quantity'='1';
 assert public.qse_ability_refill_buy(buy_id,11)->>'error'='idempotency_conflict';
 assert public.qse_ability_refill_reserve(gen_random_uuid(),'health')->>'error'='invalid_request';
 r:=public.qse_ability_refill_reserve(receipt,'defense');
 assert r->>'status'='pending' and r->>'ability'='defense';
 assert public.qse_ability_refills()->>'quantity'='0';
 assert jsonb_array_length(public.qse_ability_refills()->'pending')=1;
 assert public.qse_ability_refill_reserve(receipt,'defense')->>'id'=receipt::text;
 assert public.qse_ability_refill_reserve(receipt,'attack')->>'error'='idempotency_conflict';
 assert public.qse_ability_refill_reserve(gen_random_uuid(),'attack')->>'error'='no_refills';
 perform set_config('request.jwt.claim.sub',v::text,true);
 assert public.qse_ability_refill_ack(receipt)->>'error'='receipt_not_found';
 assert jsonb_array_length(public.qse_ability_refills()->'pending')=0;
 perform set_config('request.jwt.claim.sub',u::text,true);
 assert public.qse_ability_refill_ack(receipt)->>'used'='true';
 assert public.qse_ability_refill_ack(receipt)->>'used'='true';
 assert jsonb_array_length(public.qse_ability_refills()->'pending')=0;
 assert public.qse_ability_refill_reserve(receipt,'defense')->>'status'='used';
 -- Consumables can be bought again using a new nonce, without touching other balances.
 assert public.qse_ability_refill_buy(gen_random_uuid(),10)->>'purchased'='true';
 assert public.qse_ability_refills()->>'quantity'='1';
 assert (select coins=10 from qse_v3.wallets where user_id=u);
 update qse_v3.ability_refill_settings set active=false;
 assert public.qse_ability_refill_buy(gen_random_uuid(),10)->>'error'='sales_disabled';
 -- Disabling sales does not remove previously bought refills.
 assert public.qse_ability_refill_reserve(gen_random_uuid(),'attack')->>'status'='pending';
end;
$test$;
select 'ABILITY_REFILLS_BACKEND PASS: disabled, price, wallet, duplicate purchase, stock, pending recovery, isolation, acknowledgement' result;
rollback;
