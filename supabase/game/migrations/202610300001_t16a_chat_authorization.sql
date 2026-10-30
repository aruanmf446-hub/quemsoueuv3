-- T16A GAME: autoridade única de identidade, amizade e bloqueio para CHAT.
-- Nenhuma tabela de autenticação adicional é criada no CHAT.
create table if not exists qse_v3.chat_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint chat_blocks_pkey primary key (blocker_id, blocked_id),
  constraint chat_blocks_not_self check (blocker_id <> blocked_id)
);
create index if not exists chat_blocks_blocked_idx on qse_v3.chat_blocks (blocked_id, blocker_id);
alter table qse_v3.chat_blocks enable row level security;
revoke all on qse_v3.chat_blocks from public, anon, authenticated;

-- Lightweight targeted authorization: one indexed friendship lookup and two indexed block lookups.
-- No username/profile list or cross-database trust in client-provided identities.
create or replace function public.qse_chat_can_message(p_peer uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := qse_v3.require_user();
  v_allowed boolean := false;
begin
  if p_peer is null or p_peer = v_user then
    return jsonb_build_object('allowed', false);
  end if;
  select
    exists (
      select 1 from qse_v3.friendships f
      where f.user_low = least(v_user, p_peer)
        and f.user_high = greatest(v_user, p_peer)
    )
    and not exists (
      select 1 from qse_v3.chat_blocks b
      where (b.blocker_id = v_user and b.blocked_id = p_peer)
         or (b.blocker_id = p_peer and b.blocked_id = v_user)
    )
  into v_allowed;
  return jsonb_build_object('allowed', coalesce(v_allowed,false));
end;
$$;
revoke all on function public.qse_chat_can_message(uuid) from public, anon, authenticated;
grant execute on function public.qse_chat_can_message(uuid) to authenticated;

-- A ação de bloquear continua pertencendo ao GAME (nunca ao CHAT).
create or replace function public.qse_chat_block(p_peer uuid, p_block boolean)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := qse_v3.require_user();
begin
  if p_peer is null or p_peer = v_user or p_block is null then
    return jsonb_build_object('error','invalid_peer');
  end if;
  if not exists(select 1 from qse_v3.player_profiles where user_id = p_peer) then
    return jsonb_build_object('error','player_not_found');
  end if;
  if p_block then
    insert into qse_v3.chat_blocks(blocker_id,blocked_id) values(v_user,p_peer)
    on conflict (blocker_id,blocked_id) do nothing;
  else
    delete from qse_v3.chat_blocks where blocker_id=v_user and blocked_id=p_peer;
  end if;
  return jsonb_build_object('status','applied');
end;
$$;
revoke all on function public.qse_chat_block(uuid,boolean) from public, anon, authenticated;
grant execute on function public.qse_chat_block(uuid,boolean) to authenticated;
