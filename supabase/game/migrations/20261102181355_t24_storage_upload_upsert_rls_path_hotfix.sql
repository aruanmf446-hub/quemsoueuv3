-- Hotfix T24: deck paths must come from storage.objects.name, not
-- qse_creator_decks.name (display title) inside correlated RLS subqueries.
-- All mutations still require owner + draft/rejected; published/pending locked.
-- Preserve the original T21 owner-only reads and public-preview helpers.
drop policy if exists qse_t24_originals_insert_draft on storage.objects;
create policy qse_t24_originals_insert_draft on storage.objects
  as restrictive for insert to authenticated
  with check (
    bucket_id <> 'qse-deck-originals'
    or exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
  );

drop policy if exists qse_t24_originals_update_draft on storage.objects;
create policy qse_t24_originals_update_draft on storage.objects
  as restrictive for update to authenticated
  using (
    bucket_id <> 'qse-deck-originals'
    or exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
  )
  with check (
    bucket_id <> 'qse-deck-originals'
    or exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
  );

drop policy if exists qse_t24_originals_delete_draft_or_orphan on storage.objects;
create policy qse_t24_originals_delete_draft_or_orphan on storage.objects
  as restrictive for delete to authenticated
  using (
    bucket_id <> 'qse-deck-originals'
    or exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
    or not exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
    )
  );

drop policy if exists qse_t24_cover_insert_draft on storage.objects;
create policy qse_t24_cover_insert_draft on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'qse-deck-originals'
    and owner_id = (select auth.uid())::text
    and name = (select auth.uid())::text || '/'
               || (storage.foldername(objects.name))[2] || '/deck_cover.png'
    and exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
  );

drop policy if exists qse_t24_cover_update_draft on storage.objects;
create policy qse_t24_cover_update_draft on storage.objects
  for update to authenticated
  using (
    bucket_id = 'qse-deck-originals'
    and owner_id = (select auth.uid())::text
    and storage.filename(objects.name) = 'deck_cover.png'
    and exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
  )
  with check (
    bucket_id = 'qse-deck-originals'
    and owner_id = (select auth.uid())::text
    and name = (select auth.uid())::text || '/'
               || (storage.foldername(objects.name))[2] || '/deck_cover.png'
    and exists (
      select 1 from public.qse_creator_decks d
      where d.owner_id = (select auth.uid())
        and d.id::text = (storage.foldername(objects.name))[2]
        and d.status in ('draft','rejected')
    )
  );
