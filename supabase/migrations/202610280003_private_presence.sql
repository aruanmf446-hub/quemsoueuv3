-- NOT DEPLOYED: private-channel configuration and revocation acceptance are mandatory.
-- Requer Supabase Realtime com autorização de canais privados habilitada.
-- Não remove nem altera políticas preexistentes. Interrompe se os pré-requisitos faltarem.
begin;
do $prerequisite$
begin
  if not exists(select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='realtime' and c.relname='messages' and c.relrowsecurity) then
    raise exception 'Realtime messages requer RLS habilitado antes desta migration';
  end if;
end $prerequisite$;
create function qse_v3.presence_allowed(topic text,writing boolean) returns boolean language plpgsql stable security definer set search_path = '' as $$
declare owner uuid := auth.uid(); target uuid;
begin
  if owner is null or topic is null or topic !~ '^friend-presence:[0-9a-fA-F-]{36}$' then return false; end if;
  begin target:=substr(topic,17)::uuid; exception when invalid_text_representation then return false; end;
  if writing then return owner=target; end if;
  return owner=target or exists(select 1 from qse_v3.friendships where user_low=least(owner,target) and user_high=greatest(owner,target));
end $$;
revoke all on function qse_v3.presence_allowed(text,boolean) from public,anon;
grant execute on function qse_v3.presence_allowed(text,boolean) to authenticated;
-- Guardas restritivas impedem que políticas permissivas preexistentes abram este namespace.
-- Outros tópicos Realtime continuam regidos pelas políticas já existentes.
create policy qse_v3_presence_read_guard on realtime.messages as restrictive for select to public
  using (case when (select realtime.topic()) like 'friend-presence:%'
    then extension='presence' and qse_v3.presence_allowed((select realtime.topic()),false) else true end);
create policy qse_v3_presence_write_guard on realtime.messages as restrictive for insert to public
  with check (case when (select realtime.topic()) like 'friend-presence:%'
    then extension='presence' and qse_v3.presence_allowed((select realtime.topic()),true) else true end);
create policy qse_v3_presence_read on realtime.messages for select to authenticated
  using (extension='presence' and qse_v3.presence_allowed((select realtime.topic()),false));
create policy qse_v3_presence_write on realtime.messages for insert to authenticated
  with check (extension='presence' and qse_v3.presence_allowed((select realtime.topic()),true));
commit;
