-- Dados inteiramente sintéticos e revertidos; não altera carteiras de jogadores.
begin;
do $test$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); req uuid:=gen_random_uuid();
 fail_req uuid:=gen_random_uuid(); r jsonb; failed boolean:=false;
begin
 insert into auth.users(id) values(a),(b);
 perform qse_v3.ensure_player(a); perform qse_v3.ensure_player(b);
 perform qse_v3.post_wallet_entry(a,gen_random_uuid(),'coins',250,'QA rollback setup');
 perform qse_v3.post_wallet_entry(a,gen_random_uuid(),'gems',33,'QA rollback setup');
 perform set_config('request.jwt.claim.sub','',true);
 assert public.qse_emote_purchase('dance_01',req,100)->>'error'='unauthorized';
 perform set_config('request.jwt.claim.sub',a::text,true);
 assert public.qse_emote_purchase('dance_01',req,100)->>'error'='emote_unavailable';
 assert (public.qse_emote_shop()->'items'->0->>'price_coins')='100';
 assert (public.qse_emote_shop()->'items'->0->>'available')='false';
 insert into qse_v3.emote_products(id,name,price_coins,animation_key,active,asset_ready)
 values('qa_dance','QA',100,'qa_clip',true,true),('qa_other','QA',100,'qa_clip',true,true);
 assert public.qse_emote_purchase('qa_dance',req,1)->>'error'='price_changed';
 r:=public.qse_emote_purchase('qa_dance',req,100);
 assert r->>'owned'='true' and r->>'already_owned'='false';
 assert (select coins=150 and gems=33 from qse_v3.wallets where user_id=a);
 assert public.qse_emote_purchase('qa_dance',req,100)->>'already_owned'='true';
 assert public.qse_emote_purchase('qa_dance',gen_random_uuid(),100)->>'already_owned'='true';
 assert (select coins=150 from qse_v3.wallets where user_id=a);
 assert (select count(*)=1 from qse_v3.wallet_transactions where user_id=a and reason='emote:qa_dance');
 assert (select count(*)=1 from qse_v3.player_emotes where user_id=a and emote_id='qa_dance');
 assert public.qse_emote_purchase('qa_other',req,100)->>'error'='idempotency_conflict';
 perform set_config('request.jwt.claim.sub',b::text,true);
 assert public.qse_emote_purchase('qa_dance',gen_random_uuid(),100)->>'error'='insufficient_funds';
 assert (select count(*)=0 from qse_v3.player_emotes where user_id=b);
 assert not exists(select 1 from jsonb_array_elements(public.qse_emote_shop()->'items') x where (x->>'owned')::boolean);
 assert not has_table_privilege('authenticated','qse_v3.player_emotes','INSERT');
 assert not has_table_privilege('authenticated','qse_v3.player_emotes','SELECT');
 assert not has_table_privilege('authenticated','qse_v3.player_emotes','TRUNCATE');
 assert not has_table_privilege('authenticated','qse_v3.emote_products','UPDATE');
 assert not has_function_privilege('anon','public.qse_emote_purchase(text,uuid,bigint)','EXECUTE');
 assert has_function_privilege('authenticated','public.qse_emote_purchase(text,uuid,bigint)','EXECUTE');
 assert (select relrowsecurity from pg_class where oid='qse_v3.player_emotes'::regclass);
 delete from auth.users where id=a;
 assert not exists(select 1 from qse_v3.player_emotes where user_id=a);
 assert not exists(select 1 from qse_v3.wallet_transactions where user_id=a);
end;
$test$;
-- Uma falha ao conceder o item deve reverter o débito na mesma operação.
create function qse_v3.qa_fail_emote_insert() returns trigger language plpgsql as $$
begin raise exception 'qa_insert_failure'; end; $$;
create trigger qa_fail_emote_insert before insert on qse_v3.player_emotes
for each row execute function qse_v3.qa_fail_emote_insert();
do $test$
declare u uuid:=gen_random_uuid(); req uuid:=gen_random_uuid(); failed boolean:=false;
begin
 insert into auth.users(id) values(u);perform qse_v3.ensure_player(u);
 perform qse_v3.post_wallet_entry(u,gen_random_uuid(),'coins',200,'QA rollback setup');
 perform set_config('request.jwt.claim.sub',u::text,true);
 begin perform public.qse_emote_purchase('qa_dance',req,100);
 exception when others then failed:=sqlerrm='qa_insert_failure'; end;
 assert failed;
 assert (select coins=200 from qse_v3.wallets where user_id=u);
 assert not exists(select 1 from qse_v3.wallet_transactions where user_id=u and idempotency_key=req);
 assert not exists(select 1 from qse_v3.player_emotes where user_id=u);
end;
$test$;
select jsonb_build_object('passed',true,'transaction','rollback','areas',array[
 'auth','price100','asset_unavailable','purchase','coins_only','owned','idempotency',
 'insufficient_funds','isolation','acl','rls','account_cleanup','atomic_rollback']) result;
rollback;
