-- T16D CHAT: salas do Duelo usam o armazenamento e TTL existentes.
-- Membros NÃO são espelhados: autorização sempre conferida no GAME no gateway.
alter table public.qse_chat_conversations
 add column if not exists game_room_id uuid;
alter table public.qse_chat_conversations
 drop constraint if exists qse_chat_conversations_kind_check;
alter table public.qse_chat_conversations
 add constraint qse_chat_conversations_kind_check
 check (kind in ('direct','group','room'));
alter table public.qse_chat_conversations
 add constraint qse_chat_conversations_room_check
 check ((kind = 'room' and game_room_id is not null)
    or (kind <> 'room' and game_room_id is null));
create unique index if not exists qse_chat_conversations_game_room_idx
 on public.qse_chat_conversations(game_room_id)
 where game_room_id is not null;

-- Executável somente pelo service_role do gateway.
-- A autenticação e participação AO VIVO são checadas no GAME antes desta RPC.
create or replace function public.qse_chat_room_read(
 p_user_id uuid,p_conversation_id uuid,p_limit integer default 50
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_messages jsonb;
begin
 if p_user_id is null or p_conversation_id is null
    or not exists(select 1 from public.qse_chat_conversations
       where id=p_conversation_id and kind='room') then
   return jsonb_build_object('error','forbidden');
 end if;
 select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'id',m.id,'sender_game_user_id',m.sender_game_user_id,
  'body',m.body,'sent_at',m.sent_at
 ) order by m.sent_at desc,m.id desc),'[]'::jsonb) into v_messages
 from (
   select id,sender_game_user_id,body,sent_at from public.qse_chat_messages
   where conversation_id=p_conversation_id
     and deleted_at is null
     and sent_at > pg_catalog.now()-interval '24 hours'
   order by sent_at desc,id desc
   limit least(greatest(coalesce(p_limit,50),1),50)
 ) m;
 return jsonb_build_object('messages',v_messages);
end;
$$;

create or replace function public.qse_chat_room_send(
 p_sender uuid,p_conversation_id uuid,p_request_id uuid,p_body text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_existing public.qse_chat_messages%rowtype; v_id uuid; v_sent timestamptz; v_count integer;
begin
 if p_sender is null or p_conversation_id is null or p_request_id is null
   or p_body is null or pg_catalog.char_length(pg_catalog.btrim(p_body)) not between 1 and 2000 then
   return jsonb_build_object('error','invalid_message');
 end if;
 -- Mesmo lock e mesmo índice UNIQUE do envio privado: limite GLOBAL por usuário.
 perform pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended('qse-chat-send:'||p_sender::text,0)
 );
 select * into v_existing from public.qse_chat_messages
 where sender_game_user_id=p_sender and client_request_id=p_request_id limit 1;
 if found then
   if v_existing.conversation_id <> p_conversation_id
      or v_existing.body <> pg_catalog.btrim(p_body) then
     return jsonb_build_object('error','idempotency_conflict');
   end if;
   if v_existing.sent_at <= pg_catalog.now()-interval '24 hours' then
     return jsonb_build_object('error','expired_request');
   end if;
   return jsonb_build_object('message',jsonb_build_object(
     'id',v_existing.id,'sent_at',v_existing.sent_at),'duplicate',true);
 end if;
 if not exists(select 1 from public.qse_chat_conversations
               where id=p_conversation_id and kind='room') then
   return jsonb_build_object('error','forbidden');
 end if;
 select count(*) into v_count from public.qse_chat_messages
 where sender_game_user_id=p_sender and sent_at > pg_catalog.now()-interval '60 seconds';
 if v_count >= 20 then return jsonb_build_object('error','rate_limited'); end if;
 insert into public.qse_chat_messages
    (conversation_id,sender_game_user_id,client_request_id,body)
 values(p_conversation_id,p_sender,p_request_id,pg_catalog.btrim(p_body))
 returning id,sent_at into v_id,v_sent;
 return jsonb_build_object('message',jsonb_build_object(
   'id',v_id,'sent_at',v_sent),'duplicate',false);
end;
$$;
revoke all on function public.qse_chat_room_read(uuid,uuid,integer)
 from public,anon,authenticated;
revoke all on function public.qse_chat_room_send(uuid,uuid,uuid,text)
 from public,anon,authenticated;
grant execute on function public.qse_chat_room_read(uuid,uuid,integer) to service_role;
grant execute on function public.qse_chat_room_send(uuid,uuid,uuid,text) to service_role;
