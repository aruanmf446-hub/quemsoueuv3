-- SOMENTE cluster descartável criado por tools/player_ui/test_database.py.
-- Não executar este arquivo em um projeto Supabase.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users(id uuid primary key,email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to authenticated,service_role;
grant execute on function auth.uid() to authenticated,service_role;
-- Reproduz apenas a superfície SQL usada pelo Realtime, não o serviço WebSocket.
create schema realtime;
create table realtime.messages(id bigint generated always as identity,extension text,topic text);
alter table realtime.messages enable row level security;
create function realtime.topic() returns text language sql stable as $$
  select current_setting('realtime.topic',true)
$$;
grant usage on schema realtime to authenticated;
grant select,insert on realtime.messages to authenticated;
grant usage on all sequences in schema realtime to authenticated;
grant execute on function realtime.topic() to authenticated;
