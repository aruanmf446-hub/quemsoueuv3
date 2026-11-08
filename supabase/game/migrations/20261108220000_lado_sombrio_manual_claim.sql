-- Manual, free opt-in: no automatic claims or backfill. Existing gifts are untouched.
begin;







create or replace function qse_v3.official_deck_allowed(p_deck text,p_user uuid)
returns boolean language sql stable security definer set search_path='' as $function$
 select p_deck <> 'lado_sombrio' or exists (
  select 1 from public.qse_reward_claims c join public.qse_reward_offers o on o.id=c.offer_id
  where c.user_id=p_user and o.item_type='deck' and o.item_id=p_deck
 );
$function$;
revoke all on function qse_v3.official_deck_allowed(text,uuid) from public,anon,authenticated;

insert into qse_v3.duel_decks(id,name,card_ids,sort_order) values ('lado_sombrio','Lado Sombrio',array['lado_sombrio/0DDAFCC2-A4B3-4517-8C32-9FE398AE36ED','lado_sombrio/32845652-37FD-439B-AF87-EA313F81E26F','lado_sombrio/69D90FC2-8763-48B4-B4BA-C3EE6310B9CF','lado_sombrio/87EDBC3E-D04B-4750-B075-695E22EB46A2','lado_sombrio/8DB59DBB-3ECB-4D86-B6EB-D95C87587329','lado_sombrio/AD7AE492-2699-439E-AB72-228408049B5F','lado_sombrio/BBE1237A-5315-4BF6-8E1C-6998B34D75CF','lado_sombrio/F074887D-54D7-4407-ACE3-5FEF839787A0','lado_sombrio/90CFE00B-A415-49BB-AA13-2A444EC4A442','lado_sombrio/A06F4A32-DF09-46E2-8DA3-92D6D79DA2CB'],5) on conflict(id) do update set name=excluded.name,card_ids=excluded.card_ids,sort_order=excluded.sort_order;

insert into public.qse_reward_campaigns(id,title,subtitle,description,active,priority)
values ('lado_sombrio_2026','QSE ORIGINALS — LADO SOMBRIO','10 cartas originais',
'Resgate gratuitamente o Lado Sombrio para liberar as 10 cartas na sua Biblioteca e no Mata-Mata.',true,120);
insert into public.qse_reward_offers(id,campaign_id,item_type,item_id,title,description,price,active,sort_order,auto_grant)
values ('deck_lado_sombrio','lado_sombrio_2026','deck','lado_sombrio','Lado Sombrio',
'10 personagens QSE Originals. Disponível na Biblioteca e para jogar somente após o resgate.',0,true,0,false);

CREATE OR REPLACE FUNCTION public.qse_rewards_feed()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_uid uuid := (select auth.uid());
 v_campaign public.qse_reward_campaigns%rowtype;
 v_offers jsonb;
begin
 if v_uid is null then return jsonb_build_object('ok',false,'code','not_authenticated'); end if;
 select * into v_campaign from public.qse_reward_campaigns
 where active and starts_at<=now() and (ends_at is null or ends_at>now())
 order by priority desc,starts_at desc limit 1;
 if not found then
  return jsonb_build_object('ok',true,'campaign',null,'seen',true,'revealed',true,'offers','[]'::jsonb);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',o.id,'kind',o.item_type,'item_id',o.item_id,'title',o.title,
  'description',o.description,'price',o.price,'auto_grant',o.auto_grant,'campaign_id',o.campaign_id,
  'claimed',cl.claimed_at is not null,'claimed_at',cl.claimed_at,
  'claim_enabled',(o.item_type='deck' or (
   o.item_type='skin' and o.item_id in
     ('cowboy','michelly','rodrigo','lorena','gus','lana','halloween')
   and exists(select 1 from qse_v3.character_catalog ch
     where ch.id=o.item_id and ch.initially_unlocked=true)
  ))
 ) order by o.sort_order,o.id),'[]'::jsonb)
 into v_offers from public.qse_reward_offers o
 join public.qse_reward_campaigns offer_campaign on offer_campaign.id=o.campaign_id
 left join public.qse_reward_claims cl on cl.offer_id=o.id and cl.user_id=v_uid
 where (o.campaign_id=v_campaign.id or (not o.auto_grant and cl.claimed_at is null))
 and offer_campaign.active and offer_campaign.starts_at<=now()
 and (offer_campaign.ends_at is null or offer_campaign.ends_at>now())
 and o.active and o.price=0;
 return jsonb_build_object(
  'ok',true,
  'campaign',jsonb_build_object('id',v_campaign.id,'title',v_campaign.title,
                               'subtitle',v_campaign.subtitle,'description',v_campaign.description),
  'seen',exists(select 1 from public.qse_news_seen s
                where s.user_id=v_uid and s.campaign_id=v_campaign.id),
  'revealed',exists(select 1 from public.qse_reward_reveals r
                    where r.user_id=v_uid and r.campaign_id=v_campaign.id),
  'offers',v_offers);
end $function$;

CREATE OR REPLACE FUNCTION public.qse_rewards_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := (select auth.uid());
  v_items jsonb;
begin
  if v_user is null then
    return jsonb_build_object('ok',false,'code','not_authenticated');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,
    'kind',o.item_type,
    'item_id',o.item_id,
    'campaign_id',o.campaign_id,
    'title',o.title,
    'description',o.description,
    'price',o.price,
    'auto_grant',o.auto_grant,
    'created_at',o.created_at,
    'claimed',true,
    'claimed_at',cl.claimed_at,
    'claim_enabled',false,
    'revealed',(r.user_id is not null)
  ) order by campaign.priority desc,o.sort_order,o.id), '[]'::jsonb)
  into v_items
  from public.qse_reward_claims cl
  join public.qse_reward_offers o on o.id=cl.offer_id
  join public.qse_reward_campaigns campaign on campaign.id=o.campaign_id
  left join public.qse_reward_reveals r on r.user_id=cl.user_id
                                             and r.campaign_id=o.campaign_id
  where cl.user_id=v_user and o.item_type in ('deck','skin') and o.price=0;
  return jsonb_build_object('ok',true,'offers',v_items);
end
$function$;

CREATE OR REPLACE FUNCTION public.qse_duel_decks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=qse_v3.require_user();
begin
 return jsonb_build_object('defaults',qse_v3.duel_default_settings(),'decks',coalesce((
  select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'size',cardinality(d.card_ids),'community',d.id like 'community_%') order by d.sort_order,d.name)
  from qse_v3.duel_decks d where (d.id not like 'community_%' or qse_v3.community_deck_allowed(d.id,uid))
  and qse_v3.official_deck_allowed(d.id,uid)), '[]'::jsonb));
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
  if exists(select 1 from unnest(decks) id where not qse_v3.official_deck_allowed(id,auth.uid())) then return null; end if;
  -- A room admin must own each community version they select.
  if exists(select 1 from unnest(decks) id where starts_with(id,'community_')
    and not qse_v3.community_deck_allowed(id,auth.uid())) then return null; end if;
  -- Cada jogador escolhe cartas diferentes entre si: o deck precisa ter cartas suficientes.
  if cardinality(qse_v3.duel_deck_cards(decks)) < (result->>'cards_per_player')::integer then return null; end if;
  return result || jsonb_build_object('deck_ids',to_jsonb(decks));
end $function$;

CREATE OR REPLACE FUNCTION public.qse_duel_join(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; clean text; skin text;
begin
  perform qse_v3.ensure_player(owner);
  if not exists(select 1 from qse_v3.player_profiles p where p.user_id=owner and p.nickname is not null and qse_v3.nickname_valid(p.nickname)) then
    return jsonb_build_object('error','nickname_required','error_code','nickname_required');
  end if;
  clean := upper(regexp_replace(coalesce(p_code,''),'[^A-Za-z0-9]','','g'));
  if clean !~ '^[A-HJ-NP-Z2-9]{6}$' then return jsonb_build_object('error','room_not_found'); end if;
  select r.* into room from qse_v3.duel_rooms r where r.code = clean for update;
  if not found then return jsonb_build_object('error','room_not_found'); end if;
  if room.status = 'closed' then return jsonb_build_object('error','room_closed'); end if;
  if exists(select 1 from jsonb_array_elements_text(room.settings->'deck_ids') d(id)
    where not qse_v3.official_deck_allowed(d.id,owner)) then
    return jsonb_build_object('error','deck_claim_required'); end if;
  if exists(select 1 from qse_v3.duel_kicks where room_id = room.id and user_id = owner) then
    return jsonb_build_object('error','kicked'); end if;
  if exists(select 1 from qse_v3.duel_members where room_id = room.id and user_id = owner) then
    update qse_v3.duel_members set last_seen_at = now() where room_id = room.id and user_id = owner;
    return qse_v3.duel_snapshot(room.id,owner);
  end if;
  perform qse_v3.duel_sweep(room.id);
  if room.status = 'lobby' and qse_v3.duel_player_count(room.id) >= (room.settings->>'max_players')::integer then
    return jsonb_build_object('error','room_full'); end if;
  perform qse_v3.duel_leave_others(owner,room.id);
  select equipped_character_id into skin from qse_v3.player_loadout where user_id = owner;
  insert into qse_v3.duel_members(room_id,user_id,character_id,role)
    values(room.id,owner,skin,case when room.status = 'lobby' then 'player' else 'spectator' end);
  perform qse_v3.duel_touch(room.id);
  perform qse_v3.duel_fix_admin(room.id);
  return qse_v3.duel_snapshot(room.id,owner);
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
  if exists(select 1 from qse_v3.duel_members m cross join
    jsonb_array_elements_text(room.settings->'deck_ids') d(id)
    where m.room_id=p_room and m.user_id is not null
      and not qse_v3.official_deck_allowed(d.id,m.user_id)) then
    return jsonb_build_object('error','deck_claim_required'); end if;
  perform qse_v3.duel_sweep(p_room);
  if qse_v3.duel_player_count(p_room) < 2 then return jsonb_build_object('error','not_enough_players'); end if;
  perform qse_v3.duel_begin_match(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $function$;

commit;
