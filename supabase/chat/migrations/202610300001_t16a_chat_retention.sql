-- T16A CHAT: TTL de 24 h em leitura e limpeza física; acesso exclusivo via gateway.
-- Backup de dados legitimos: a primeira execução atua apenas em linhas já expiradas.
create extension if not exists pg_cron with schema pg_catalog;

alter table public.qse_chat_messages
  add column if not exists client_request_id uuid;

create index if not exists qse_chat_messages_expiry_idx
  on public.qse_chat_messages (sent_at, id);
create index if not exists qse_chat_messages_rate_idx
  on public.qse_chat_messages (sender_game_user_id, sent_at desc);
create unique index if not exists qse_chat_messages_request_idx
  on public.qse_chat_messages (sender_game_user_id, client_request_id)
  where client_request_id is not null;

-- Leitura única: membership + filtro temporal dentro do próprio PostgreSQL.
-- Não depende de cron já ter executado.
create or replace function public.qse_chat_read(
  p_user_id uuid, p_conversation_id uuid, p_limit int default 50
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_messages jsonb;
begin
  if p_user_id is null or p_conversation_id is null
     or not exists (
       select 1 from public.qse_chat_members
       where conversation_id=p_conversation_id and game_user_id=p_user_id
     ) then
    return jsonb_build_object('error','forbidden');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',m.id,'sender_game_user_id',m.sender_game_user_id,
      'body',m.body,'sent_at',m.sent_at
    ) order by m.sent_at desc,m.id desc),'[]'::jsonb)
    into v_messages
    from (
      select id,sender_game_user_id,body,sent_at
      from public.qse_chat_messages
      where conversation_id=p_conversation_id
        and deleted_at is null
        and sent_at > pg_catalog.now() - interval '24 hours'
      order by sent_at desc,id desc
      limit least(greatest(coalesce(p_limit,50),1),50)
    ) m;
  return jsonb_build_object('messages',v_messages);
end;
$$;

-- Limite de 20 mensagens em janela deslizante de 60 s, inclusive requisições paralelas.
-- Uma única RPC substitui contagem + inserção separadas; chave de idempotência para retries.
create or replace function public.qse_chat_send(
  p_sender uuid, p_conversation_id uuid, p_request_id uuid, p_body text
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_existing public.qse_chat_messages%rowtype;
  v_id uuid;
  v_sent timestamptz;
  v_count int;
begin
  if p_sender is null or p_conversation_id is null or p_request_id is null
    or p_body is null or pg_catalog.char_length(pg_catalog.btrim(p_body)) not between 1 and 2000 then
    return jsonb_build_object('error','invalid_message');
  end if;
  -- Serializa apenas por remetente: evita corrida do contador e duplicatas simultâneas.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('qse-chat-send:' || p_sender::text,0)
  );
  select * into v_existing from public.qse_chat_messages
   where sender_game_user_id=p_sender and client_request_id=p_request_id
   limit 1;
  if found then
    if v_existing.conversation_id <> p_conversation_id
       or v_existing.body <> pg_catalog.btrim(p_body) then
      return jsonb_build_object('error','idempotency_conflict');
    end if;
    if v_existing.sent_at <= pg_catalog.now() - interval '24 hours' then
      return jsonb_build_object('error','expired_request');
    end if;
    return jsonb_build_object('message',jsonb_build_object(
      'id',v_existing.id,'sent_at',v_existing.sent_at),'duplicate',true);
  end if;
  if (select count(*) from public.qse_chat_members
      where conversation_id=p_conversation_id) <> 2
     or not exists (
       select 1 from public.qse_chat_members
       where conversation_id=p_conversation_id and game_user_id=p_sender
     )
     or not exists (
       select 1 from public.qse_chat_conversations
       where id=p_conversation_id and kind='direct'
     ) then
    return jsonb_build_object('error','forbidden');
  end if;
  select count(*) into v_count from public.qse_chat_messages
    where sender_game_user_id=p_sender
      and sent_at > pg_catalog.now() - interval '60 seconds';
  if v_count >= 20 then
    return jsonb_build_object('error','rate_limited');
  end if;
  insert into public.qse_chat_messages
     (conversation_id,sender_game_user_id,client_request_id,body)
    values(p_conversation_id,p_sender,p_request_id,pg_catalog.btrim(p_body))
    returning id,sent_at into v_id,v_sent;
  return jsonb_build_object('message',jsonb_build_object(
    'id',v_id,'sent_at',v_sent),'duplicate',false);
end;
$$;

-- Limpeza em lotes com SKIP LOCKED: nunca bloqueia uma tabela inteira.
-- Conversas vazias antigas são apagadas após a remoção dos registros expirados.
create or replace function public.qse_chat_cleanup(
  p_message_batch int default 2000, p_room_batch int default 250
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_deleted_messages int := 0; v_deleted_rooms int := 0;
begin
  if p_message_batch not between 1 and 5000 or p_room_batch not between 1 and 500 then
    raise exception 'invalid cleanup batch';
  end if;
  with targets as (
    select id from public.qse_chat_messages
      where sent_at <= pg_catalog.now() - interval '24 hours'
      order by sent_at,id
      limit p_message_batch
      for update skip locked
  ), removed as (
    delete from public.qse_chat_messages m
      using targets t where m.id=t.id returning m.id
  ) select count(*) into v_deleted_messages from removed;

  with empty_rooms as (
    select c.id from public.qse_chat_conversations c
    where c.created_at <= pg_catalog.now() - interval '24 hours'
      and not exists (
        select 1 from public.qse_chat_messages m where m.conversation_id=c.id
      )
    order by c.created_at,c.id
    limit p_room_batch for update of c skip locked
  ), removed as (
    delete from public.qse_chat_conversations c
    using empty_rooms e where c.id=e.id returning c.id
  ) select count(*) into v_deleted_rooms from removed;
  return jsonb_build_object('messages_deleted',v_deleted_messages,'rooms_deleted',v_deleted_rooms);
end;
$$;

-- Só o serviço verificado no servidor pode chamar as RPCs; cliente anon/JWT de outro projeto nunca.
revoke all on function public.qse_chat_read(uuid,uuid,int) from public,anon,authenticated;
revoke all on function public.qse_chat_send(uuid,uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.qse_chat_cleanup(int,int) from public,anon,authenticated;
grant execute on function public.qse_chat_read(uuid,uuid,int) to service_role;
grant execute on function public.qse_chat_send(uuid,uuid,uuid,text) to service_role;

-- Uma execução por minuto, até 2.000 mensagens e 250 salas por execução (2,88M msg/dia).
-- Job criado apenas neste banco CHAT.
select cron.schedule('qse-chat-ttl-24h','* * * * *',
  'select public.qse_chat_cleanup(2000,250);');
