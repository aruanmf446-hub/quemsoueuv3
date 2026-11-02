alter table public.qse_catalog_decks add column if not exists published_at timestamptz;
update public.qse_catalog_decks set published_at='2026-10-30T13:33:30Z'::timestamptz where id='lendas_urbanas' and published_at is null;
do $$ begin
 if exists(select 1 from public.qse_catalog_decks where published_at is null) then
 raise exception 'unknown historic publication date'; end if;
end $$;
alter table public.qse_catalog_decks alter column published_at set not null;
