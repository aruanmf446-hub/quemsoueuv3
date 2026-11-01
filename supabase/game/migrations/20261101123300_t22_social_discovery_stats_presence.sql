-- T22 GAME | Estatísticas compartilhadas, descoberta por amigos e presença privada.
alter table qse_v3.account_preferences add column if not exists last_seen_at timestamptz;
create index if not exists duel_match_players_user_match_t22_idx
 on qse_v3.duel_match_players(user_id,match_id)
 where user_id is not null;

create or replace function public.qse_mutual_friends(p_target uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user();
begin
 if p_target is null or p_target=v_owner then return jsonb_build_object('error','invalid_player'); end if;
 if not exists(select 1 from qse_v3.player_profiles p
   join qse_v3.account_preferences a using(user_id)
   where p.user_id=p_target and
     (a.discoverable or exists(select 1 from qse_v3.friendships f
      where f.user_low=least(v_owner,p_target) and f.user_high=greatest(v_owner,p_target))))
 then return jsonb_build_object('error','player_not_found'); end if;
 return (
 with me as (
   select case when user_low=v_owner then user_high else user_low end uid
   from qse_v3.friendships where v_owner in(user_low,user_high)
 ), them as (
   select case when user_low=p_target then user_high else user_low end uid
   from qse_v3.friendships where p_target in(user_low,user_high)
 ), shared as (
   select me.uid from me join them on me.uid=them.uid
 ), candidates as (
   select s.uid from shared s
   join qse_v3.account_preferences a on a.user_id=s.uid
   where a.discoverable or s.uid=v_owner or s.uid=p_target
   order by s.uid limit 5
 )
 select jsonb_build_object(
   'count',(select count(*) from shared),
   'players',coalesce((select jsonb_agg(qse_v3.public_fragment(uid)) from candidates),'[]'::jsonb))
 );
end $function$;

create or replace function public.qse_player_suggestions(p_limit integer default 10)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user();
begin
 if p_limit is null or p_limit not between 1 and 20 then
   return jsonb_build_object('error','invalid_limit'); end if;
 return (
 with my_friends as (
   select case when user_low=v_owner then user_high else user_low end uid
   from qse_v3.friendships where v_owner in(user_low,user_high)
 ), friends_of_friends as (
   select case when f.user_low=mf.uid then f.user_high else f.user_low end uid
   from my_friends mf join qse_v3.friendships f on mf.uid in(f.user_low,f.user_high)
 ), counts as (
   select ff.uid,count(*) mutual_count from friends_of_friends ff
   join qse_v3.account_preferences a on a.user_id=ff.uid and a.discoverable
   where ff.uid <> v_owner
     and not exists(select 1 from my_friends where uid=ff.uid)
     and not exists(select 1 from qse_v3.friend_requests r
        where (r.sender_id=v_owner and r.recipient_id=ff.uid)
           or (r.sender_id=ff.uid and r.recipient_id=v_owner))
   group by ff.uid
 ), shortlist as (
   select c.uid,c.mutual_count from counts c order by c.mutual_count desc,c.uid limit p_limit
 )
 select jsonb_build_object(
  'players',coalesce((select jsonb_agg(qse_v3.public_fragment(uid) order by mutual_count desc,uid) from shortlist),'[]'::jsonb),
  'mutual_counts',coalesce((select jsonb_object_agg(uid::text,mutual_count) from shortlist),'{}'::jsonb))
 );
end $function$;

create or replace function public.qse_recent_matches_with(p_player uuid,p_limit integer default 10)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user();
begin
 if p_player is null or p_player=v_owner then
   return jsonb_build_object('error','invalid_player'); end if;
 if p_limit is null or p_limit not between 1 and 20 then
   return jsonb_build_object('error','invalid_limit'); end if;
 if not exists(select 1 from qse_v3.player_profiles p
   join qse_v3.account_preferences a using(user_id)
   where p.user_id=p_player and
    (a.discoverable or exists(select 1 from qse_v3.friendships f
      where f.user_low=least(v_owner,p_player) and f.user_high=greatest(v_owner,p_player))))
 then return jsonb_build_object('error','player_not_found'); end if;
 return (
 with joint as (
   select m.id match_id,m.room_id,coalesce(m.finished_at,m.created_at) played_at
   from qse_v3.duel_matches m
   where m.finished_at is not null
     and exists(select 1 from qse_v3.duel_match_players p where p.match_id=m.id and p.user_id=v_owner)
     and exists(select 1 from qse_v3.duel_match_players p where p.match_id=m.id and p.user_id=p_player)
   order by m.finished_at desc,m.id desc limit p_limit
 )
 select jsonb_build_object(
   'count',(select count(*) from joint),
   'matches',coalesce((select jsonb_agg(jsonb_build_object(
      'match_id',match_id,'room_id',room_id,'played_at',played_at) order by played_at desc)
     from joint),'[]'::jsonb))
 );
end $function$;

create or replace function public.qse_friend_stats(p_friend uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user(); v_count bigint; v_last timestamptz;
begin
 if p_friend is null or p_friend=v_owner then return jsonb_build_object('error','invalid_player'); end if;
 if not exists(select 1 from qse_v3.friendships f
    where f.user_low=least(v_owner,p_friend) and f.user_high=greatest(v_owner,p_friend))
 then return jsonb_build_object('error','not_friends'); end if;
 select count(*),max(m.finished_at) into v_count,v_last
 from qse_v3.duel_matches m where m.finished_at is not null
 and exists(select 1 from qse_v3.duel_match_players p where p.match_id=m.id and p.user_id=v_owner)
 and exists(select 1 from qse_v3.duel_match_players p where p.match_id=m.id and p.user_id=p_friend);
 return jsonb_build_object('matches_together',v_count,'last_played_at',v_last);
end $function$;

-- O cliente envia heartbeat de presença sob JWT. "in_match" é apurado pelo GAME.
create or replace function public.qse_presence_heartbeat()
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user(); v_match boolean;
begin
 perform qse_v3.ensure_player(v_owner);
 update qse_v3.account_preferences set last_seen_at=now() where user_id=v_owner;
 select exists(
   select 1 from qse_v3.duel_members m join qse_v3.duel_rooms r on r.id=m.room_id
   where m.user_id=v_owner and m.role='player' and r.status='in_match'
     and m.last_seen_at > now()-interval '90 seconds'
 ) into v_match;
 return jsonb_build_object('status',case when v_match then 'in_match' else 'online' end,
                           'last_seen_at',now());
end $function$;

create or replace function public.qse_friends()
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_owner uuid := qse_v3.require_user();
begin
 perform qse_v3.ensure_player(v_owner);
 return jsonb_build_object(
 'friends',coalesce((select jsonb_agg(qse_v3.public_fragment(case when f.user_low=v_owner then f.user_high else f.user_low end) order by f.created_at)
     from qse_v3.friendships f where v_owner in(f.user_low,f.user_high)),'[]'::jsonb),
 'incoming',coalesce((select jsonb_agg(qse_v3.public_fragment(r.sender_id) order by r.created_at)
     from qse_v3.friend_requests r where r.recipient_id=v_owner),'[]'::jsonb),
 'outgoing',coalesce((select jsonb_agg(qse_v3.public_fragment(r.recipient_id) order by r.created_at)
     from qse_v3.friend_requests r where r.sender_id=v_owner),'[]'::jsonb),
 'requests',coalesce((select jsonb_object_agg(other_id::text,
    jsonb_build_object('message',request_message,'requested_at',created_at))
   from (select r.sender_id other_id,r.request_message,r.created_at
         from qse_v3.friend_requests r where r.recipient_id=v_owner
         union all
         select r.recipient_id other_id,r.request_message,r.created_at
         from qse_v3.friend_requests r where r.sender_id=v_owner) v),'{}'::jsonb),
 'presence',coalesce((
   select jsonb_object_agg(friend_id::text,
      jsonb_build_object('last_seen_at',last_seen_at,
         'status',case when last_seen_at is null or last_seen_at<=now()-interval '90 seconds' then 'offline'
           when exists(select 1 from qse_v3.duel_members m
               join qse_v3.duel_rooms r on r.id=m.room_id
               where m.user_id=friend_id and m.role='player' and r.status='in_match'
                 and m.last_seen_at > now()-interval '90 seconds') then 'in_match'
           else 'online' end))
   from (
     select case when f.user_low=v_owner then f.user_high else f.user_low end friend_id,
            a.last_seen_at
     from qse_v3.friendships f
     join qse_v3.account_preferences a
       on a.user_id=case when f.user_low=v_owner then f.user_high else f.user_low end
     where v_owner in (f.user_low,f.user_high)
   ) friends_only
 ),'{}'::jsonb));
end $function$;

revoke all on function public.qse_mutual_friends(uuid) from public,anon,authenticated;
revoke all on function public.qse_player_suggestions(integer) from public,anon,authenticated;
revoke all on function public.qse_recent_matches_with(uuid,integer) from public,anon,authenticated;
revoke all on function public.qse_friend_stats(uuid) from public,anon,authenticated;
revoke all on function public.qse_presence_heartbeat() from public,anon,authenticated;
revoke all on function public.qse_friends() from public,anon,authenticated;
grant execute on function public.qse_mutual_friends(uuid) to authenticated;
grant execute on function public.qse_player_suggestions(integer) to authenticated;
grant execute on function public.qse_recent_matches_with(uuid,integer) to authenticated;
grant execute on function public.qse_friend_stats(uuid) to authenticated;
grant execute on function public.qse_presence_heartbeat() to authenticated;
grant execute on function public.qse_friends() to authenticated;
