
-- T20. Proprietary community decks are private drafts until publishing/moderation rules are defined.
-- All identity and ownership come from the GAME JWT. No changes to CHAT or CATALOG.
create table public.qse_creator_decks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 3 and 80),
  description text not null default '' check (char_length(description) <= 1500),
  category text not null default '' check (char_length(category) <= 48),
  tags text[] not null default '{}'::text[] check (cardinality(tags) <= 3),
  visibility text not null default 'private' check (visibility = 'private'),
  status text not null default 'draft' check (status = 'draft'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);
create index qse_creator_decks_owner_updated_idx on public.qse_creator_decks(owner_id, updated_at desc);

create table public.qse_creator_cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null,
  owner_id uuid not null default auth.uid(),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  description text not null default '' check (char_length(description) <= 2000),
  sort_order integer not null default 0 check (sort_order between 0 and 10000),
  image_original_path text,
  portrait_center_x numeric(6,5) not null default 0.5 check (portrait_center_x between 0 and 1),
  portrait_center_y numeric(6,5) not null default 0.5 check (portrait_center_y between 0 and 1),
  portrait_zoom numeric(6,3) not null default 1.0 check (portrait_zoom between 1 and 8),
  duel_center_x numeric(6,5) not null default 0.5 check (duel_center_x between 0 and 1),
  duel_center_y numeric(6,5) not null default 0.5 check (duel_center_y between 0 and 1),
  duel_zoom numeric(6,3) not null default 1.0 check (duel_zoom between 1 and 8),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (deck_id,owner_id) references public.qse_creator_decks(id,owner_id) on delete cascade,
  constraint qse_card_original_owned_path check (
    image_original_path is null
    or (
      image_original_path like owner_id::text || '/' || deck_id::text || '/%'
      and char_length(image_original_path) <= 200
    )
  )
);
create index qse_creator_cards_deck_order_idx on public.qse_creator_cards(deck_id, sort_order, id);

-- Favorites are exclusively per GAME account; official IDs are namespaced separately.
create table public.qse_deck_favorites (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  deck_ref text not null check (
    deck_ref ~ '^official:[a-z0-9_]{2,64}$'
    or deck_ref ~ '^creator:[0-9a-f-]{36}$'
  ),
  created_at timestamptz not null default now(),
  primary key (user_id, deck_ref)
);
create index qse_deck_favorites_recent_idx on public.qse_deck_favorites(user_id,created_at desc);

-- Only personal music selection; device graphics, language and input settings stay local.
create table public.qse_user_music_selection (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  hidden_track_ids text[] not null default '{}'::text[] check (cardinality(hidden_track_ids) <= 100),
  deselected_track_ids text[] not null default '{}'::text[] check (cardinality(deselected_track_ids) <= 100),
  updated_at timestamptz not null default now()
);

create function qse_v3.t20_touch_updated_at()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;
create trigger qse_creator_decks_updated_at before update on public.qse_creator_decks
  for each row execute function qse_v3.t20_touch_updated_at();
create trigger qse_creator_cards_updated_at before update on public.qse_creator_cards
  for each row execute function qse_v3.t20_touch_updated_at();
create trigger qse_user_music_selection_updated_at before update on public.qse_user_music_selection
  for each row execute function qse_v3.t20_touch_updated_at();

-- Serialize concurrent additions per deck, enforce 30 cards even for malicious API callers.
create function qse_v3.t20_enforce_card_limit()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  perform 1 from public.qse_creator_decks
    where id=new.deck_id and owner_id=new.owner_id for update;
  if (select count(*) from public.qse_creator_cards where deck_id=new.deck_id) >= 30 then
    raise exception 'Maximum of 30 cards per deck' using errcode='23514';
  end if;
  return new;
end $$;
create trigger qse_creator_card_limit before insert on public.qse_creator_cards
  for each row execute function qse_v3.t20_enforce_card_limit();

-- Strict per-account row ownership (private drafts only).
alter table public.qse_creator_decks enable row level security;
alter table public.qse_creator_cards enable row level security;
alter table public.qse_deck_favorites enable row level security;
alter table public.qse_user_music_selection enable row level security;
alter table public.qse_creator_decks force row level security;
alter table public.qse_creator_cards force row level security;
alter table public.qse_deck_favorites force row level security;
alter table public.qse_user_music_selection force row level security;

create policy qse_creator_decks_read on public.qse_creator_decks
  for select to authenticated using (owner_id = (select auth.uid()));
create policy qse_creator_decks_add on public.qse_creator_decks
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy qse_creator_decks_edit on public.qse_creator_decks
  for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy qse_creator_decks_remove on public.qse_creator_decks
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy qse_creator_cards_read on public.qse_creator_cards
  for select to authenticated using (owner_id = (select auth.uid()));
create policy qse_creator_cards_add on public.qse_creator_cards
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy qse_creator_cards_edit on public.qse_creator_cards
  for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy qse_creator_cards_remove on public.qse_creator_cards
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy qse_deck_favorites_read on public.qse_deck_favorites
  for select to authenticated using (user_id = (select auth.uid()));
create policy qse_deck_favorites_add on public.qse_deck_favorites
  for insert to authenticated with check (
    user_id = (select auth.uid()) and
    case
      when deck_ref ~ '^official:[a-z0-9_]{2,64}$' then true
      when deck_ref ~ '^creator:[0-9a-f-]{36}$' then
        exists(select 1 from public.qse_creator_decks d
          where d.owner_id = (select auth.uid())
          and d.id = substring(deck_ref from 9)::uuid)
      else false
    end
  );
create policy qse_deck_favorites_remove on public.qse_deck_favorites
  for delete to authenticated using (user_id = (select auth.uid()));

create policy qse_music_selection_read on public.qse_user_music_selection
  for select to authenticated using (user_id = (select auth.uid()));
create policy qse_music_selection_add on public.qse_user_music_selection
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy qse_music_selection_edit on public.qse_user_music_selection
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy qse_music_selection_remove on public.qse_user_music_selection
  for delete to authenticated using (user_id = (select auth.uid()));

-- Supabase October 30 2026: explicit GRANT required for new Data API objects.
revoke all on public.qse_creator_decks, public.qse_creator_cards,
  public.qse_deck_favorites,public.qse_user_music_selection from public, anon;
grant select,insert,update,delete on public.qse_creator_decks,
  public.qse_creator_cards,public.qse_deck_favorites,
  public.qse_user_music_selection to authenticated;
-- Favorites must not be edited: remove and add instead.
revoke update on public.qse_deck_favorites from authenticated;
revoke all on function qse_v3.t20_touch_updated_at() from public,anon,authenticated;
revoke all on function qse_v3.t20_enforce_card_limit() from public,anon,authenticated;

-- Private originals; a public deck/media publication mechanism is intentionally NOT enabled.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('qse-deck-originals','qse-deck-originals',false,10485760,
  array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do nothing;

-- File naming: <GAME uid>/<owned deck uuid>/<image uuid>.(jpg|jpeg|png|webp)
create policy qse_deck_originals_read on storage.objects
for select to authenticated using (
  bucket_id='qse-deck-originals'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
create policy qse_deck_originals_add on storage.objects
for insert to authenticated with check (
  bucket_id='qse-deck-originals'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and storage.filename(name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$'
  and exists (
    select 1 from public.qse_creator_decks d
    where d.owner_id=(select auth.uid()) and d.id::text=(storage.foldername(name))[2]
  )
);
create policy qse_deck_originals_edit on storage.objects
for update to authenticated
using (
  bucket_id='qse-deck-originals'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[1]=(select auth.uid())::text
)
with check (
  bucket_id='qse-deck-originals'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and storage.filename(name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$'
);
create policy qse_deck_originals_remove on storage.objects
for delete to authenticated using (
  bucket_id='qse-deck-originals'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
select pg_notify('pgrst','reload schema');
