-- T22 GAME | Convites privados direcionados: tokens visíveis apenas ao destinatário
-- dentro de RPC autenticada. Sem mudar o link global de qse_duel_invite_create.
create table if not exists qse_v3.duel_friend_invites (
 room_id uuid not null references qse_v3.duel_rooms(id) on delete cascade,
 recipient_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 sender_id uuid not null references qse_v3.player_profiles(user_id) on delete cascade,
 token text not null unique,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null,
 primary key(room_id,recipient_id),
 constraint duel_friend_invite_distinct check(sender_id<>recipient_id),
 constraint duel_friend_invite_token_format check(token ~ '^[0-9a-f]{48}$'),
 constraint duel_friend_invite_expiry check(expires_at>created_at)
);
alter table qse_v3.duel_friend_invites enable row level security;
revoke all on qse_v3.duel_friend_invites from public,anon,authenticated;
create index if not exists duel_friend_invites_recipient_recent
 on qse_v3.duel_friend_invites(recipient_id,expires_at desc);

create or replace function public.qse_duel_invite_send(p_room uuid,p_friend uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 v_owner uuid := qse_v3.require_user();
 v_room qse_v3.duel_rooms%rowtype;
 v_token text;
 v_expiry timestamptz;
begin
 if p_room is null or p_friend is null or p_friend=v_owner then
   return jsonb_build_object('error','invalid_invite');
 end if;
 if not exists(select 1 from qse_v3.friendships
   where user_low=least(v_owner,p_friend) and user_high=greatest(v_owner,p_friend)) then
   return jsonb_build_object('error','not_friends');
 end if;
 select * into v_room from qse_v3.duel_rooms where id=p_room for update;
 if not found or v_room.status not in ('lobby','in_match')
   or v_room.admin_id is distinct from v_owner
   or not exists(select 1 from qse_v3.duel_members
       where room_id=p_room and user_id=v_owner)
   or exists(select 1 from qse_v3.duel_kicks
       where room_id=p_room and user_id=v_owner)
   or exists(select 1 from qse_v3.duel_kicks
       where room_id=p_room and user_id=p_friend)
 then return jsonb_build_object('error','forbidden'); end if;
 v_token := pg_catalog.encode(extensions.gen_random_bytes(24),'hex');
 v_expiry := now() + interval '60 minutes';
 insert into qse_v3.duel_friend_invites(room_id,recipient_id,sender_id,token,created_at,expires_at)
 values(p_room,p_friend,v_owner,v_token,now(),v_expiry)
 on conflict(room_id,recipient_id) do update set
   sender_id=excluded.sender_id,token=excluded.token,
   created_at=excluded.created_at,expires_at=excluded.expires_at;
 -- Intencionalmente sem token: o administrador nunca lê segredo do destinatário.
 return jsonb_build_object('status','sent','room_id',p_room,'expires_at',v_expiry);
end $function$;

create or replace function public.qse_duel_invites_between(p_friend uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user();
begin
 if p_friend is null or p_friend=v_owner then return jsonb_build_object('error','invalid_player'); end if;
 if not exists(select 1 from qse_v3.friendships
   where user_low=least(v_owner,p_friend) and user_high=greatest(v_owner,p_friend))
 then return jsonb_build_object('error','not_friends'); end if;
 return coalesce((
   select jsonb_agg(
     jsonb_build_object(
       'room_id',i.room_id,'room_name',r.name,'sent_by',i.sender_id,
       'created_at',i.created_at,'expires_at',i.expires_at)
     || case when i.recipient_id=v_owner
          then jsonb_build_object('token',i.token)
          else '{}'::jsonb end
     order by i.created_at desc)
   from qse_v3.duel_friend_invites i
   join qse_v3.duel_rooms r on r.id=i.room_id
   where ((i.recipient_id=v_owner and i.sender_id=p_friend)
       or (i.sender_id=v_owner and i.recipient_id=p_friend))
     and i.expires_at>now() and r.status in ('lobby','in_match')
     and r.admin_id=i.sender_id
     and not exists(select 1 from qse_v3.duel_kicks k
        where k.room_id=i.room_id and k.user_id=v_owner)
 ),'[]'::jsonb);
end $function$;

-- Aceita token global antigo ou token direcionado. Não muda assinatura nem retorno.
create or replace function public.qse_duel_invite_join(p_token text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 v_owner uuid := qse_v3.require_user();
 v_room_code text;
begin
 if p_token is null or p_token !~ '^[0-9a-f]{48}$' then
   return jsonb_build_object('error','invalid_invite');
 end if;
 select r.code into v_room_code
 from qse_v3.duel_invite_links i
 join qse_v3.duel_rooms r on r.id=i.room_id
 where i.token_hash=pg_catalog.encode(
   extensions.digest(pg_catalog.decode(p_token,'hex'),'sha256'),'hex')
   and i.expires_at>now() and r.status <> 'closed';
 if not found then
   -- Destinatário autenticado e amizade ainda ativa; administrador ainda é o remetente.
   select r.code into v_room_code
   from qse_v3.duel_friend_invites i
   join qse_v3.duel_rooms r on r.id=i.room_id
   join qse_v3.friendships f
     on f.user_low=least(i.sender_id,i.recipient_id)
    and f.user_high=greatest(i.sender_id,i.recipient_id)
   where i.token=p_token
     and i.recipient_id=v_owner
     and i.expires_at>now()
     and r.status in ('lobby','in_match')
     and r.admin_id=i.sender_id;
 end if;
 if not found then return jsonb_build_object('error','invalid_invite'); end if;
 return public.qse_duel_join(v_room_code);
end $function$;

revoke all on function public.qse_duel_invite_send(uuid,uuid) from public,anon,authenticated;
revoke all on function public.qse_duel_invites_between(uuid) from public,anon,authenticated;
revoke all on function public.qse_duel_invite_join(text) from public,anon,authenticated;
grant execute on function public.qse_duel_invite_send(uuid,uuid) to authenticated;
grant execute on function public.qse_duel_invites_between(uuid) to authenticated;
grant execute on function public.qse_duel_invite_join(text) to authenticated;
