-- Requires the manual-claim migration. All generated test data is rolled back.
-- SQL identities simulate authenticated users, not real HTTP sessions.
begin;
do $test$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); x jsonb; room_id uuid; code text; future_campaign text:='future_'||substr(replace(gen_random_uuid()::text,'-',''),1,12);
begin
 insert into auth.users(id,aud,role) values(a,'authenticated','authenticated'),(b,'authenticated','authenticated');
 perform qse_v3.ensure_player(a); perform qse_v3.ensure_player(b);
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform public.qse_profile_update('ClaimA'||substr(replace(a::text,'-',''),1,8));
 perform qse_reward_seed_user(a);
 assert not qse_v3.official_deck_allowed('lado_sombrio',a), 'seed must not grant manual offer';
 x:=public.qse_rewards_feed();
 assert exists(select 1 from jsonb_array_elements(x->'offers') o where o->>'item_id'='lado_sombrio' and o->>'claimed'='false' and o->>'auto_grant'='false'), 'manual offer missing';
 assert not exists(select 1 from jsonb_array_elements(public.qse_rewards_inventory()->'offers') o where o->>'item_id'='lado_sombrio'), 'inventory leaked before claim';
 assert not exists(select 1 from jsonb_array_elements(public.qse_duel_decks()->'decks') d where d->>'id'='lado_sombrio'), 'online catalogue leaked';
 assert qse_v3.duel_settings('{"deck_ids":["lado_sombrio"],"cards_per_player":3}',null) is null, 'direct settings bypass';
 perform public.qse_rewards_mark_seen('lado_sombrio_2026');
 insert into public.qse_reward_campaigns(id,title,active,priority) values(future_campaign,'Temporary SQL test',true,121);
 assert exists(select 1 from jsonb_array_elements(public.qse_rewards_feed()->'offers') o where o->>'item_id'='lado_sombrio' and o->>'claimed'='false'), 'future campaign buried pending manual pack';
 delete from public.qse_reward_campaigns where id=future_campaign;
 perform public.qse_rewards_reveal('lado_sombrio_2026');
 assert not qse_v3.official_deck_allowed('lado_sombrio',a), 'view/reveal must not claim';
 x:=public.qse_rewards_claim('deck_lado_sombrio');
 assert x->>'ok'='true', 'explicit claim failed';
 x:=public.qse_rewards_claim('deck_lado_sombrio');
 assert x->>'status'='already_claimed', 'repeat claim not idempotent';
 assert (select count(*)=1 from public.qse_reward_claims where user_id=a and offer_id='deck_lado_sombrio'), 'duplicate claim';
 assert qse_v3.official_deck_allowed('lado_sombrio',a), 'claim failed to unlock';
 assert exists(select 1 from jsonb_array_elements(public.qse_duel_decks()->'decks') d where d->>'id'='lado_sombrio'), 'claimed deck not playable';
 assert exists(select 1 from jsonb_array_elements(public.qse_rewards_inventory()->'offers') o where o->>'item_id'='lado_sombrio' and o->>'auto_grant'='false'), 'receipt missing';
 x:=public.qse_duel_create('Claim test',false,'{"deck_ids":["lado_sombrio"],"cards_per_player":3}');
 assert x->'room'->>'id' is not null, 'claimed deck room creation failed';
 room_id:=(x->'room'->>'id')::uuid; code:=x->'room'->>'code';
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform public.qse_profile_update('ClaimB'||substr(replace(b::text,'-',''),1,8));
 assert not qse_v3.official_deck_allowed('lado_sombrio',b), 'claim leaked to another account';
 x:=public.qse_duel_join(code);
 assert x->>'error'='deck_claim_required', 'unclaimed user joined protected deck';
 -- Simulate an already joined player before the admin selects this pack.
 insert into qse_v3.duel_members(room_id,user_id,character_id,role) values(room_id,b,'cowboy','player');
 perform set_config('request.jwt.claim.sub',a::text,true);
 x:=public.qse_duel_start(room_id);
 assert x->>'error'='deck_claim_required', 'start bypassed participant claim';
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform public.qse_rewards_claim('deck_lado_sombrio');
 x:=public.qse_duel_join(code);
 assert x->'room'->>'id'=room_id::text, 'claimed participant cannot rejoin';
 perform set_config('request.jwt.claim.sub',a::text,true);
 x:=public.qse_duel_start(room_id);
 assert x->'match' is not null and not x ? 'error', 'claimed players cannot start';
 perform set_config('request.jwt.claim.sub','',true);
 x:=public.qse_rewards_claim('deck_lado_sombrio');
 assert x->>'ok'='false', 'anonymous claim allowed';
end $test$;
select 'PASS: seed, feed, view/ignore, claim, duplicate, inventory, settings, join, start, account isolation, anonymous' as result;
rollback;
