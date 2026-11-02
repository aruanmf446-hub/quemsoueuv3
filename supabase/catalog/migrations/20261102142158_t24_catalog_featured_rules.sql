create table public.qse_catalog_featured (
 id uuid primary key default gen_random_uuid(),
 kind text not null check (kind in ('pin','campaign')),
 deck_ref text,
 theme text,
 title text check (title is null or char_length(title)<=40),
 starts_at timestamptz,
 ends_at timestamptz,
 priority integer not null default 0,
 active boolean not null default true,
 constraint featured_target_required check (deck_ref is not null or theme is not null),
 constraint featured_deck_format check (deck_ref is null or deck_ref ~ '^(official:[a-z0-9_]{2,64}|creator:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$'),
 constraint featured_time_window check (ends_at is null or starts_at is null or ends_at>starts_at)
);
alter table public.qse_catalog_featured enable row level security;
revoke all on public.qse_catalog_featured from anon,authenticated;
grant select on public.qse_catalog_featured to anon,authenticated;
create policy qse_catalog_featured_active_read on public.qse_catalog_featured for select to anon,authenticated using (active=true);
create index qse_catalog_featured_active_priority on public.qse_catalog_featured (priority desc) where active=true;
insert into public.qse_catalog_featured(kind,theme,title,starts_at,ends_at)
 values ('campaign','Natal','Especial de Natal','2026-12-01T03:00:00Z','2026-12-26T03:00:00Z'),
        ('campaign','Halloween','Noite de Halloween','2026-10-20T03:00:00Z','2026-11-01T03:00:00Z');
