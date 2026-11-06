-- Synthetic fixtures only; every write is reverted. Packages below are NOT product prices.
begin;
do $test$
declare u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); req uuid:=gen_random_uuid();
 o jsonb; t jsonb; v_order uuid; failed boolean:=false; n bigint;
begin
 insert into auth.users(id) values(u),(other_user);
 perform qse_v3.ensure_player(u); perform qse_v3.ensure_player(other_user);
 assert not (select enabled from qse_v3.coin_store_settings);
 assert not exists(select 1 from qse_v3.coin_packages);
 perform set_config('request.jwt.claim.sub','',true);
 assert public.qse_coin_store()->>'error'='unauthorized';
 assert public.qse_coin_order_prepare(u,'qa_pack',req,990,500,false)->>'error'='payments_unavailable';
 insert into qse_v3.coin_packages values('qa_pack','Fixture only',500,990,true);
 update qse_v3.coin_store_settings set enabled=true;
 perform set_config('request.jwt.claim.sub',u::text,true);
 assert jsonb_array_length(public.qse_coin_store()->'packages')=1;
 assert public.qse_coin_order_prepare(u,'qa_pack',req,991,500,false)->>'error'='price_changed';
 assert public.qse_coin_order_prepare(u,'qa_pack',req,990,500,true)->>'error'='payments_unavailable';
 o:=public.qse_coin_order_prepare(u,'qa_pack',req,990,500,false); v_order:=(o->>'id')::uuid;
 assert v_order is not null;
 assert public.qse_coin_order_prepare(u,'qa_pack',req,990,500,false)->>'id'=v_order::text;
 assert public.qse_coin_order_prepare(u,'qa_pack',req,990,600,false)->>'error'='idempotency_conflict';
 perform public.qse_coin_order_bind(v_order,'cs_test_fixture','https://checkout.stripe.com/c/pay/fixture');
 perform public.qse_coin_order_complete(v_order,'cs_test_fixture','pi_test',990,'brl',false,'evt_test');
 assert (select status='test_paid' and transaction_id is null from qse_v3.coin_orders where coin_orders.id=v_order);
 assert (select coins=0 from qse_v3.wallets where user_id=u);
 update qse_v3.coin_store_settings set live_mode=true;
 req:=gen_random_uuid();o:=public.qse_coin_order_prepare(u,'qa_pack',req,990,500,true);v_order:=(o->>'id')::uuid;
 perform public.qse_coin_order_bind(v_order,'cs_live_fixture','https://checkout.stripe.com/c/pay/fixture');
 begin perform public.qse_coin_order_complete(v_order,'cs_live_fixture','pi_real',1,'brl',true,'evt_bad');
 exception when others then failed:=sqlerrm='payment_mismatch'; end;
 assert failed;failed:=false;
 assert (select coins=0 from qse_v3.wallets where user_id=u);
 perform public.qse_coin_order_complete(v_order,'cs_live_fixture','pi_real',990,'brl',true,'evt_real');
 assert public.qse_coin_order_complete(v_order,'cs_live_fixture','pi_real',990,'brl',true,'evt_duplicate')->>'duplicate'='true';
 assert (select coins=500 and gems=0 from qse_v3.wallets where user_id=u);
 assert (select count(*)=1 from qse_v3.wallet_transactions where user_id=u and idempotency_key=v_order);
 -- A fresh order may buy the same consumable package again.
 o:=public.qse_coin_order_prepare(u,'qa_pack',gen_random_uuid(),990,500,true);
 perform public.qse_coin_order_bind((o->>'id')::uuid,'cs_live_second','https://checkout.stripe.com/c/pay/second');
 perform public.qse_coin_order_complete((o->>'id')::uuid,'cs_live_second','pi_second',990,'brl',true,'evt_second');
 assert (select coins=1000 from qse_v3.wallets where user_id=u);
 perform set_config('request.jwt.claim.sub',other_user::text,true);
 assert jsonb_array_length(public.qse_coin_store()->'orders')=0;
 perform public.qse_coin_order_review(v_order,'pi_real',990,'brl',true,'refund','evt_refund');
 begin perform qse_v3.post_wallet_entry(u,gen_random_uuid(),'coins',-100,'QA blocked purchase');
 exception when others then failed:=sqlerrm='payment_review'; end;
 assert failed;
 assert public.qse_coin_order_prepare(u,'qa_pack',gen_random_uuid(),990,500,true)->>'error'='payment_review';
 assert public.qse_coin_order_complete(v_order,'cs_live_fixture','pi_real',990,'brl',true,'evt_late')->>'status'='payment_review';
 assert (select coins=1000 from qse_v3.wallets where user_id=u);
 assert not has_function_privilege('authenticated','public.qse_coin_order_complete(uuid,text,text,integer,text,boolean,text)','execute');
 assert not has_function_privilege('anon','public.qse_coin_store()','execute');
 assert not has_table_privilege('authenticated','qse_v3.coin_orders','TRUNCATE');
 assert not has_table_privilege('authenticated','qse_v3.coin_packages','UPDATE');
 assert (select relrowsecurity from pg_class where oid='qse_v3.coin_orders'::regclass);
 delete from auth.users where auth.users.id=u;
 assert not exists(select 1 from qse_v3.coin_orders where user_id=u);
end;
$test$;
create function qse_v3.qa_fail_coin_order() returns trigger language plpgsql as $$
begin
 if new.status='paid' then raise exception 'qa_order_write_failure'; end if;
 return new;
end $$;
create trigger qa_fail_coin_order before update on qse_v3.coin_orders
 for each row execute function qse_v3.qa_fail_coin_order();
do $test$
declare u uuid:=gen_random_uuid(); o jsonb; failed boolean:=false;
begin
 insert into auth.users(id) values(u);perform qse_v3.ensure_player(u);
 o:=public.qse_coin_order_prepare(u,'qa_pack',gen_random_uuid(),990,500,true);
 perform public.qse_coin_order_bind((o->>'id')::uuid,'cs_live_atomic','https://checkout.stripe.com/c/pay/atomic');
 begin perform public.qse_coin_order_complete((o->>'id')::uuid,'cs_live_atomic','pi_atomic',990,'brl',true,'evt_atomic');
 exception when others then failed:=sqlerrm='qa_order_write_failure'; end;
 assert failed;
 assert (select coins=0 from qse_v3.wallets where user_id=u);
 assert not exists(select 1 from qse_v3.wallet_transactions where user_id=u);
 -- Refund arriving before completion must prevent subsequent coin credit too.
 perform public.qse_coin_order_review((o->>'id')::uuid,'pi_atomic',990,'brl',true,'refund','evt_refund_first');
 assert public.qse_coin_order_complete((o->>'id')::uuid,'cs_live_atomic','pi_atomic',990,'brl',true,'evt_paid_late')->>'status'='payment_review';
 assert (select coins=0 from qse_v3.wallets where user_id=u);
end;
$test$;
select jsonb_build_object('passed',true,'transaction','rollback','areas',array[
 'disabled_by_default','no_invented_products','auth','quote','expected_price','mode_isolation','test_no_credit',
 'idempotent_order','idempotent_credit','coins_only','repeat_purchase','ownership_isolation','refund_hold',
 'late_event','rls','acl','account_cleanup','atomic_rollback','refund_before_payment']) result;
rollback;
