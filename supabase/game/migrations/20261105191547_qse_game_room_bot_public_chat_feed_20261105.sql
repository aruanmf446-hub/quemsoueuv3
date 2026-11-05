-- GAME: migration 20261105191547. Acrescenta somente bots e eventos revelados ao contrato de acesso.
CREATE OR REPLACE FUNCTION public.qse_duel_chat_access(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := qse_v3.require_user();
  v_allowed boolean := false;
  v_members jsonb := '[]'::jsonb;
  v_match uuid;
  v_bots jsonb := '[]'::jsonb;
  v_bot_events jsonb := '[]'::jsonb;
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
      'nickname', pg_catalog.left(
        coalesce(nullif(pg_catalog.btrim(p.nickname), ''), 'Sem nickname'),
        80
      )
    )
    order by m.joined_at, m.id
  ), '[]'::jsonb)
  into v_members
  from qse_v3.duel_members m
  left join qse_v3.player_profiles p on p.user_id = m.user_id
  where m.room_id = p_room
    and m.user_id is not null
    and m.role in ('player','spectator')
    and not exists (
      select 1 from qse_v3.duel_kicks k
       where k.room_id = p_room and k.user_id = m.user_id
    );
  -- Metadados SOMENTE publicos da partida para mensagens dos bots no CHAT.
  select r.match_id into v_match from qse_v3.duel_rooms r
   where r.id=p_room and r.status='in_match';
  if v_match is not null then
    select coalesce(jsonb_agg(jsonb_build_object('member_id',p.member_id,
      'nickname',p.nickname,'skin_id',p.skin_id) order by p.member_id),'[]'::jsonb)
      into v_bots from qse_v3.duel_match_players p
      where p.match_id=v_match and p.is_bot;
    select coalesce(jsonb_agg(jsonb_build_object('seq',e.seq,'kind',e.kind)
      order by e.seq),'[]'::jsonb) into v_bot_events
    from (select seq,kind from qse_v3.duel_match_events
      where match_id=v_match and reveal_at <= now()
        and kind in ('pick','timeout','eliminated')
      order by seq desc limit 12) e;
  end if;
  return pg_catalog.jsonb_build_object('allowed',true,'participants',v_members,
    'bot_match_id',v_match,'bots',v_bots,'bot_events',v_bot_events);
end;
$function$
;
