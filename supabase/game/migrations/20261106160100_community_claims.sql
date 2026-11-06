-- GAME owns identity, moderation, entitlements and match validation.
-- CATALOG stores immutable approved previews; no GAME JWT is used as CATALOG auth.
begin;
alter table qse_v3.duel_decks drop constraint duel_decks_id_check;
alter table qse_v3.duel_decks add constraint duel_decks_id_check check(id ~ '^[a-z0-9_]{2,32}$' or id ~ '^community_[0-9a-f]{32}$');
alter table qse_v3.duel_decks drop constraint duel_decks_name_check;
alter table qse_v3.duel_decks add constraint duel_decks_name_check check(char_length(name) between 1 and case when id ~ '^community_[0-9a-f]{32}$' then 60 else 32 end);
create table public.qse_community_versions (
 id uuid primary key default gen_random_uuid(),
 deck_id uuid not null,
 fingerprint text not null,
 source jsonb not null,
 manifest jsonb not null default '{}'::jsonb,
 ready boolean not null default false,
 created_at timestamptz not null default now(),
 unique(deck_id,fingerprint)
);
create table public.qse_community_claims (
 user_id uuid not null references auth.users(id) on delete cascade,
 deck_id uuid not null,
 version_id uuid not null references public.qse_community_versions(id),
 claimed_at timestamptz not null default now(),
 primary key(user_id,deck_id)
);
alter table public.qse_community_versions enable row level security;
alter table public.qse_community_claims enable row level security;
revoke all on public.qse_community_versions, public.qse_community_claims from public,anon,authenticated,service_role;
grant select on public.qse_community_claims to authenticated;
create policy qse_community_claims_own_read on public.qse_community_claims for select to authenticated using(user_id=auth.uid());

-- Private source: only published, complete, server-owned metadata and preview paths.
create function qse_v3.community_source(p_deck uuid) returns jsonb
language sql stable security definer set search_path='' as $function$
 select jsonb_build_object('deck_id',d.id,'name',d.name,'description',d.description,
  'category',d.category,'creator',coalesce(nullif(btrim(p.nickname),''),'Criador da comunidade'),
  'revision',d.updated_at,'cards',c.cards)
 from public.qse_creator_decks d
 left join qse_v3.player_profiles p on p.user_id=d.owner_id
 cross join lateral (
  select count(*) total,count(*) filter(where lib.id is not null and duel.id is not null and nullif(btrim(c.name),'') is not null) valid,
   jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'description',c.description,'revision',c.updated_at,
    'library_path',lib.name,'library_revision',lib.updated_at,'duel_path',duel.name,'duel_revision',duel.updated_at)
    order by c.position,c.id) cards
  from public.qse_creator_cards c
  left join storage.objects lib on lib.bucket_id='qse-deck-originals'
   and lib.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_library.png'
  left join storage.objects duel on duel.bucket_id='qse-deck-originals'
   and duel.name=c.owner_id::text||'/'||c.deck_id::text||'/'||c.id::text||'_duel.png'
  where c.deck_id=d.id and c.owner_id=d.owner_id
 ) c
 where d.id=p_deck and d.status='published' and d.visibility='public' and c.total between 5 and 30 and c.total=c.valid
$function$;
revoke all on function qse_v3.community_source(uuid) from public,anon,authenticated;

create function public.qse_catalog_prepare(p_deck uuid) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare src jsonb; v public.qse_community_versions; ref text; cards jsonb;
begin
 perform 1 from public.qse_creator_decks where id=p_deck for update;
 src:=qse_v3.community_source(p_deck);
 if src is null then return jsonb_build_object('error','deck_unavailable'); end if;
 insert into public.qse_community_versions(deck_id,fingerprint,source)
 values(p_deck,encode(sha256(convert_to(src::text,'UTF8')),'hex'),src)
 on conflict(deck_id,fingerprint) do nothing;
 select * into v from public.qse_community_versions
 where deck_id=p_deck and fingerprint=encode(sha256(convert_to(src::text,'UTF8')),'hex');
 ref:='community_'||replace(v.id::text,'-','');
 select jsonb_agg(jsonb_build_object('id',ref||'/'||(c->>'id'),'name',c->>'name','description',coalesce(c->>'description',''),
  'library_path',v.id::text||'/'||(c->>'id')||'_library.png','duel_path',v.id::text||'/'||(c->>'id')||'_duel.png') order by ord)
 into cards from jsonb_array_elements(src->'cards') with ordinality x(c,ord);
 update public.qse_community_versions set manifest=jsonb_build_object('id',ref,'deck_id',p_deck,'version_id',v.id,
  'name',src->>'name','description',coalesce(src->>'description',''),'category',coalesce(src->>'category',''),
  'creator',src->>'creator','cards',cards,'size',jsonb_array_length(cards)) where id=v.id and not ready;
 select * into v from public.qse_community_versions where id=v.id;
 return jsonb_build_object('version_id',v.id,'ready',v.ready,'source',v.source,'manifest',v.manifest);
end;
$function$;
revoke all on function public.qse_catalog_prepare(uuid) from public,anon,authenticated;
grant execute on function public.qse_catalog_prepare(uuid) to service_role;

create function public.qse_catalog_finalize(p_version uuid) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare v public.qse_community_versions; src jsonb;
begin
 select * into v from public.qse_community_versions where id=p_version;
 if not found then return jsonb_build_object('error','deck_unavailable'); end if;
 perform 1 from public.qse_creator_decks where id=v.deck_id for update;
 src:=qse_v3.community_source(v.deck_id);
 if src is null or encode(sha256(convert_to(src::text,'UTF8')),'hex')<>v.fingerprint then
  return jsonb_build_object('error','deck_changed'); end if;
 update public.qse_community_versions set ready=true where id=v.id;
 insert into qse_v3.duel_decks(id,name,card_ids,sort_order)
 select v.manifest->>'id',v.manifest->>'name',array(select c->>'id' from jsonb_array_elements(v.manifest->'cards') c),1000000
 on conflict(id) do nothing;
 return jsonb_build_object('ready',true,'version_id',v.id);
end;
$function$;
revoke all on function public.qse_catalog_finalize(uuid) from public,anon,authenticated;
grant execute on function public.qse_catalog_finalize(uuid) to service_role;

create function public.qse_community_claim(p_deck uuid,p_version uuid) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare uid uuid:=auth.uid(); v public.qse_community_versions; previous uuid; src jsonb;
begin
 if uid is null then return jsonb_build_object('error','unauthorized'); end if;
 perform 1 from public.qse_creator_decks where id=p_deck for update;
 select * into v from public.qse_community_versions where id=p_version and deck_id=p_deck and ready;
 src:=qse_v3.community_source(p_deck);
 if v.id is null or src is null then return jsonb_build_object('error','deck_unavailable'); end if;
 if encode(sha256(convert_to(src::text,'UTF8')),'hex')<>v.fingerprint then return jsonb_build_object('error','deck_changed'); end if;
 select version_id into previous from public.qse_community_claims where user_id=uid and deck_id=p_deck;
 insert into public.qse_community_claims(user_id,deck_id,version_id) values(uid,p_deck,v.id)
 on conflict(user_id,deck_id) do update set version_id=excluded.version_id;
 return jsonb_build_object('claimed',true,'deck_id',p_deck,'version_id',v.id,'deck_ref',v.manifest->>'id','already_owned',coalesce(previous=v.id,false));
end;
$function$;
revoke all on function public.qse_community_claim(uuid,uuid) from public,anon;
grant execute on function public.qse_community_claim(uuid,uuid) to authenticated;

create function public.qse_community_inventory() returns jsonb
language plpgsql stable security definer set search_path='' as $function$
begin
 if auth.uid() is null then return jsonb_build_object('error','unauthorized'); end if;
 return jsonb_build_object('items',coalesce((select jsonb_agg(v.manifest||jsonb_build_object('available',coalesce(d.status='published' and d.visibility='public',false)) order by c.claimed_at desc)
 from public.qse_community_claims c join public.qse_community_versions v on v.id=c.version_id
 left join public.qse_creator_decks d on d.id=c.deck_id where c.user_id=auth.uid()),'[]'::jsonb));
end;
$function$;
revoke all on function public.qse_community_inventory() from public,anon;
grant execute on function public.qse_community_inventory() to authenticated;

-- Opponents may load the host's chosen version only while they belong to that room.
create function public.qse_community_manifests(p_refs text[]) returns jsonb
language plpgsql stable security definer set search_path='' as $function$
begin
 if auth.uid() is null then return jsonb_build_object('error','unauthorized'); end if;
 if p_refs is null or cardinality(p_refs) not between 1 and 5 or array_position(p_refs,null) is not null then return jsonb_build_object('error','invalid_contract'); end if;
 if exists(select 1 from unnest(p_refs) r where not exists(
  select 1 from public.qse_community_versions v left join public.qse_creator_decks d on d.id=v.deck_id
  where v.ready and v.manifest->>'id'=r and (
   (d.status='published' and d.visibility='public' and exists(select 1 from public.qse_community_claims c where c.user_id=auth.uid() and c.version_id=v.id))
   or exists(select 1 from qse_v3.duel_members m join qse_v3.duel_rooms room on room.id=m.room_id
    where m.user_id=auth.uid() and room.settings->'deck_ids' ? r and
    (room.status='in_match' or (room.status='lobby' and d.status='published' and d.visibility='public')))
  ))) then return jsonb_build_object('error','deck_not_owned'); end if;
 return jsonb_build_object('items',(select jsonb_agg(manifest) from public.qse_community_versions where ready and manifest->>'id'=any(p_refs)));
end;
$function$;
revoke all on function public.qse_community_manifests(text[]) from public,anon;
grant execute on function public.qse_community_manifests(text[]) to authenticated;

create function qse_v3.community_deck_allowed(p_ref text,p_user uuid) returns boolean
language sql stable security definer set search_path='' as $function$
 select exists(select 1 from public.qse_community_claims c join public.qse_community_versions v on v.id=c.version_id
 join public.qse_creator_decks d on d.id=v.deck_id where c.user_id=p_user and v.ready and v.manifest->>'id'=p_ref
 and d.status='published' and d.visibility='public')
$function$;
revoke all on function qse_v3.community_deck_allowed(text,uuid) from public,anon,authenticated;

create or replace function public.qse_duel_decks() returns jsonb
language plpgsql security definer set search_path='' as $function$
declare uid uuid:=qse_v3.require_user();
begin
 return jsonb_build_object('defaults',qse_v3.duel_default_settings(),'decks',coalesce((
  select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'size',cardinality(d.card_ids),'community',d.id like 'community_%') order by d.sort_order,d.name)
  from qse_v3.duel_decks d where d.id not like 'community_%' or qse_v3.community_deck_allowed(d.id,uid)), '[]'::jsonb));
end;
$function$;
CREATE OR REPLACE FUNCTION qse_v3.duel_settings(p_input jsonb, p_base jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  result jsonb := coalesce(p_base,qse_v3.duel_default_settings());
  entry record;
  decks text[];
begin
  if p_input is not null then
    if jsonb_typeof(p_input) <> 'object' then return null; end if;
    for entry in select key,value from jsonb_each(p_input) loop
      if entry.key not in ('max_players','deck_ids','cards_per_player','bots_allowed','turn_seconds',
        'selection_seconds','tiebreak_base','tiebreak_per_player') then return null; end if;
      result := result || jsonb_build_object(entry.key,entry.value);
    end loop;
  end if;
  if not (qse_v3.duel_int_ok(result,'max_players',2,20) and qse_v3.duel_int_ok(result,'cards_per_player',1,6)
    and qse_v3.duel_int_ok(result,'turn_seconds',15,180) and qse_v3.duel_int_ok(result,'selection_seconds',10,120)
    and qse_v3.duel_int_ok(result,'tiebreak_base',4,12) and qse_v3.duel_int_ok(result,'tiebreak_per_player',1,4)
    and jsonb_typeof(result->'bots_allowed') = 'boolean' and jsonb_typeof(result->'deck_ids') = 'array'
    and jsonb_array_length(result->'deck_ids') between 1 and 5) then
    return null;
  end if;
  if exists(select 1 from jsonb_array_elements(result->'deck_ids') e where jsonb_typeof(e) <> 'string') then return null; end if;
  select array_agg(distinct v) into decks from jsonb_array_elements_text(result->'deck_ids') v;
  if (select count(*) from qse_v3.duel_decks where id = any(decks)) <> cardinality(decks) then return null; end if;
  -- A room admin must own each community version they select.
  if exists(select 1 from unnest(decks) id where starts_with(id,'community_')
    and not qse_v3.community_deck_allowed(id,auth.uid())) then return null; end if;
  -- Cada jogador escolhe cartas diferentes entre si: o deck precisa ter cartas suficientes.
  if cardinality(qse_v3.duel_deck_cards(decks)) < (result->>'cards_per_player')::integer then return null; end if;
  return result || jsonb_build_object('deck_ids',to_jsonb(decks));
end $function$;

CREATE OR REPLACE FUNCTION public.qse_duel_start(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  if room.status <> 'lobby' then return jsonb_build_object('error','match_in_progress'); end if;

  if exists (select 1 from qse_v3.duel_members m left join qse_v3.player_profiles p on p.user_id=m.user_id
    where m.room_id=p_room and m.role='player' and m.user_id is not null
      and (p.nickname is null or not qse_v3.nickname_valid(p.nickname))) then
    return jsonb_build_object('error','nickname_required','error_code','nickname_required');
  end if;
  if qse_v3.duel_settings(room.settings,null) is null then
    return jsonb_build_object('error','deck_unavailable'); end if;
  perform qse_v3.duel_sweep(p_room);
  if qse_v3.duel_player_count(p_room) < 2 then return jsonb_build_object('error','not_enough_players'); end if;
  perform qse_v3.duel_begin_match(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $function$;

notify pgrst,'reload schema';
commit;
