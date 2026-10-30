-- Duelo / Multiplayer — etapa 2: a partida. Seleção secreta das cartas, contagem regressiva,
-- sorteio da ordem, turnos com votação, eliminação de personagens (atinge todos que têm a
-- carta), vidas x cartas, faltas por não votar, bots, saída/desconexão e fim da partida.
-- A vitória matemática antecipada e o desempate reduzido são a etapa 3.
--
-- Sem servidor de jogo: o tempo avança de forma "preguiçosa". Toda chamada de um
-- participante (o sinal de vida vem a cada 2 s) executa qse_v3.duel_advance, que processa
-- os prazos vencidos com a sala travada. Assim ninguém precisa confiar no relógio do cliente.
begin;

create table qse_v3.duel_matches (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  room_id uuid not null references qse_v3.duel_rooms(id) on delete cascade,
  phase text not null check (phase in ('selection','countdown','turns','reveal','finished')),
  phase_deadline timestamptz not null,
  settings jsonb not null,
  pool text[] not null,
  removed text[] not null default '{}',
  turn_order uuid[] not null default '{}',
  turn_index integer not null default -1,
  turn_member uuid,
  turn_started_at timestamptz,
  result jsonb,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index duel_matches_room on qse_v3.duel_matches(room_id);
alter table qse_v3.duel_rooms add column match_id uuid references qse_v3.duel_matches(id) on delete set null;
create index duel_rooms_match on qse_v3.duel_rooms(match_id);

-- Participantes da disputa (fotografia do momento do início). lives e cartas são contadores
-- separados: falta tira vida sem tirar carta; eliminação de personagem tira os dois.
create table qse_v3.duel_match_players (
  match_id uuid not null references qse_v3.duel_matches(id) on delete cascade,
  member_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  is_bot boolean not null,
  nickname text not null,
  skin_id text not null,
  lives integer not null check (lives >= 0),
  faults integer not null default 0 check (faults between 0 and 2),
  confirmed boolean not null default false,
  auto_selected boolean not null default false,
  eliminated_reason text check (eliminated_reason in ('lives','faults','left','disconnect')),
  eliminated_at timestamptz,
  primary key (match_id,member_id)
);
create index duel_match_players_user on qse_v3.duel_match_players(user_id);

-- Cartas secretas: nunca saem do servidor, exceto para o próprio dono ou depois de perdidas.
create table qse_v3.duel_match_cards (
  match_id uuid not null,
  member_id uuid not null,
  card_id text not null,
  lost boolean not null default false,
  primary key (match_id,member_id,card_id),
  foreign key (match_id,member_id) references qse_v3.duel_match_players(match_id,member_id) on delete cascade
);

-- Linha do tempo pública da partida. Em 'pick', quem foi atingido (hits) só é entregue aos
-- clientes depois de reveal_at: a revelação acontece com suspense, sem vazar antes.
create table qse_v3.duel_match_events (
  match_id uuid not null references qse_v3.duel_matches(id) on delete cascade,
  seq integer not null,
  kind text not null check (kind in ('pick','timeout','eliminated','finished')),
  actor uuid,
  card_id text,
  hits jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  reveal_at timestamptz not null default now(),
  primary key (match_id,seq)
);

do $rls$
declare item text;
begin
  foreach item in array array['duel_matches','duel_match_players','duel_match_cards','duel_match_events'] loop
    execute format('alter table qse_v3.%I enable row level security',item);
    execute format('revoke all on qse_v3.%I from public,anon,authenticated',item);
    execute format('grant all on qse_v3.%I to service_role',item);
  end loop;
end $rls$;

-- Tempos fixos da apresentação (segundos).
create function qse_v3.duel_timing(p_key text) returns interval language sql immutable set search_path = '' as $$
  select make_interval(secs => case p_key
    when 'countdown' then 5      -- 5... 4... 3... 2... 1...
    when 'suspense' then 2.5     -- carta escolhida em destaque antes de mostrar os atingidos
    when 'reveal' then 6.5       -- suspense + resultado, até o próximo turno
    when 'timeout' then 3.5      -- aviso de falta
    when 'finished' then 9       -- campeão na tela antes de voltar ao lobby
    when 'bot_think' then 2.5    -- bot "pensando" na vez dele
    when 'disconnect' then 30    -- sem sinal por mais que isso durante a partida = desconectado
    else 0 end)
$$;

-- ---------------------------------------------------------------------------------------
-- Peças internas
-- ---------------------------------------------------------------------------------------
create function qse_v3.duel_set_phase(p_match uuid,p_phase text,p_wait interval) returns void language plpgsql security definer set search_path = '' as $$
declare v_room uuid;
begin
  update qse_v3.duel_matches set phase = p_phase, phase_deadline = now() + p_wait where id = p_match returning duel_matches.room_id into v_room;
  update qse_v3.duel_rooms set match_phase = p_phase, phase_deadline = now() + p_wait where id = v_room;
  perform qse_v3.duel_touch(v_room);
end $$;

create function qse_v3.duel_event(p_match uuid,p_kind text,p_actor uuid,p_card text,p_hits jsonb,p_suspense interval) returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into qse_v3.duel_match_events(match_id,seq,kind,actor,card_id,hits,reveal_at)
    select p_match,coalesce(max(seq),0) + 1,p_kind,p_actor,p_card,coalesce(p_hits,'[]'::jsonb),now() + p_suspense
    from qse_v3.duel_match_events where match_id = p_match;
end $$;

create function qse_v3.duel_eliminate(p_match uuid,p_member uuid,p_reason text) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update qse_v3.duel_match_players set eliminated_reason = p_reason, eliminated_at = now()
    where match_id = p_match and member_id = p_member and eliminated_reason is null;
  return found;
end $$;

-- Cartas aleatórias distintas para quem não confirmou a tempo (permitido só na seleção).
create function qse_v3.duel_fill_cards(p_match uuid,p_member uuid) returns void language plpgsql security definer set search_path = '' as $$
declare match_row qse_v3.duel_matches;
begin
  select * into match_row from qse_v3.duel_matches where id = p_match;
  delete from qse_v3.duel_match_cards where match_id = p_match and member_id = p_member;
  insert into qse_v3.duel_match_cards(match_id,member_id,card_id)
    select p_match,p_member,c from unnest(match_row.pool) c order by random()
    limit (match_row.settings->>'cards_per_player')::integer;
end $$;

create function qse_v3.duel_begin_match(p_room uuid) returns uuid language plpgsql security definer set search_path = '' as $$
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
  update qse_v3.duel_rooms set status = 'in_match', match_id = new_match, match_phase = 'selection',
    phase_deadline = (select phase_deadline from qse_v3.duel_matches where id = new_match) where id = p_room;
  perform qse_v3.duel_touch(p_room);
  return new_match;
end $$;

-- Próximo jogador vivo na ordem sorteada (circular).
create function qse_v3.duel_next_turn(p_match uuid) returns void language plpgsql security definer set search_path = '' as $$
declare match_row qse_v3.duel_matches; total integer; step integer; candidate integer; member uuid;
begin
  select * into match_row from qse_v3.duel_matches where id = p_match;
  total := cardinality(match_row.turn_order);
  for step in 1..total loop
    candidate := (match_row.turn_index + step) % total;
    member := match_row.turn_order[candidate + 1];
    if exists(select 1 from qse_v3.duel_match_players where match_id = p_match and member_id = member and eliminated_reason is null) then
      update qse_v3.duel_matches set turn_index = candidate, turn_member = member, turn_started_at = now() where id = p_match;
      perform qse_v3.duel_set_phase(p_match,'turns',make_interval(secs => (match_row.settings->>'turn_seconds')::integer));
      return;
    end if;
  end loop;
end $$;

-- Volta todos ao lobby da mesma sala, com as configurações preservadas. Espectadores
-- voltam a ser jogadores enquanto houver vaga.
create function qse_v3.duel_return_to_lobby(p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
declare room qse_v3.duel_rooms; ghost record;
begin
  select * into room from qse_v3.duel_rooms where id = p_room;
  update qse_v3.duel_rooms set status = 'lobby', match_phase = null, phase_deadline = null, match_id = null where id = p_room;
  for ghost in select id from qse_v3.duel_members where room_id = p_room and role = 'spectator' order by joined_at loop
    exit when qse_v3.duel_player_count(p_room) >= (room.settings->>'max_players')::integer;
    update qse_v3.duel_members set role = 'player' where id = ghost.id;
  end loop;
  perform qse_v3.duel_touch(p_room);
  perform qse_v3.duel_fix_admin(p_room);
end $$;

-- Fim da partida (regras desta etapa): sem jogadores reais vivos, a sala é encerrada
-- (nunca há bot campeão); com 1 vivo, ele vence; com 0, empate (o desempate é a etapa 3).
create function qse_v3.duel_check_end(p_match uuid) returns boolean language plpgsql security definer set search_path = '' as $$
declare alive integer; real_alive integer; winners jsonb; v_room uuid;
begin
  select count(*),count(*) filter (where not is_bot),coalesce(jsonb_agg(member_id) ,'[]'::jsonb)
    into alive,real_alive,winners from qse_v3.duel_match_players where match_id = p_match and eliminated_reason is null;
  select m.room_id into v_room from qse_v3.duel_matches m where m.id = p_match;
  if real_alive = 0 then
    update qse_v3.duel_matches set phase = 'finished', finished_at = now(), result = jsonb_build_object('reason','only_bots','winners','[]'::jsonb)
      where id = p_match;
    update qse_v3.duel_rooms set status = 'closed', closed_at = now(), match_phase = null, phase_deadline = null, admin_id = null
      where id = v_room;
    perform qse_v3.duel_touch(v_room);
    return true;
  end if;
  if alive <= 1 then
    update qse_v3.duel_matches set finished_at = now(),
      result = jsonb_build_object('reason',case when alive = 1 then 'last_standing' else 'draw' end,'winners',winners)
      where id = p_match;
    perform qse_v3.duel_event(p_match,'finished',null,null,winners,interval '0');
    perform qse_v3.duel_set_phase(p_match,'finished',qse_v3.duel_timing('finished'));
    return true;
  end if;
  return false;
end $$;

-- Eliminar uma carta (personagem do deck): sai do jogo e atinge TODOS os vivos que têm a
-- carta (inclusive quem escolheu). Cada atingido perde a carta e uma vida; sem vidas, é eliminado.
create function qse_v3.duel_pick_card(p_match uuid,p_actor uuid,p_card text) returns void language plpgsql security definer set search_path = '' as $$
declare hits jsonb := '[]'::jsonb; target record;
begin
  update qse_v3.duel_matches set removed = array_append(removed,p_card) where id = p_match;
  for target in select c.member_id from qse_v3.duel_match_cards c join qse_v3.duel_match_players p using(match_id,member_id)
      where c.match_id = p_match and c.card_id = p_card and not c.lost and p.eliminated_reason is null loop
    update qse_v3.duel_match_cards set lost = true where match_id = p_match and member_id = target.member_id and card_id = p_card;
    update qse_v3.duel_match_players set lives = greatest(lives - 1,0) where match_id = p_match and member_id = target.member_id;
    if (select lives from qse_v3.duel_match_players where match_id = p_match and member_id = target.member_id) = 0 then
      perform qse_v3.duel_eliminate(p_match,target.member_id,'lives');
    end if;
    hits := hits || jsonb_build_array((select jsonb_build_object('member_id',member_id,'lives',lives,
      'eliminated',eliminated_reason is not null) from qse_v3.duel_match_players where match_id = p_match and member_id = target.member_id));
  end loop;
  perform qse_v3.duel_event(p_match,'pick',p_actor,p_card,hits,qse_v3.duel_timing('suspense'));
  perform qse_v3.duel_set_phase(p_match,'reveal',qse_v3.duel_timing('reveal'));
end $$;

-- Turno sem voto: falta. 1ª falta tira uma vida (não tira carta); 2ª falta elimina,
-- mesmo que não sejam seguidas. Nunca se escolhe carta aleatória nos turnos.
create function qse_v3.duel_apply_timeout(p_match uuid,p_member uuid) returns void language plpgsql security definer set search_path = '' as $$
declare player qse_v3.duel_match_players;
begin
  update qse_v3.duel_match_players set faults = least(faults + 1,2) where match_id = p_match and member_id = p_member
    returning * into player;
  if player.faults >= 2 then
    perform qse_v3.duel_eliminate(p_match,p_member,'faults');
  else
    update qse_v3.duel_match_players set lives = greatest(lives - 1,0) where match_id = p_match and member_id = p_member
      returning * into player;
    if player.lives = 0 then perform qse_v3.duel_eliminate(p_match,p_member,'lives'); end if;
  end if;
  perform qse_v3.duel_event(p_match,'timeout',p_member,null,(select jsonb_build_array(jsonb_build_object('member_id',member_id,
    'lives',lives,'faults',faults,'eliminated',eliminated_reason is not null)) from qse_v3.duel_match_players
    where match_id = p_match and member_id = p_member),interval '0');
  perform qse_v3.duel_set_phase(p_match,'reveal',qse_v3.duel_timing('timeout'));
end $$;

-- Bot da etapa 2: escolhe ao acaso entre os personagens disponíveis, evitando os próprios
-- quando possível. (Estratégia melhor fica para a etapa 3.)
create function qse_v3.duel_bot_choice(p_match uuid,p_member uuid) returns text language sql volatile security definer set search_path = '' as $$
  select c from qse_v3.duel_matches m, unnest(m.pool) c
  where m.id = p_match and not (c = any(m.removed))
  order by exists(select 1 from qse_v3.duel_match_cards k where k.match_id = p_match and k.member_id = p_member
    and k.card_id = c and not k.lost), random()
  limit 1
$$;

-- Processa tudo que já venceu, em ordem, com a sala travada. Chamado por toda chamada.
create function qse_v3.duel_advance(p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
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
      perform qse_v3.duel_set_phase(match_row.id,'countdown',qse_v3.duel_timing('countdown'));
    elsif match_row.phase = 'countdown' then
      exit when now() < match_row.phase_deadline;
      if qse_v3.duel_check_end(match_row.id) then continue; end if;
      select array_agg(member_id order by random()) into order_ids from qse_v3.duel_match_players
        where match_id = match_row.id and eliminated_reason is null;
      update qse_v3.duel_matches set turn_order = order_ids, turn_index = -1 where id = match_row.id;
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
end $$;

-- ADM: jogador real presente e, durante a partida, ainda vivo na disputa. Se o ADM sair ou
-- for eliminado, sorteia entre os jogadores reais vivos (nunca um bot); sem nenhum, entre os
-- reais da sala; sem nenhum real, a sala é encerrada.
create or replace function qse_v3.duel_fix_admin(p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
declare room qse_v3.duel_rooms; chosen uuid; alive_real uuid[];
begin
  select * into room from qse_v3.duel_rooms where id = p_room and status <> 'closed';
  if not found then return; end if;
  if room.status = 'in_match' and room.match_id is not null then
    select array_agg(p.user_id) into alive_real from qse_v3.duel_match_players p
      join qse_v3.duel_members m on m.id = p.member_id
      where p.match_id = room.match_id and not p.is_bot and p.eliminated_reason is null;
  end if;
  if room.admin_id is not null and exists(select 1 from qse_v3.duel_members where room_id = p_room and user_id = room.admin_id)
      and (alive_real is null or room.admin_id = any(alive_real)) then
    return;
  end if;
  select user_id into chosen from qse_v3.duel_members where room_id = p_room and user_id is not null
    order by (alive_real is not null and user_id = any(alive_real)) desc, (role = 'player') desc, random() limit 1;
  if chosen is null then
    update qse_v3.duel_rooms set status = 'closed', closed_at = now(), admin_id = null, match_phase = null,
      phase_deadline = null where id = p_room;
  elsif chosen is distinct from room.admin_id then
    update qse_v3.duel_rooms set admin_id = chosen where id = p_room;
  else
    return;
  end if;
  perform qse_v3.duel_touch(p_room);
end $$;

-- Partida vista por um participante: cartas próprias, cartas já perdidas de todos e o que
-- já foi revelado. Nunca as cartas secretas dos outros.
create function qse_v3.duel_match_json(p_match uuid,p_viewer_member uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id',m.id,'phase',m.phase,'deadline',m.phase_deadline,'server_now',now(),
    'turn_member',m.turn_member,'turn_order',to_jsonb(m.turn_order),'result',m.result,
    'cards_per_player',(m.settings->>'cards_per_player')::integer,
    'pool',(select coalesce(jsonb_agg(jsonb_build_object('card_id',c,'removed',c = any(m.removed)) order by o),'[]'::jsonb)
      from unnest(m.pool) with ordinality as x(c,o)),
    'players',(select coalesce(jsonb_agg(jsonb_build_object('member_id',p.member_id,'nickname',p.nickname,'skin_id',p.skin_id,
        'is_bot',p.is_bot,'lives',p.lives,'faults',p.faults,'confirmed',p.confirmed,'eliminated',p.eliminated_reason is not null,
        'reason',p.eliminated_reason,'is_you',p.member_id = p_viewer_member,
        'cards_left',(select count(*) from qse_v3.duel_match_cards k where k.match_id = p.match_id and k.member_id = p.member_id and not k.lost),
        'lost',(select coalesce(jsonb_agg(k.card_id),'[]'::jsonb) from qse_v3.duel_match_cards k
          where k.match_id = p.match_id and k.member_id = p.member_id and k.lost))
      order by array_position(m.turn_order,p.member_id),p.nickname),'[]'::jsonb)
      from qse_v3.duel_match_players p where p.match_id = m.id),
    'my_cards',(select coalesce(jsonb_agg(jsonb_build_object('card_id',k.card_id,'lost',k.lost) order by k.card_id),'[]'::jsonb)
      from qse_v3.duel_match_cards k where k.match_id = m.id and k.member_id = p_viewer_member),
    'events',(select coalesce(jsonb_agg(jsonb_build_object('seq',e.seq,'kind',e.kind,'actor',e.actor,'card_id',e.card_id,
        'at',e.created_at,'reveal_at',e.reveal_at,'revealed',now() >= e.reveal_at,
        'hits',case when now() >= e.reveal_at then e.hits else null end) order by e.seq),'[]'::jsonb)
      from (select * from qse_v3.duel_match_events where match_id = m.id order by seq desc limit 10) e))
  from qse_v3.duel_matches m where m.id = p_match
$$;

create or replace function qse_v3.duel_snapshot(p_room uuid,p_viewer uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'room',jsonb_build_object('id',r.id,'code',r.code,'name',r.name,'is_public',r.is_public,'status',r.status,
      'match_phase',r.match_phase,'phase_deadline',r.phase_deadline,'settings',r.settings,'revision',r.revision,
      'decks',qse_v3.duel_decks_json(array(select jsonb_array_elements_text(r.settings->'deck_ids')))),
    'you',(select jsonb_build_object('member_id',m.id,'role',m.role,'is_admin',m.user_id = r.admin_id)
      from qse_v3.duel_members m where m.room_id = r.id and m.user_id = p_viewer),
    'members',coalesce((select jsonb_agg(jsonb_build_object(
        'member_id',m.id,'is_bot',m.user_id is null,'is_admin',m.user_id is not null and m.user_id = r.admin_id,
        'is_you',m.user_id = p_viewer,'role',m.role,'character_id',m.character_id,
        'nickname',coalesce(m.bot_name,p.nickname,'Sem nickname'),'public_id',p.public_id,
        'online',m.user_id is null or m.last_seen_at > now() - interval '20 seconds')
      order by m.joined_at,m.id)
      from qse_v3.duel_members m left join qse_v3.player_profiles p on p.user_id = m.user_id
      where m.room_id = r.id),'[]'::jsonb),
    'match',case when r.match_id is null then null else qse_v3.duel_match_json(r.match_id,
      (select m.id from qse_v3.duel_members m where m.room_id = r.id and m.user_id = p_viewer)) end)
  from qse_v3.duel_rooms r where r.id = p_room
$$;

-- Saída voluntária durante a partida elimina (a disputa continua sem ele).
create or replace function qse_v3.duel_leave_room(p_owner uuid,p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
declare room qse_v3.duel_rooms; member uuid;
begin
  select * into room from qse_v3.duel_rooms where id = p_room;
  select id into member from qse_v3.duel_members where room_id = p_room and user_id = p_owner;
  if member is null then return; end if;
  if room.status = 'in_match' and room.match_id is not null and qse_v3.duel_eliminate(room.match_id,member,'left') then
    perform qse_v3.duel_event(room.match_id,'eliminated',member,null,
      jsonb_build_array(jsonb_build_object('member_id',member,'eliminated',true,'reason','left')),interval '0');
  end if;
  delete from qse_v3.duel_members where id = member;
  perform qse_v3.duel_touch(p_room);
  perform qse_v3.duel_fix_admin(p_room);
  perform qse_v3.duel_advance(p_room);
end $$;

-- ---------------------------------------------------------------------------------------
-- API pública (novas e substituídas)
-- ---------------------------------------------------------------------------------------
create or replace function public.qse_duel_start(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  if room.status <> 'lobby' then return jsonb_build_object('error','match_in_progress'); end if;
  perform qse_v3.duel_sweep(p_room);
  if qse_v3.duel_player_count(p_room) < 2 then return jsonb_build_object('error','not_enough_players'); end if;
  perform qse_v3.duel_begin_match(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

create or replace function public.qse_duel_heartbeat(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms;
begin
  update qse_v3.duel_members set last_seen_at = now() where room_id = p_room and user_id = owner;
  if not found then
    select r.* into room from qse_v3.duel_rooms r where r.id = p_room;
    return jsonb_build_object('member',false,'status',coalesce(room.status,'closed'),'revision',coalesce(room.revision,0));
  end if;
  perform qse_v3.duel_sweep(p_room);
  perform qse_v3.duel_advance(p_room);
  select r.* into room from qse_v3.duel_rooms r where r.id = p_room;
  return jsonb_build_object('member',exists(select 1 from qse_v3.duel_members where room_id = p_room and user_id = owner),
    'status',room.status,'revision',room.revision,'server_now',now());
end $$;

create or replace function public.qse_duel_room(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin
  if not exists(select 1 from qse_v3.duel_members where room_id = p_room and user_id = owner) then
    return jsonb_build_object('error','not_member'); end if;
  perform qse_v3.duel_advance(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

-- Seleção secreta: exatamente N cartas distintas dos decks da partida.
create function public.qse_duel_select(p_room uuid,p_cards text[]) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; match_row qse_v3.duel_matches; member uuid;
begin
  perform qse_v3.duel_advance(p_room);
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  select * into match_row from qse_v3.duel_matches where id = room.match_id;
  if room.status <> 'in_match' or match_row.phase is distinct from 'selection' then
    return jsonb_build_object('error','not_selection_phase'); end if;
  select p.member_id into member from qse_v3.duel_match_players p join qse_v3.duel_members m on m.id = p.member_id
    where p.match_id = match_row.id and m.user_id = owner and p.eliminated_reason is null;
  if member is null then return jsonb_build_object('error','not_in_match'); end if;
  if p_cards is null or cardinality(p_cards) <> (match_row.settings->>'cards_per_player')::integer
      or (select count(distinct c) from unnest(p_cards) c) <> cardinality(p_cards)
      or exists(select 1 from unnest(p_cards) c where not (c = any(match_row.pool))) then
    return jsonb_build_object('error','invalid_selection'); end if;
  delete from qse_v3.duel_match_cards where match_id = match_row.id and member_id = member;
  insert into qse_v3.duel_match_cards(match_id,member_id,card_id) select match_row.id,member,c from unnest(p_cards) c;
  update qse_v3.duel_match_players set confirmed = true where match_id = match_row.id and member_id = member;
  perform qse_v3.duel_touch(p_room);
  perform qse_v3.duel_advance(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

-- Voto do jogador da vez: a carta sai do jogo e atinge todos que a possuem.
create function public.qse_duel_pick(p_room uuid,p_card text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; match_row qse_v3.duel_matches; member uuid;
begin
  perform qse_v3.duel_advance(p_room);
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  select * into match_row from qse_v3.duel_matches where id = room.match_id;
  if room.status <> 'in_match' or match_row.phase is distinct from 'turns' then return jsonb_build_object('error','not_your_turn'); end if;
  select id into member from qse_v3.duel_members where room_id = p_room and user_id = owner;
  if member is distinct from match_row.turn_member then return jsonb_build_object('error','not_your_turn'); end if;
  if p_card is null or not (p_card = any(match_row.pool)) or p_card = any(match_row.removed) then
    return jsonb_build_object('error','card_unavailable'); end if;
  perform qse_v3.duel_pick_card(match_row.id,member,p_card);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

-- Durante a partida, o ADM pode expulsar espectadores e quem já foi eliminado (Ghost),
-- nunca um jogador vivo.
create or replace function public.qse_duel_kick(p_room uuid,p_member uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; target qse_v3.duel_members; alive boolean;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  select m.* into target from qse_v3.duel_members m where m.id = p_member and m.room_id = p_room;
  if not found then return jsonb_build_object('error','member_not_found'); end if;
  if target.user_id = owner then return jsonb_build_object('error','cannot_kick_self'); end if;
  if room.status <> 'lobby' then
    alive := exists(select 1 from qse_v3.duel_match_players where match_id = room.match_id and member_id = target.id
      and eliminated_reason is null);
    if alive then return jsonb_build_object('error','cannot_kick_active_player'); end if;
  end if;
  delete from qse_v3.duel_members where id = target.id;
  if target.user_id is not null then
    insert into qse_v3.duel_kicks(room_id,user_id) values(p_room,target.user_id) on conflict do nothing;
  end if;
  perform qse_v3.duel_touch(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

do $permissions$
declare item record;
begin
  for item in select p.oid::regprocedure as signature from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('qse_duel_start','qse_duel_heartbeat','qse_duel_room','qse_duel_select','qse_duel_pick','qse_duel_kick') loop
    execute format('revoke all on function %s from public,anon,authenticated',item.signature);
    execute format('grant execute on function %s to authenticated',item.signature);
  end loop;
end $permissions$;
revoke all on all functions in schema qse_v3 from public,anon,authenticated;
commit;
