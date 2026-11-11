-- GAME: migration 20261105191141. Sorteio unico antes da selecao.
-- Conservar locks de sala, cartas privadas, countdown, reveal e compatibilidade com partidas antigas.
CREATE OR REPLACE FUNCTION qse_v3.duel_begin_match(p_room uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare room qse_v3.duel_rooms; new_match uuid; bot record;
begin
  select * into room from qse_v3.duel_rooms where id = p_room;
  insert into qse_v3.duel_matches(room_id,phase,phase_deadline,settings,pool)
    values(p_room,'selection',now() + make_interval(secs => (room.settings->>'selection_seconds')::integer),room.settings,
      qse_v3.duel_deck_cards(array(select jsonb_array_elements_text(room.settings->'deck_ids'))))
    returning id into new_match;
  insert into qse_v3.duel_match_players(match_id,member_id,user_id,is_bot,nickname,skin_id,lives)
    select new_match,m.id,m.user_id,m.user_id is null,coalesce(m.bot_name,p.nickname,'Sem nickname'),m.character_id,
      (room.settings->>'cards_per_player')::integer
    from qse_v3.duel_members m left join qse_v3.player_profiles p on p.user_id = m.user_id
    where m.room_id = p_room and m.role = 'player';
  -- Bots escolhem na hora (cartas aleatórias) e já ficam PRONTOS.
  for bot in select member_id from qse_v3.duel_match_players where match_id = new_match and is_bot loop
    perform qse_v3.duel_fill_cards(new_match,bot.member_id);
    update qse_v3.duel_match_players set confirmed = true where match_id = new_match and member_id = bot.member_id;
  end loop;
  -- Sorteio UNICO no nascimento da partida, antes da selecao secreta.
  update qse_v3.duel_matches set turn_order = (
    select coalesce(array_agg(member_id order by random()),'{}'::uuid[])
    from qse_v3.duel_match_players where match_id=new_match)
    where id=new_match;
  update qse_v3.duel_rooms set status = 'in_match', match_id = new_match, match_phase = 'selection',
    phase_deadline = (select phase_deadline from qse_v3.duel_matches where id = new_match) where id = p_room;
  perform qse_v3.duel_touch(p_room);
  return new_match;
end $function$
;
CREATE OR REPLACE FUNCTION qse_v3.duel_advance(p_room uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare room qse_v3.duel_rooms; match_row qse_v3.duel_matches; ghost record; order_ids uuid[]; choice text; guard integer := 0;
begin
  select * into room from qse_v3.duel_rooms where id = p_room for update;
  if not found or room.status <> 'in_match' or room.match_id is null then return; end if;
  -- Jogadores reais sem sinal (ou que já não estão na sala) são eliminados por desconexão.
  for ghost in select p.member_id from qse_v3.duel_match_players p left join qse_v3.duel_members m on m.id = p.member_id
      where p.match_id = room.match_id and not p.is_bot and p.eliminated_reason is null
        and (m.id is null or m.last_seen_at < now() - qse_v3.duel_timing('disconnect')) loop
    if qse_v3.duel_eliminate(room.match_id,ghost.member_id,'disconnect') then
      perform qse_v3.duel_event(room.match_id,'eliminated',ghost.member_id,null,
        jsonb_build_array(jsonb_build_object('member_id',ghost.member_id,'eliminated',true,'reason','disconnect')),interval '0');
      perform qse_v3.duel_touch(p_room);
    end if;
  end loop;
  perform qse_v3.duel_fix_admin(p_room);
  loop
    guard := guard + 1;
    exit when guard > 12;
    select * into room from qse_v3.duel_rooms where id = p_room;
    exit when room.status <> 'in_match' or room.match_id is null;
    select * into match_row from qse_v3.duel_matches where id = room.match_id;
    if match_row.phase = 'selection' then
      exit when now() < match_row.phase_deadline and exists(select 1 from qse_v3.duel_match_players
        where match_id = match_row.id and eliminated_reason is null and not confirmed);
      for ghost in select member_id from qse_v3.duel_match_players where match_id = match_row.id and not confirmed loop
        perform qse_v3.duel_fill_cards(match_row.id,ghost.member_id);
        update qse_v3.duel_match_players set confirmed = true, auto_selected = true
          where match_id = match_row.id and member_id = ghost.member_id;
      end loop;
      -- A apresentacao da sequencia precisa terminar antes de iniciar o relogio do turno.
      perform qse_v3.duel_set_phase(match_row.id,'countdown',
        make_interval(secs => greatest(5,ceil(7.0 + 1.8 * cardinality(match_row.turn_order))::integer)));
    elsif match_row.phase = 'countdown' then
      exit when now() < match_row.phase_deadline;
      if qse_v3.duel_check_end(match_row.id) then continue; end if;
      -- Compatibilidade com partidas antigas que iniciaram antes do sorteio antecipado.
      if cardinality(match_row.turn_order) = 0 then
        select array_agg(member_id order by random()) into order_ids from qse_v3.duel_match_players
          where match_id=match_row.id and eliminated_reason is null;
        update qse_v3.duel_matches set turn_order=coalesce(order_ids,'{}'::uuid[]),turn_index=-1
          where id=match_row.id;
      end if;
      perform qse_v3.duel_next_turn(match_row.id);
    elsif match_row.phase = 'turns' then
      if exists(select 1 from qse_v3.duel_match_players where match_id = match_row.id and member_id = match_row.turn_member
          and eliminated_reason is not null) then
        if not qse_v3.duel_check_end(match_row.id) then perform qse_v3.duel_next_turn(match_row.id); end if;
      elsif exists(select 1 from qse_v3.duel_match_players where match_id = match_row.id and member_id = match_row.turn_member and is_bot)
          and now() >= match_row.turn_started_at + qse_v3.duel_timing('bot_think') then
        choice := qse_v3.duel_bot_choice(match_row.id,match_row.turn_member);
        if choice is null then perform qse_v3.duel_apply_timeout(match_row.id,match_row.turn_member);
        else perform qse_v3.duel_pick_card(match_row.id,match_row.turn_member,choice); end if;
      elsif now() >= match_row.phase_deadline then
        perform qse_v3.duel_apply_timeout(match_row.id,match_row.turn_member);
      else
        exit;
      end if;
    elsif match_row.phase = 'reveal' then
      exit when now() < match_row.phase_deadline;
      if not qse_v3.duel_check_end(match_row.id) then perform qse_v3.duel_next_turn(match_row.id); end if;
    elsif match_row.phase = 'finished' then
      exit when now() < match_row.phase_deadline;
      perform qse_v3.duel_return_to_lobby(p_room);
    else
      exit;
    end if;
  end loop;
end $function$
;
