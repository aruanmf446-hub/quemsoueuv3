
-- T21 compatibility with Claude editor. All four tables are empty at migration.
-- No change to existing GAME user/duel tables, CHAT or CATALOG.
alter table public.qse_creator_decks
  add column if not exists requested_visibility text not null default 'private'
    check(requested_visibility in ('private','unlisted','public'));
alter table public.qse_creator_decks
  add constraint qse_t21_name_length check (char_length(btrim(name)) <= 60),
  add constraint qse_t21_description_length check (char_length(description) <= 400),
  add constraint qse_t21_category check(category in ('','Lendas e terror','Personagens','Animais','Lugares','Objetos','Outros'));
alter table public.qse_creator_cards
  add constraint qse_t21_card_name_length check(char_length(btrim(name)) <= 40),
  add constraint qse_t21_card_description_length check(char_length(description) <= 300),
  add constraint qse_t21_library_zoom_max check(portrait_zoom <= 6),
  add constraint qse_t21_duel_zoom_max check(duel_zoom <= 6);

-- Claude uses a WhatsApp-style crop with 5:7 library and 16:5 duel previews.
-- Match his picker: 12 MiB. Files remain private, owned per GAME user and per owned deck.
update storage.buckets
set file_size_limit = 12582912
where id = 'qse-deck-originals' and public = false and file_size_limit = 10485760;

-- File pattern: <uuid>_original.(png|jpg|jpeg|webp),
-- <uuid>_library.png or <uuid>_duel.png. No arbitrary files/folders.
alter policy qse_deck_originals_add on storage.objects
with check (
  bucket_id = 'qse-deck-originals'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name),1) = 2
  and storage.filename(storage.objects.name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_(original\.(png|jpg|jpeg|webp)|library\.png|duel\.png)$'
  and exists (
    select 1 from public.qse_creator_decks d
    where d.owner_id = (select auth.uid())
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
);
alter policy qse_deck_originals_edit on storage.objects
using (
  bucket_id = 'qse-deck-originals'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.qse_creator_decks d
    where d.owner_id = (select auth.uid())
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
)
with check (
  bucket_id = 'qse-deck-originals'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name),1) = 2
  and storage.filename(storage.objects.name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_(original\.(png|jpg|jpeg|webp)|library\.png|duel\.png)$'
  and exists (
    select 1 from public.qse_creator_decks d
    where d.owner_id = (select auth.uid())
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
);
alter policy qse_deck_originals_remove on storage.objects
using (
  bucket_id = 'qse-deck-originals'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.qse_creator_decks d
    where d.owner_id = (select auth.uid())
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
);
select pg_notify('pgrst', 'reload schema');
