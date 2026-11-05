-- CHAT: migration 20261105191616. Funcao Edge usa somente service_role, sem identidade ficticia GAME.
alter table public.qse_chat_messages add column if not exists sender_bot_member_id uuid;
alter table public.qse_chat_messages alter column sender_game_user_id drop not null;
do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.qse_chat_messages'::regclass
   and conname='qse_chat_messages_exactly_one_sender') then
   alter table public.qse_chat_messages add constraint qse_chat_messages_exactly_one_sender
     check((sender_game_user_id is null) <> (sender_bot_member_id is null)) not valid;
 end if;
end $$;
alter table public.qse_chat_messages validate constraint qse_chat_messages_exactly_one_sender;
create index if not exists qse_chat_messages_bot_rate_idx
 on public.qse_chat_messages(conversation_id,sender_bot_member_id,sent_at desc)
 where sender_bot_member_id is not null;
create table if not exists public.qse_chat_bot_emissions(
 conversation_id uuid not null references public.qse_chat_conversations(id) on delete cascade,
 match_id uuid not null,
 event_seq integer not null check(event_seq>=0),
 bot_member_id uuid not null,
 created_at timestamptz not null default now(),
 delivered boolean not null default false,
 primary key(conversation_id,match_id,event_seq,bot_member_id)
);
alter table public.qse_chat_bot_emissions enable row level security;
revoke all on public.qse_chat_bot_emissions from public,anon,authenticated;
grant select,insert,update,delete on public.qse_chat_bot_emissions to service_role;
create index if not exists qse_chat_bot_emissions_expiry_idx on public.qse_chat_bot_emissions(created_at);
CREATE OR REPLACE FUNCTION public.qse_chat_room_bot_emit(p_conversation_id uuid, p_match_id uuid, p_bot_member_id uuid, p_event_seq integer, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_count integer;
  v_message uuid;
  v_when timestamptz;
begin
  if p_conversation_id is null or p_match_id is null or p_bot_member_id is null
    or p_event_seq is null or p_event_seq < 0
    or p_body is null or char_length(btrim(p_body)) not between 1 and 240
    or p_body ~ '[[:cntrl:]]' then
    return jsonb_build_object('error','invalid_bot_event');
  end if;
  if not exists (select 1 from public.qse_chat_conversations c
     where c.id=p_conversation_id and c.kind='room' and c.game_room_id is not null) then
    return jsonb_build_object('error','forbidden');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('qse-room-bot:'||p_conversation_id::text||':'||p_bot_member_id::text,0));
  insert into public.qse_chat_bot_emissions(conversation_id,match_id,event_seq,bot_member_id)
    values(p_conversation_id,p_match_id,p_event_seq,p_bot_member_id)
    on conflict do nothing;
  get diagnostics v_count = row_count;
  if v_count=0 then return jsonb_build_object('duplicate',true,'sent',false); end if;
  if exists (select 1 from public.qse_chat_messages
      where conversation_id=p_conversation_id and sender_bot_member_id=p_bot_member_id
      and sent_at>now()-interval '15 seconds') then
    return jsonb_build_object('duplicate',false,'sent',false,'cooldown',true);
  end if;
  insert into public.qse_chat_messages
    (conversation_id,sender_game_user_id,sender_bot_member_id,body)
  values(p_conversation_id,null,p_bot_member_id,btrim(p_body))
  returning id,sent_at into v_message,v_when;
  update public.qse_chat_bot_emissions set delivered=true
    where conversation_id=p_conversation_id and match_id=p_match_id
      and event_seq=p_event_seq and bot_member_id=p_bot_member_id;
  return jsonb_build_object('duplicate',false,'sent',true,
    'message',jsonb_build_object('id',v_message,'sent_at',v_when));
end $function$
;

revoke all on function public.qse_chat_room_bot_emit(uuid,uuid,uuid,integer,text) from public,anon,authenticated;
grant execute on function public.qse_chat_room_bot_emit(uuid,uuid,uuid,integer,text) to service_role;
CREATE OR REPLACE FUNCTION public.qse_chat_room_read(p_user_id uuid, p_conversation_id uuid, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_messages jsonb;
begin
 if p_user_id is null or p_conversation_id is null
    or not exists(select 1 from public.qse_chat_conversations
       where id=p_conversation_id and kind='room') then
   return jsonb_build_object('error','forbidden');
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',m.id,'sender_game_user_id',m.sender_game_user_id,
  'sender_bot_member_id',m.sender_bot_member_id,
  'body',m.body,'sent_at',m.sent_at
 ) order by m.sent_at desc,m.id desc),'[]'::jsonb) into v_messages
 from (select id,sender_game_user_id,sender_bot_member_id,body,sent_at
   from public.qse_chat_messages
   where conversation_id=p_conversation_id and deleted_at is null
     and sent_at>now()-interval '24 hours'
   order by sent_at desc,id desc
   limit least(greatest(coalesce(p_limit,50),1),50)) m;
 return jsonb_build_object('messages',v_messages);
end $function$
;

