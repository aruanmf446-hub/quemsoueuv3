-- Somente consultas; revisar resultado antes de aplicar migrations. Não contém credenciais.
select version();
select nspname from pg_catalog.pg_namespace where nspname in ('qse_v3','auth','realtime');
select table_schema,table_name,column_name,data_type from information_schema.columns
 where (table_schema='auth' and table_name='users') or (table_schema='realtime' and table_name='messages')
 order by table_schema,table_name,ordinal_position;
select table_schema,table_name,column_name,data_type from information_schema.columns
 where table_schema in ('public','qse_v3') and table_name ilike any
   (array['%profile%','%prefer%','%friend%','%wallet%','%transaction%','%achievement%','%progress%','%unlock%','%loadout%'])
 order by table_schema,table_name,ordinal_position;
select n.nspname,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid)
 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='public' and p.proname like 'qse_%') or n.nspname='qse_v3';
-- Políticas permissivas anteriores em realtime.messages podem ampliar acesso por OR.
-- As guardas restritivas de 0003 protegem friend-presence:* mesmo diante de políticas
-- permissivas. Revisar sua interação e a autorização do Realtime antes da aplicação.
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
 from pg_catalog.pg_policies where schemaname in ('public','qse_v3','realtime');
select rolname,rolbypassrls from pg_catalog.pg_roles where rolname in ('anon','authenticated','service_role');
