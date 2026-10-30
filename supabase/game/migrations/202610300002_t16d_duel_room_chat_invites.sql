-- T16D GAME: API aditiva para autorização de chat de sala e convites por token.
-- Não altera tabelas/RPCs preexistentes do Duelo.
create table if not exists qse_v3.duel_invite_links (
 room_id uuid primary key references qse_v3.duel_rooms(id) on delete cascade,
 token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null,
 constraint duel_invite_links_expiry_check check (expires_at > created_at)
);
create index if not exists duel_invite_links_expire_idx
 on qse_v3.duel_invite_links(expires_at);
alter table qse_v3.duel_invite_links enable row level security;
revoke all on qse_v3.duel_invite_links from public, anon, authenticated;

-- Cada operação CHAT consulta status, expulsão e participação AO VIVO no GAME.
create or replace function public.qse_duel_chat_access(p_room uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_actor uuid := qse_v3.require_user(); v_allowed boolean := false;
begin
 if p_room is null then return jsonb_build_object('allowed',false); end if;
 select exists(
   select 1 from qse_v3.duel_rooms r
   join qse_v3.duel_members m on m.room_id=r.id and m.user_id=v_actor
   where r.id=p_room and r.status in ('lobby','in_match')
     and m.role in ('player','spectator')
     and not exists(select 1 from qse_v3.duel_kicks k
                    where k.room_id=r.id and k.user_id=v_actor)
 ) into v_allowed;
 return jsonb_build_object('allowed',coalesce(v_allowed,false));
end;
$$;

-- Token aleatório de 192 bits, armazenado apenas como SHA-256, duração 5-1440 minutos.
-- Somente administrador atual da sala, presente e não expulso, pode rotacionar convite.
create or replace function public.qse_duel_invite_create(
  p_room uuid, p_minutes integer default 60
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
 v_actor uuid := qse_v3.require_user();
 v_room qse_v3.duel_rooms%rowtype;
 v_token text;
 v_expires timestamptz;
begin
 if p_room is null or p_minutes is null or p_minutes not between 5 and 1440 then
   return jsonb_build_object('error','invalid_invite');
 end if;
 select * into v_room from qse_v3.duel_rooms where id=p_room for update;
 if not found or v_room.status='closed' or v_room.admin_id is distinct from v_actor
    or not exists(select 1 from qse_v3.duel_members
                  where room_id=p_room and user_id=v_actor)
    or exists(select 1 from qse_v3.duel_kicks
              where room_id=p_room and user_id=v_actor) then
   return jsonb_build_object('error','forbidden');
 end if;
 v_token := pg_catalog.encode(extensions.gen_random_bytes(24),'hex');
 v_expires := pg_catalog.now() + pg_catalog.make_interval(mins=>p_minutes);
 insert into qse_v3.duel_invite_links(room_id,token_hash,created_by,created_at,expires_at)
 values(p_room,pg_catalog.encode(extensions.digest(pg_catalog.decode(v_token,'hex'),'sha256'),'hex'),v_actor,now(),v_expires)
 on conflict(room_id) do update set
   token_hash=excluded.token_hash, created_by=excluded.created_by,
   created_at=excluded.created_at, expires_at=excluded.expires_at;
 return jsonb_build_object('token',v_token,'expires_at',v_expires);
end;
$$;

-- Resgata token sem fornecer UUID ou código de sala ao cliente.
-- Reusa as verificações EXISTENTES em qse_duel_join: fechado, kick, lotação, etc.
create or replace function public.qse_duel_invite_join(p_token text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_room_code text;
begin
 perform qse_v3.require_user();
 if p_token is null or p_token !~ '^[0-9a-f]{48}$' then
   return jsonb_build_object('error','invalid_invite');
 end if;
 select r.code into v_room_code
 from qse_v3.duel_invite_links i
 join qse_v3.duel_rooms r on r.id=i.room_id
 where i.token_hash=pg_catalog.encode(
   extensions.digest(pg_catalog.decode(p_token,'hex'),'sha256'),'hex')
   and i.expires_at > now() and r.status <> 'closed';
 if not found then return jsonb_build_object('error','invalid_invite'); end if;
 return public.qse_duel_join(v_room_code);
end;
$$;

revoke all on function public.qse_duel_chat_access(uuid) from public,anon,authenticated;
revoke all on function public.qse_duel_invite_create(uuid,integer) from public,anon,authenticated;
revoke all on function public.qse_duel_invite_join(text) from public,anon,authenticated;
grant execute on function public.qse_duel_chat_access(uuid) to authenticated;
grant execute on function public.qse_duel_invite_create(uuid,integer) to authenticated;
grant execute on function public.qse_duel_invite_join(text) to authenticated;
