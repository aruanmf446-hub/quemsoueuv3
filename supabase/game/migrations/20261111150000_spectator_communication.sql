create or replace function public.qse_duel_chat_access(p_room uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := qse_v3.require_user();
  v_allowed boolean := false;
  v_members jsonb := '[]'::jsonb;
begin
  if p_room is null then return pg_catalog.jsonb_build_object('allowed',false); end if;
  select exists(
    select 1
      from qse_v3.duel_rooms r
      join qse_v3.duel_members m
        on m.room_id = r.id and m.user_id = v_actor
     where r.id = p_room
       and r.status in ('lobby','in_match')
       and m.role in ('player','spectator')
       and not exists (
         select 1 from qse_v3.duel_kicks k
          where k.room_id = r.id and k.user_id = v_actor
       )
  ) into v_allowed;
  if not coalesce(v_allowed,false) then
    return pg_catalog.jsonb_build_object('allowed',false);
  end if;

  select coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'tag', pg_catalog.encode(
        extensions.digest(
          pg_catalog.convert_to(
            'qse-room-member-v1:' || p_room::text || ':' || m.user_id::text,
            'UTF8'
          ),
          'sha256'
        ), 'hex'),
      'member_id', m.id,
      'can_speak', (r.status = 'lobby' or (m.role = 'player' and mp.member_id is not null and mp.eliminated_reason is null)),
      'nickname', pg_catalog.left(
        coalesce(nullif(pg_catalog.btrim(p.nickname), ''), 'Sem nickname'),
        80
      )
    )
    order by m.joined_at, m.id
  ), '[]'::jsonb)
  into v_members
  from qse_v3.duel_members m
  join qse_v3.duel_rooms r on r.id = m.room_id
  left join qse_v3.duel_match_players mp on mp.match_id = r.match_id and mp.member_id = m.id
  left join qse_v3.player_profiles p on p.user_id = m.user_id
  where m.room_id = p_room
    and m.user_id is not null
    and m.role in ('player','spectator')
    and not exists (
      select 1 from qse_v3.duel_kicks k
       where k.room_id = p_room and k.user_id = m.user_id
    );
  return pg_catalog.jsonb_build_object('allowed',true,'participants',v_members);
end;
$function$;

revoke all on function public.qse_duel_chat_access(uuid)
from public, anon, authenticated;
grant execute on function public.qse_duel_chat_access(uuid) to authenticated;
