-- Auditoria de metadados: não lê linhas de jogadores e não altera objetos.
begin transaction read only;
select version(),current_user,current_database();
select nspname from pg_catalog.pg_namespace where nspname not like 'pg_%' order by 1;
select n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,
 pg_catalog.pg_get_userbyid(c.relowner) as owner
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','qse_v3','auth','realtime') and c.relkind in ('r','p','v','m') order by 1,2;
select table_schema,table_name,column_name,data_type,is_nullable,column_default
from information_schema.columns where table_schema in ('public','qse_v3','auth','realtime') order by 1,2,ordinal_position;
select n.nspname,c.relname,k.conname,pg_catalog.pg_get_constraintdef(k.oid) as definition
from pg_catalog.pg_constraint k join pg_catalog.pg_class c on c.oid=k.conrelid
join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','qse_v3','auth','realtime') order by 1,2,3;
select * from pg_catalog.pg_policies where schemaname in ('public','qse_v3','auth','realtime') order by schemaname,tablename,policyname;
select n.nspname,p.proname,pg_catalog.pg_get_function_identity_arguments(p.oid) as arguments,
 p.prosecdef,p.proconfig,p.proacl,pg_catalog.pg_get_functiondef(p.oid) as definition
from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','qse_v3') and p.prokind='f' order by 1,2,3;
select n.nspname,c.relname,t.tgname,t.tgenabled,pg_catalog.pg_get_triggerdef(t.oid) as definition
from pg_catalog.pg_trigger t join pg_catalog.pg_class c on c.oid=t.tgrelid
join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and n.nspname in ('public','qse_v3','auth','realtime') order by 1,2,3;
select table_schema,table_name,grantee,privilege_type from information_schema.table_privileges
where table_schema in ('public','qse_v3','auth','realtime') order by 1,2,3,4;
select routine_schema,routine_name,grantee,privilege_type from information_schema.routine_privileges
where routine_schema in ('public','qse_v3') order by 1,2,3;
select n.nspname,d.defaclobjtype,d.defaclacl from pg_catalog.pg_default_acl d
left join pg_catalog.pg_namespace n on n.oid=d.defaclnamespace;
select rolname,rolsuper,rolbypassrls,rolcanlogin from pg_catalog.pg_roles
where rolname in ('anon','authenticated','service_role',current_user);
select pubname,schemaname,tablename from pg_catalog.pg_publication_tables order by 1,2,3;
rollback;
