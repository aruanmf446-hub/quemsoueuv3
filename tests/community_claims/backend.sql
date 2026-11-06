-- Executed after the GAME migration inside the same transaction, then ROLLBACK.
create temporary table qse_claim_test_checks(label text);
create temporary table qse_claim_test_identity(player uuid,other uuid);
create function pg_temp.check(ok boolean,label text) returns void language plpgsql as $$
begin
 if ok is distinct from true then raise exception 'COMMUNITY_CLAIM_TEST: %',label; end if;
 insert into qse_claim_test_checks values(label);
end;$$;
do $test$
declare
 author uuid:=gen_random_uuid(); reviewer uuid:=gen_random_uuid(); player uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 deck uuid:=gen_random_uuid(); card uuid; version uuid; ref text; result jsonb; source jsonb; i integer; room uuid; match_room uuid;
begin
 insert into auth.users(id,instance_id,aud,role,email,created_at,updated_at)
 select id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','qse-test-'||id::text||'@example.invalid',now(),now()
 from unnest(array[author,reviewer,player,other]) id;
 perform set_config('request.jwt.claim.sub',author::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',author,'role','authenticated')::text,true);
 insert into public.qse_creator_decks(id,owner_id,name,category) values(deck,author,'[ROLLBACK TEST] Community','Personagens');
 for i in 1..5 loop
  card:=gen_random_uuid();
  insert into public.qse_creator_cards(id,deck_id,owner_id,name,position,image_original_path)
  values(card,deck,author,'Carta '||i,i,author::text||'/'||deck::text||'/'||card::text||'_original.png');
  insert into storage.objects(bucket_id,name)
  select 'qse-deck-originals',author::text||'/'||deck::text||'/'||card::text||'_'||format||'.png' from unnest(array['original','library','duel']) format;
 end loop;
 result:=public.qse_deck_publish_request(deck);
 perform pg_temp.check(not result ? 'error','existing publication request');
 insert into public.qse_deck_reviewers(user_id,grant_note) values(reviewer,'Rollback-only automated test');
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',reviewer,'role','authenticated')::text,true);
 result:=public.qse_deck_review_decide(deck,true,null);
 perform pg_temp.check(result->>'status'='published','existing manual approval preserved');
 result:=public.qse_catalog_prepare(deck);
 version:=(result->>'version_id')::uuid; ref:=result->'manifest'->>'id';source:=result;
 perform pg_temp.check(version is not null and jsonb_array_length(result->'manifest'->'cards')=5,'prepare approved five-card version');
 perform pg_temp.check(not result->'manifest' ? 'owner_id' and not result->'manifest' ? 'source','public manifest excludes owner credentials/private source');
 perform pg_temp.check((public.qse_catalog_prepare(deck)->>'version_id')::uuid=version,'preparation retry reuses version');
 result:=public.qse_community_claim(deck,version);
 perform pg_temp.check(result->>'error'='deck_unavailable','unfinalized version cannot be claimed');
 result:=public.qse_catalog_finalize(version);
 perform pg_temp.check((result->>'ready')::boolean,'finalize after private preview distribution');
 perform pg_temp.check(cardinality(qse_v3.duel_deck_cards(array[ref]))=5,'online match resolver has stable cards');
 perform set_config('request.jwt.claim.sub',player::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',player,'role','authenticated')::text,true);
 perform pg_temp.check(not qse_v3.community_deck_allowed(ref,player),'unowned version cannot be selected');
 perform pg_temp.check(qse_v3.duel_settings(jsonb_build_object('deck_ids',jsonb_build_array(ref)),null) is null,'room settings reject bypass of claim');
 result:=public.qse_community_claim(deck,version);
 perform pg_temp.check((result->>'claimed')::boolean and not (result->>'already_owned')::boolean,'claim confirms account entitlement');
 result:=public.qse_community_claim(deck,version);
 perform pg_temp.check((result->>'already_owned')::boolean,'repeated claim is idempotent');
 perform pg_temp.check((select count(*)=1 from public.qse_community_claims where user_id=player and deck_id=deck),'one entitlement per account/deck');
 perform pg_temp.check(jsonb_array_length(public.qse_community_inventory()->'items')=1,'owner inventory sees claimed deck');
 perform pg_temp.check(qse_v3.community_deck_allowed(ref,player),'claimed version is playable');
 perform pg_temp.check(qse_v3.duel_settings(jsonb_build_object('deck_ids',jsonb_build_array(ref)),null) is not null,'room settings accept claimed version');
 perform pg_temp.check((public.qse_duel_decks()->'decks') @> jsonb_build_array(jsonb_build_object('id',ref)),'online selector includes owned version');
 perform pg_temp.check(jsonb_array_length(public.qse_community_manifests(array[ref])->'items')=1,'owner may request signed preview manifest');
 perform qse_v3.ensure_player(player);
 update qse_v3.player_profiles set nickname='QseTest'||left(replace(player::text,'-',''),8) where user_id=player;
 result:=public.qse_duel_create('[ROLLBACK TEST] Community',false,jsonb_build_object('deck_ids',jsonb_build_array(ref),'max_players',3));
 perform pg_temp.check(not result ? 'error','actual online room creation accepts claimed version');
 match_room:=(result->'room'->>'id')::uuid;
 result:=public.qse_duel_add_bot(match_room);
 perform pg_temp.check(not result ? 'error','existing online bot joins community room');
 result:=public.qse_duel_start(match_room);
 perform pg_temp.check(result->'room'->>'status'='in_match','actual online match starts with community deck');
 perform pg_temp.check(jsonb_array_length(result->'match'->'pool')=5,'actual online match pool has all five version cards');
 result:=public.qse_duel_select(match_room,(qse_v3.duel_deck_cards(array[ref]))[1:3]);
 perform pg_temp.check(not result ? 'error','actual online selection accepts stable community IDs');
 perform public.qse_duel_leave(match_room);
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated')::text,true);
 perform pg_temp.check(jsonb_array_length(public.qse_community_inventory()->'items')=0,'other account inventory is isolated');
 perform pg_temp.check(public.qse_community_manifests(array[ref])->>'error'='deck_not_owned','nonmember cannot fetch another account version');
 perform pg_temp.check(not (public.qse_duel_decks()->'decks') @> jsonb_build_array(jsonb_build_object('id',ref)),'unowned version hidden from online selector');
 insert into qse_v3.duel_rooms(code,name,is_public,admin_id,created_by,settings)
 values(qse_v3.duel_new_code(),'[ROLLBACK TEST]',false,player,player,jsonb_build_object('deck_ids',jsonb_build_array(ref))) returning id into room;
 perform qse_v3.ensure_player(other);
 insert into qse_v3.duel_members(room_id,user_id,character_id) select room,other,equipped_character_id from qse_v3.player_loadout where user_id=other;
 perform pg_temp.check(jsonb_array_length(public.qse_community_manifests(array[ref])->'items')=1,'invited opponent may load room cards without permanent gift');
 perform set_config('request.jwt.claim.sub',author::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',author,'role','authenticated')::text,true);
 result:=public.qse_deck_unpublish(deck);
 perform pg_temp.check(not result ? 'error','existing author withdrawal preserved');
 perform pg_temp.check(public.qse_catalog_finalize(version)->>'error'='deck_changed','stale preparation cannot finalize withdrawn content');
 perform set_config('request.jwt.claim.sub',player::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',player,'role','authenticated')::text,true);
 perform pg_temp.check(public.qse_community_claim(deck,version)->>'error'='deck_unavailable','withdrawal blocks new claims');
 perform pg_temp.check(not qse_v3.community_deck_allowed(ref,player),'withdrawal blocks new room selection');
 perform pg_temp.check(jsonb_array_length(public.qse_community_inventory()->'items')=1 and not (public.qse_community_inventory()->'items'->0->>'available')::boolean,'entitlement retained and marked unavailable');
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated')::text,true);
 perform pg_temp.check(public.qse_community_manifests(array[ref])->>'error'='deck_not_owned','withdrawn lobby cannot distribute cards');
 update qse_v3.duel_rooms set status='in_match' where id=room;
 perform pg_temp.check(jsonb_array_length(public.qse_community_manifests(array[ref])->'items')=1,'running match retains immutable card version');
 delete from qse_v3.duel_members where room_id=room and user_id=other;
 perform pg_temp.check(public.qse_community_manifests(array[ref])->>'error'='deck_not_owned','removed opponent loses remote preview access');
 insert into qse_claim_test_identity values(player,other);
 perform set_config('request.jwt.claim.sub',author::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',author,'role','authenticated')::text,true);
 delete from public.qse_creator_cards where deck_id=deck;
 delete from public.qse_creator_decks where id=deck;
 perform set_config('request.jwt.claim.sub',player::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',player,'role','authenticated')::text,true);
 perform pg_temp.check((public.qse_community_inventory()->'items'->0->'available')='false'::jsonb,'deleted source retains unavailable entitlement, not null');
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
 perform pg_temp.check(public.qse_community_inventory()->>'error'='unauthorized','anonymous inventory refused');
 perform pg_temp.check(public.qse_community_claim(deck,version)->>'error'='unauthorized','anonymous claim refused');
 perform pg_temp.check(not has_function_privilege('authenticated','public.qse_catalog_finalize(uuid)','execute'),'players cannot forge finalization');
 perform pg_temp.check(not has_function_privilege('authenticated','public.qse_catalog_prepare(uuid)','execute'),'private source is service-only');
 perform pg_temp.check(not has_table_privilege('authenticated','public.qse_community_versions','select'),'private source table is inaccessible');
 perform pg_temp.check(not has_table_privilege('authenticated','public.qse_community_claims','insert'),'ownership cannot be forged with table writes');
 perform pg_temp.check(not has_table_privilege('authenticated','public.qse_community_claims','truncate'),'new entitlement table has no authenticated TRUNCATE');
end;
$test$;
grant select on qse_claim_test_identity to authenticated;
grant insert on qse_claim_test_checks to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select player::text from qse_claim_test_identity),true);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select player from qse_claim_test_identity),'role','authenticated')::text,true);
do $$ begin
 perform pg_temp.check((select count(*)=1 from public.qse_community_claims),'RLS reads own entitlement');
 begin perform 1 from public.qse_community_versions; raise exception 'private source unexpectedly readable';
 exception when insufficient_privilege then perform pg_temp.check(true,'RLS role cannot read private source'); end;
 begin perform public.qse_catalog_finalize(gen_random_uuid()); raise exception 'finalize unexpectedly executable';
 exception when insufficient_privilege then perform pg_temp.check(true,'authenticated RPC cannot forge finalization'); end;
end;$$;
select set_config('request.jwt.claim.sub',(select other::text from qse_claim_test_identity),true);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select other from qse_claim_test_identity),'role','authenticated')::text,true);
do $$ begin
 perform pg_temp.check((select count(*)=0 from public.qse_community_claims),'RLS hides another account entitlement');
end;$$;
reset role;
select count(*) as checks,0 as failures from qse_claim_test_checks;
