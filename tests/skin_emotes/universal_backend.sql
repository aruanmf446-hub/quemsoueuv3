-- GAME: synthetic accounts and product; no persistent purchases or wallet changes.
begin;
do $test$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
 product text:='qa_universal_'||replace(gen_random_uuid()::text,'-',''); r jsonb; item jsonb;
begin
 insert into auth.users(id) values(a),(b);
 perform qse_v3.ensure_player(a);perform qse_v3.ensure_player(b);
 perform qse_v3.post_wallet_entry(a,gen_random_uuid(),'coins',250,'QA rollback universal');
 insert into qse_v3.emote_products(id,name,price_coins,animation_key,active,asset_ready)
 values(product,'QA universal rollback',100,'qa_universal_clip',true,true);
 perform set_config('request.jwt.claim.sub',a::text,true);
 r:=public.qse_emote_purchase(product,gen_random_uuid(),100);
 assert r->>'owned'='true' and r->>'already_owned'='false';
 assert public.qse_emote_purchase(product,gen_random_uuid(),100)->>'already_owned'='true';
 assert (select coins=150 from qse_v3.wallets where user_id=a);
 assert (select count(*)=1 from qse_v3.player_emotes where user_id=a and emote_id=product);
 assert (select count(*)=1 from qse_v3.wallet_transactions where user_id=a and reason='emote:'||product);
 select x into item from jsonb_array_elements(public.qse_emote_shop()->'items') x where x->>'id'=product;
 assert item->>'owned'='true';
 perform set_config('request.jwt.claim.sub',b::text,true);
 select x into item from jsonb_array_elements(public.qse_emote_shop()->'items') x where x->>'id'=product;
 assert item->>'owned'='false';
 assert public.qse_emote_purchase(product,gen_random_uuid(),100)->>'error'='insufficient_funds';
 perform set_config('request.jwt.claim.sub',a::text,true);
 update qse_v3.emote_products set active=false where id=product;
 select x into item from jsonb_array_elements(public.qse_emote_shop()->'items') x where x->>'id'=product;
 assert item->>'owned'='true' and item->>'available'='false';
 assert not exists(select 1 from information_schema.columns where table_schema='qse_v3'
  and table_name='player_emotes' and column_name in ('character_id','skin_id','variant_id'));
 assert not has_table_privilege('authenticated','qse_v3.player_emotes','INSERT');
end;
$test$;
select jsonb_build_object('passed',true,'transaction','rollback','areas',array[
 'account_ownership','one_debit','no_character_binding','another_account_denied',
 'reopened_account_read','retired_item_keeps_ownership','no_direct_grants']) result;
rollback;
