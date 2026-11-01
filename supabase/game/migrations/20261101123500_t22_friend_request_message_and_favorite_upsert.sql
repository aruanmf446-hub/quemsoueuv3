-- T22 GAME | Pedidos com mensagem opcional e metadados separados dos cinco campos de perfil.
alter table qse_v3.friend_requests add column if not exists request_message text;
alter table qse_v3.friend_requests drop constraint if exists friend_requests_message_length;
alter table qse_v3.friend_requests add constraint friend_requests_message_length
  check (request_message is null or char_length(request_message) <= 140);

-- Quatro argumentos sem DEFAULT: evita ambiguidades PostgREST com o contrato de três argumentos.
create or replace function public.qse_friend_action(
 p_action text,p_target uuid,p_request_id uuid,p_message text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
 owner uuid := qse_v3.require_user();
 prior qse_v3.processed_requests%rowtype;
 cleaned text := nullif(btrim(p_message),'');
 command jsonb := jsonb_build_object('action',p_action,'target',p_target);
 response jsonb;
 affected integer;
begin
 perform qse_v3.ensure_player(owner);
 if p_request_id is null or p_target is null or owner=p_target
    or p_action is null or p_action not in ('send','accept','decline','cancel','remove') then
   return jsonb_build_object('error','invalid_friend_request');
 end if;
 if p_message is not null and (p_action <> 'send' or char_length(p_message)>140) then
   return jsonb_build_object('error','invalid_message');
 end if;
 if cleaned is not null then
   command := command || jsonb_build_object('message',cleaned);
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner::text || ':friend-action',0));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(least(owner,p_target)::text || greatest(owner,p_target)::text,0));
 select * into prior from qse_v3.processed_requests
 where user_id=owner and domain='friends' and request_id=p_request_id;
 if found then
   if prior.request<>command then return jsonb_build_object('error','idempotency_conflict'); end if;
   return prior.response;
 end if;
 if not exists(select 1 from qse_v3.player_profiles where user_id=p_target) then
   return jsonb_build_object('error','player_not_found');
 end if;
 if p_action='send' then
   if not exists(select 1 from qse_v3.account_preferences where user_id=p_target and discoverable) then
      return jsonb_build_object('error','player_not_found');
   end if;
   if exists(select 1 from qse_v3.friendships
     where user_low=least(owner,p_target) and user_high=greatest(owner,p_target)) then
     response := jsonb_build_object('status','noop');
   elsif exists(select 1 from qse_v3.friend_requests where sender_id=p_target and recipient_id=owner) then
     return jsonb_build_object('error','incoming_request_exists');
   elsif (select count(*) from qse_v3.friend_requests where sender_id=owner)>=100 then
     return jsonb_build_object('error','rate_limit');
   else
     insert into qse_v3.friend_requests(sender_id,recipient_id,created_at,request_message)
       values(owner,p_target,now(),cleaned) on conflict do nothing;
     response := jsonb_build_object('status','applied');
   end if;
 elsif p_action in ('accept','decline') then
   delete from qse_v3.friend_requests where sender_id=p_target and recipient_id=owner;
   get diagnostics affected=row_count;
   if affected=0 then return jsonb_build_object('error','request_not_found'); end if;
   if p_action='accept' then
     insert into qse_v3.friendships values(least(owner,p_target),greatest(owner,p_target),now())
       on conflict do nothing;
     delete from qse_v3.friend_requests where sender_id=owner and recipient_id=p_target;
   end if;
   response := jsonb_build_object('status','applied');
 elsif p_action='cancel' then
   delete from qse_v3.friend_requests where sender_id=owner and recipient_id=p_target;
   response := jsonb_build_object('status','applied');
 else
   delete from qse_v3.friendships
    where user_low=least(owner,p_target) and user_high=greatest(owner,p_target);
   response := jsonb_build_object('status','applied');
 end if;
 insert into qse_v3.processed_requests values(owner,p_request_id,'friends',command,response);
 return response;
end $function$;
revoke all on function public.qse_friend_action(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.qse_friend_action(text,uuid,uuid,text) to authenticated;

-- Contrato de três parâmetros preservado para versões antigas do Godot.
create or replace function public.qse_friend_action(p_action text,p_target uuid,p_request_id uuid)
returns jsonb language sql security definer set search_path = ''
as $function$
 select public.qse_friend_action(p_action,p_target,p_request_id,null::text)
$function$;
revoke all on function public.qse_friend_action(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.qse_friend_action(text,uuid,uuid) to authenticated;

-- Mantém friends, incoming e outgoing INTACTOS; adiciona requests fora do perfil.
create or replace function public.qse_friends()
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare owner uuid := qse_v3.require_user();
begin
 perform qse_v3.ensure_player(owner);
 return jsonb_build_object(
 'friends',coalesce((select jsonb_agg(qse_v3.public_fragment(case when f.user_low=owner then f.user_high else f.user_low end) order by f.created_at)
     from qse_v3.friendships f where owner in (f.user_low,f.user_high)),'[]'::jsonb),
 'incoming',coalesce((select jsonb_agg(qse_v3.public_fragment(r.sender_id) order by r.created_at)
     from qse_v3.friend_requests r where r.recipient_id=owner),'[]'::jsonb),
 'outgoing',coalesce((select jsonb_agg(qse_v3.public_fragment(r.recipient_id) order by r.created_at)
     from qse_v3.friend_requests r where r.sender_id=owner),'[]'::jsonb),
 'requests',coalesce((select jsonb_object_agg(other_id::text,
    jsonb_build_object('message',request_message,'requested_at',created_at))
   from (select r.sender_id other_id,r.request_message,r.created_at
         from qse_v3.friend_requests r where r.recipient_id=owner
         union all
         select r.recipient_id other_id,r.request_message,r.created_at
         from qse_v3.friend_requests r where r.sender_id=owner) v),'{}'::jsonb));
end $function$;
revoke all on function public.qse_friends() from public,anon,authenticated;
grant execute on function public.qse_friends() to authenticated;

-- T21: upsert de favoritos exige UPDATE + SELECT + INSERT sob RLS.
create policy qse_deck_favorites_edit on public.qse_deck_favorites
 for update to authenticated
 using (user_id=(select auth.uid()))
 with check (
   user_id=(select auth.uid())
   and (deck_ref ~ '^official:[a-z0-9_]{2,64}$'
   or (deck_ref ~ '^creator:[0-9a-f-]{36}$'
       and exists (select 1 from public.qse_creator_decks d
                    where d.owner_id=(select auth.uid())
                    and d.id=substring(deck_ref from 9)::uuid)))
 );
