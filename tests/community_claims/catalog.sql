-- Execute after the CATALOG migration, in the same transaction, then ROLLBACK.
do $$ begin
 if not exists(select 1 from storage.buckets where id='qse-community-previews' and not public) then raise exception 'preview bucket must remain private'; end if;
 if has_table_privilege('anon','public.qse_catalog_community_versions','select') then raise exception 'anonymous snapshot access'; end if;
 if has_table_privilege('authenticated','public.qse_catalog_community_versions','insert') then raise exception 'untrusted publication'; end if;
 if not has_table_privilege('service_role','public.qse_catalog_community_versions','select,insert') then raise exception 'gateway cannot distribute versions'; end if;
 if has_table_privilege('service_role','public.qse_catalog_community_versions','update') then raise exception 'versions must be immutable via gateway'; end if;
 if not (select relrowsecurity from pg_class where oid='public.qse_catalog_community_versions'::regclass) then raise exception 'RLS disabled'; end if;
end;$$;
select 6 as checks,0 as failures;
