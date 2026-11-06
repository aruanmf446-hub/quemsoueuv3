-- GAME: migration 20261105191108. Todos os caminhos de entrada online.
CREATE OR REPLACE FUNCTION public.qse_duel_create(p_name text, p_public boolean, p_settings jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid := qse_v3.require_user(); config jsonb; new_room uuid; skin text;
begin
  perform qse_v3.ensure_player(owner);
  if not exists(select 1 from qse_v3.player_profiles p where p.user_id=owner and p.nickname is not null and qse_v3.nickname_valid(p.nickname)) then
    return jsonb_build_object('error','nickname_required','error_code','nickname_required');
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 3 and 32 or p_name ~ '[[:cntrl:]]' then
    return jsonb_build_object('error','invalid_room_name'); end if;
  if p_public is null then return jsonb_build_object('error','invalid_contract'); end if;
  if not exists(select 1 from qse_v3.duel_decks) then return jsonb_build_object('error','no_decks'); end if;
  config := qse_v3.duel_settings(p_settings,null);
  if config is null then return jsonb_build_object('error','invalid_settings'); end if;
  perform qse_v3.duel_leave_others(owner,null);
  insert into qse_v3.duel_rooms(code,name,is_public,admin_id,created_by,settings)
    values(qse_v3.duel_new_code(),btrim(p_name),p_public,owner,owner,config) returning id into new_room;
  select equipped_character_id into skin from qse_v3.player_loadout where user_id = owner;
  insert into qse_v3.duel_members(room_id,user_id,character_id) values(new_room,owner,skin);
  return qse_v3.duel_snapshot(new_room,owner);
end $function$
;
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
end $function$
;
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
  perform qse_v3.duel_sweep(p_room);
  if qse_v3.duel_player_count(p_room) < 2 then return jsonb_build_object('error','not_enough_players'); end if;
  perform qse_v3.duel_begin_match(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $function$
;
