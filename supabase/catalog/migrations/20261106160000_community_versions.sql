-- Approved, immutable versions only. Author drafts/originals stay private in GAME.
begin;
create table if not exists public.qse_catalog_community_versions (
 id uuid primary key,
 deck_id uuid not null,
 manifest jsonb not null check (jsonb_typeof(manifest)='object'),
 created_at timestamptz not null default now()
);
alter table public.qse_catalog_community_versions enable row level security;
revoke all on public.qse_catalog_community_versions from public,anon,authenticated,service_role;
grant select,insert on public.qse_catalog_community_versions to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('qse-community-previews','qse-community-previews',false,4194304,array['image/png'])
on conflict(id) do nothing;
-- No client Storage policy: only the GAME gateway signs approved version previews.
commit;
