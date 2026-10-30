-- Duelo / Multiplayer — etapa 1: salas, lista pública, convite por código, lobby,
-- configurações, administração e participantes (inclusive bots).
-- Aplicar depois de 202610280001/0002. Mesma regra do resto do schema: nenhuma leitura ou
-- escrita direta pelo cliente; tudo passa por funções public.qse_duel_*. Isso protege as
-- cartas secretas que a etapa 2 guardará nestas salas.
begin;

-- Decks que o ADM escolhe. Cada deck é uma pasta de cartas em PNG no jogo
-- (assets/duel/decks/<deck>/<carta>.png); aqui ficam só os identificadores "<deck>/<carta>".
-- Os dados vêm de supabase/seed/duel_decks.sql, gerado por tools/duel/sync_decks.py.
create table qse_v3.duel_decks (
  id text primary key check (id ~ '^[a-z0-9_]{2,32}$'),
  name text not null check (char_length(name) between 1 and 32),
  card_ids text[] not null check (cardinality(card_ids) between 2 and 300),
  sort_order integer not null default 0
);

create table qse_v3.duel_rooms (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  name text not null check (char_length(name) between 3 and 32 and name !~ '[[:cntrl:]]'),
  is_public boolean not null default true,
  status text not null default 'lobby' check (status in ('lobby','in_match','closed')),
  match_phase text check (match_phase in ('selection','countdown','turns','reveal','tiebreak','finished')),
  phase_deadline timestamptz,
  admin_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  settings jsonb not null,
  revision bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);
-- Lista pública: só salas abertas no lobby, mais recentes primeiro.
create index duel_rooms_public_lobby on qse_v3.duel_rooms(updated_at desc) where status = 'lobby' and is_public;
create index duel_rooms_admin on qse_v3.duel_rooms(admin_id);
create index duel_rooms_creator on qse_v3.duel_rooms(created_by);

-- Participantes: jogadores reais (user_id) ou bots (bot_name). role 'spectator' = Ghost.
create table qse_v3.duel_members (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  room_id uuid not null references qse_v3.duel_rooms(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  bot_name text check (bot_name is null or char_length(bot_name) between 1 and 24),
  character_id text not null,
  role text not null default 'player' check (role in ('player','spectator')),
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  check ((user_id is null) <> (bot_name is null)),
  unique (room_id,user_id)
);
create index duel_members_user on qse_v3.duel_members(user_id);

-- Expulsos não voltam para a mesma sala pelo código.
create table qse_v3.duel_kicks (
  room_id uuid not null references qse_v3.duel_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room_id,user_id)
);
create index duel_kicks_user on qse_v3.duel_kicks(user_id);

do $rls$
declare item text;
begin
  foreach item in array array['duel_decks','duel_rooms','duel_members','duel_kicks'] loop
    execute format('alter table qse_v3.%I enable row level security',item);
    execute format('revoke all on qse_v3.%I from public,anon,authenticated',item);
    execute format('grant all on qse_v3.%I to service_role',item);
  end loop;
end $rls$;

-- ---------------------------------------------------------------------------------------
-- Configurações
-- ---------------------------------------------------------------------------------------
-- Padrões da especificação; o deck padrão é o primeiro da lista.
create function qse_v3.duel_default_settings() returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('max_players',10,
    'deck_ids',coalesce((select jsonb_build_array(id) from qse_v3.duel_decks order by sort_order,id limit 1),'[]'::jsonb),
    'cards_per_player',3,'bots_allowed',true,'turn_seconds',60,'selection_seconds',30,'tiebreak_base',7,'tiebreak_per_player',2)
$$;

-- Todas as cartas (distintas) dos decks escolhidos.
create function qse_v3.duel_deck_cards(p_deck_ids text[]) returns text[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct c order by c),'{}') from (
    select unnest(d.card_ids) as c from qse_v3.duel_decks d where d.id = any(p_deck_ids)) x
$$;

create function qse_v3.duel_int_ok(p_settings jsonb,p_key text,p_min integer,p_max integer) returns boolean language sql immutable set search_path = '' as $$
  select jsonb_typeof(p_settings->p_key) = 'number'
    and (p_settings->>p_key)::numeric = trunc((p_settings->>p_key)::numeric)
    and (p_settings->>p_key)::numeric between p_min and p_max
$$;

-- Junta p_input sobre p_base (ou o padrão) e valida. Retorna null se algo for inválido.
create function qse_v3.duel_settings(p_input jsonb,p_base jsonb) returns jsonb language plpgsql stable security definer set search_path = '' as $$
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
  -- Cada jogador escolhe cartas diferentes entre si: o deck precisa ter cartas suficientes.
  if cardinality(qse_v3.duel_deck_cards(decks)) < (result->>'cards_per_player')::integer then return null; end if;
  return result || jsonb_build_object('deck_ids',to_jsonb(decks));
end $$;

-- ---------------------------------------------------------------------------------------
-- Estado interno da sala
-- ---------------------------------------------------------------------------------------
create function qse_v3.duel_touch(p_room uuid) returns void language sql security definer set search_path = '' as $$
  update qse_v3.duel_rooms set revision = revision + 1, updated_at = now() where id = p_room
$$;

create function qse_v3.duel_new_code() returns text language plpgsql volatile security definer set search_path = '' as $$
declare alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; candidate text; attempt integer := 0;
begin
  loop
    attempt := attempt + 1;
    select string_agg(substr(alphabet,1 + floor(random() * length(alphabet))::integer,1),'') into candidate
      from generate_series(1,6);
    exit when not exists(select 1 from qse_v3.duel_rooms where code = candidate);
    if attempt > 20 then raise exception 'room_code_exhausted'; end if;
  end loop;
  return candidate;
end $$;

-- ADM sempre é um jogador real da sala. Sem ADM válido, sorteia entre os reais (jogadores
-- antes de espectadores). Sem nenhum jogador real, a sala é encerrada (mesmo com bots).
create function qse_v3.duel_fix_admin(p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
declare current_admin uuid; chosen uuid;
begin
  select admin_id into current_admin from qse_v3.duel_rooms where id = p_room and status <> 'closed';
  if not found then return; end if;
  if current_admin is not null and exists(select 1 from qse_v3.duel_members
      where room_id = p_room and user_id = current_admin) then return; end if;
  select user_id into chosen from qse_v3.duel_members where room_id = p_room and user_id is not null
    order by (role = 'player') desc, random() limit 1;
  if chosen is null then
    update qse_v3.duel_rooms set status = 'closed', closed_at = now(), admin_id = null, match_phase = null,
      phase_deadline = null where id = p_room;
  else
    update qse_v3.duel_rooms set admin_id = chosen where id = p_room;
  end if;
  perform qse_v3.duel_touch(p_room);
end $$;

-- Quem parou de dar sinal no lobby (fechou o jogo sem sair) deixa a sala. Durante a
-- partida a regra de desconexão é outra (etapa 5) e não remove ninguém aqui.
create function qse_v3.duel_sweep(p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
declare removed integer;
begin
  delete from qse_v3.duel_members m using qse_v3.duel_rooms r
    where m.room_id = p_room and r.id = p_room and r.status = 'lobby' and m.user_id is not null
      and m.last_seen_at < now() - interval '45 seconds';
  get diagnostics removed = row_count;
  if removed > 0 then perform qse_v3.duel_touch(p_room); end if;
  perform qse_v3.duel_fix_admin(p_room);
end $$;

create function qse_v3.duel_leave_room(p_owner uuid,p_room uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from qse_v3.duel_members where room_id = p_room and user_id = p_owner;
  if found then
    perform qse_v3.duel_touch(p_room);
    perform qse_v3.duel_fix_admin(p_room);
  end if;
end $$;

-- Cada jogador fica em uma sala por vez: entrar ou criar outra sai das anteriores.
create function qse_v3.duel_leave_others(p_owner uuid,p_keep uuid) returns void language plpgsql security definer set search_path = '' as $$
declare item record;
begin
  for item in select room_id from qse_v3.duel_members where user_id = p_owner and room_id is distinct from p_keep loop
    perform qse_v3.duel_leave_room(p_owner,item.room_id);
  end loop;
end $$;

create function qse_v3.duel_player_count(p_room uuid) returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from qse_v3.duel_members where room_id = p_room and role = 'player'
$$;

create function qse_v3.duel_decks_json(p_deck_ids text[]) returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'size',cardinality(d.card_ids))
    order by d.sort_order,d.name),'[]'::jsonb)
  from qse_v3.duel_decks d where p_deck_ids is null or d.id = any(p_deck_ids)
$$;

-- Tudo que um participante pode ver da sala. Nunca inclui user_id (só public_id).
create function qse_v3.duel_snapshot(p_room uuid,p_viewer uuid) returns jsonb language sql stable security definer set search_path = '' as $$
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
      where m.room_id = r.id),'[]'::jsonb))
  from qse_v3.duel_rooms r where r.id = p_room
$$;

-- Sala em que o usuário está, com trava de linha (operações concorrentes na mesma sala).
create function qse_v3.duel_lock_member_room(p_owner uuid,p_room uuid) returns qse_v3.duel_rooms language plpgsql security definer set search_path = '' as $$
declare room qse_v3.duel_rooms;
begin
  select r.* into room from qse_v3.duel_rooms r where r.id = p_room for update;
  if not found or room.status = 'closed' then return null; end if;
  if not exists(select 1 from qse_v3.duel_members where room_id = p_room and user_id = p_owner) then return null; end if;
  return room;
end $$;

-- ---------------------------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------------------------
create function public.qse_duel_decks() returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform qse_v3.require_user();
  return jsonb_build_object('decks',qse_v3.duel_decks_json(null),'defaults',qse_v3.duel_default_settings());
end $$;

create function public.qse_duel_create(p_name text,p_public boolean,p_settings jsonb) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); config jsonb; new_room uuid; skin text;
begin
  perform qse_v3.ensure_player(owner);
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
end $$;

-- Salas públicas no lobby (em partida ficam ocultas). Salas cujos jogadores reais sumiram
-- há mais de 2 minutos não aparecem.
create function public.qse_duel_list(p_term text,p_only_open boolean) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); term text := lower(btrim(coalesce(p_term,'')));
begin
  if char_length(term) > 32 then return jsonb_build_object('error','invalid_search'); end if;
  return jsonb_build_object('rooms',coalesce((select jsonb_agg(x.item order by x.updated_at desc) from (
    select r.updated_at,jsonb_build_object('id',r.id,'code',r.code,'name',r.name,
      'players',qse_v3.duel_player_count(r.id),'max_players',(r.settings->>'max_players')::integer,
      'bots',(select count(*) from qse_v3.duel_members b where b.room_id = r.id and b.user_id is null),
      'cards_per_player',(r.settings->>'cards_per_player')::integer,'turn_seconds',(r.settings->>'turn_seconds')::integer,
      'decks',qse_v3.duel_decks_json(array(select jsonb_array_elements_text(r.settings->'deck_ids'))),
      'admin',(select coalesce(p.nickname,'Sem nickname') from qse_v3.player_profiles p where p.user_id = r.admin_id)) as item
    from qse_v3.duel_rooms r
    where r.status = 'lobby' and r.is_public
      and (term = '' or position(term in lower(r.name)) > 0 or upper(term) = r.code)
      and (not coalesce(p_only_open,false) or qse_v3.duel_player_count(r.id) < (r.settings->>'max_players')::integer)
      and exists(select 1 from qse_v3.duel_members m where m.room_id = r.id and m.user_id is not null
        and m.last_seen_at > now() - interval '2 minutes')
    order by r.updated_at desc limit 50) x),'[]'::jsonb));
end $$;

-- Entrada por código/convite. No lobby entra como jogador (se houver vaga); com a partida
-- em andamento entra como espectador e espera a próxima.
create function public.qse_duel_join(p_code text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; clean text; skin text;
begin
  perform qse_v3.ensure_player(owner);
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
end $$;

create function public.qse_duel_leave(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin
  perform 1 from qse_v3.duel_rooms where id = p_room for update;
  perform qse_v3.duel_leave_room(owner,p_room);
  return jsonb_build_object('left',true);
end $$;

-- Sinal de vida (a cada poucos segundos). Retorna a revisão: o jogo só busca a sala
-- inteira quando ela muda.
create function public.qse_duel_heartbeat(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms;
begin
  update qse_v3.duel_members set last_seen_at = now() where room_id = p_room and user_id = owner;
  if not found then
    select r.* into room from qse_v3.duel_rooms r where r.id = p_room;
    return jsonb_build_object('member',false,'status',coalesce(room.status,'closed'),'revision',coalesce(room.revision,0));
  end if;
  perform qse_v3.duel_sweep(p_room);
  select r.* into room from qse_v3.duel_rooms r where r.id = p_room;
  return jsonb_build_object('member',exists(select 1 from qse_v3.duel_members where room_id = p_room and user_id = owner),
    'status',room.status,'revision',room.revision);
end $$;

create function public.qse_duel_room(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user();
begin
  if not exists(select 1 from qse_v3.duel_members where room_id = p_room and user_id = owner) then
    return jsonb_build_object('error','not_member'); end if;
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

-- Configurações e dados da sala: só o ADM e só no lobby.
create function public.qse_duel_configure(p_room uuid,p_name text,p_public boolean,p_settings jsonb) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; config jsonb;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  if room.status <> 'lobby' then return jsonb_build_object('error','match_in_progress'); end if;
  if p_name is not null and (char_length(btrim(p_name)) not between 3 and 32 or p_name ~ '[[:cntrl:]]') then
    return jsonb_build_object('error','invalid_room_name'); end if;
  config := qse_v3.duel_settings(p_settings,room.settings);
  if config is null then return jsonb_build_object('error','invalid_settings'); end if;
  if (config->>'max_players')::integer < qse_v3.duel_player_count(p_room) then
    return jsonb_build_object('error','max_below_players'); end if;
  if not (config->>'bots_allowed')::boolean then
    delete from qse_v3.duel_members where room_id = p_room and user_id is null;
  end if;
  update qse_v3.duel_rooms set settings = config, name = coalesce(btrim(p_name),name),
    is_public = coalesce(p_public,is_public) where id = p_room;
  perform qse_v3.duel_touch(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

create function public.qse_duel_add_bot(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; label text; skin text;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  if room.status <> 'lobby' then return jsonb_build_object('error','match_in_progress'); end if;
  if not (room.settings->>'bots_allowed')::boolean then return jsonb_build_object('error','bots_disabled'); end if;
  if qse_v3.duel_player_count(p_room) >= (room.settings->>'max_players')::integer then
    return jsonb_build_object('error','room_full'); end if;
  select n into label from unnest(array['Bot Areia','Bot Duna','Bot Oásis','Bot Miragem','Bot Brasa','Bot Lua',
    'Bot Vento','Bot Cristal','Bot Farol','Bot Trovão','Bot Neblina','Bot Pedra','Bot Aurora','Bot Cometa',
    'Bot Tempestade','Bot Sol','Bot Eco','Bot Faísca','Bot Âmbar','Bot Estrela']) n
    where n not in (select bot_name from qse_v3.duel_members where room_id = p_room and bot_name is not null) limit 1;
  select id into skin from qse_v3.character_catalog order by random() limit 1;
  insert into qse_v3.duel_members(room_id,bot_name,character_id) values(p_room,coalesce(label,'Bot'),skin);
  perform qse_v3.duel_touch(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

-- Expulsar: no lobby, qualquer participante; durante a partida, só espectadores (Ghost).
-- Jogadores reais expulsos não podem voltar pelo código.
create function public.qse_duel_kick(p_room uuid,p_member uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms; target qse_v3.duel_members;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  select m.* into target from qse_v3.duel_members m where m.id = p_member and m.room_id = p_room;
  if not found then return jsonb_build_object('error','member_not_found'); end if;
  if target.user_id = owner then return jsonb_build_object('error','cannot_kick_self'); end if;
  if room.status <> 'lobby' and target.role <> 'spectator' then
    return jsonb_build_object('error','cannot_kick_active_player'); end if;
  delete from qse_v3.duel_members where id = target.id;
  if target.user_id is not null then
    insert into qse_v3.duel_kicks(room_id,user_id) values(p_room,target.user_id) on conflict do nothing;
  end if;
  perform qse_v3.duel_touch(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

-- Iniciar: só o ADM, no lobby, com pelo menos 2 jogadores. A sala some da lista pública
-- e todos vão para a seleção secreta de cartas (implementada na etapa 2).
create function public.qse_duel_start(p_room uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare owner uuid := qse_v3.require_user(); room qse_v3.duel_rooms;
begin
  room := qse_v3.duel_lock_member_room(owner,p_room);
  if room.id is null then return jsonb_build_object('error','not_member'); end if;
  if room.admin_id is distinct from owner then return jsonb_build_object('error','not_admin'); end if;
  if room.status <> 'lobby' then return jsonb_build_object('error','match_in_progress'); end if;
  perform qse_v3.duel_sweep(p_room);
  if qse_v3.duel_player_count(p_room) < 2 then return jsonb_build_object('error','not_enough_players'); end if;
  update qse_v3.duel_rooms set status = 'in_match', match_phase = 'selection',
    phase_deadline = now() + make_interval(secs => (settings->>'selection_seconds')::integer) where id = p_room;
  perform qse_v3.duel_touch(p_room);
  return qse_v3.duel_snapshot(p_room,owner);
end $$;

do $permissions$
declare item record;
begin
  for item in select p.oid::regprocedure as signature from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('qse_duel_decks','qse_duel_create','qse_duel_list','qse_duel_join',
      'qse_duel_leave','qse_duel_heartbeat','qse_duel_room','qse_duel_configure','qse_duel_add_bot','qse_duel_kick',
      'qse_duel_start') loop
    execute format('revoke all on function %s from public,anon,authenticated',item.signature);
    execute format('grant execute on function %s to authenticated',item.signature);
  end loop;
end $permissions$;
revoke all on all functions in schema qse_v3 from public,anon,authenticated;
commit;
