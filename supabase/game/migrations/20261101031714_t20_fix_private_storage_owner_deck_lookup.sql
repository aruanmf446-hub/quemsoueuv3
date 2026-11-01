
-- Fix ambiguous "name": inside the EXISTS subquery d.name shadowed storage.objects.name.
alter policy qse_deck_originals_add on storage.objects
with check (
  bucket_id='qse-deck-originals'
  and owner_id=(select auth.uid())::text
  and (storage.foldername(storage.objects.name))[1]=(select auth.uid())::text
  and storage.filename(storage.objects.name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$'
  and exists (
    select 1 from public.qse_creator_decks d
    where d.owner_id=(select auth.uid())
      and d.id::text=(storage.foldername(storage.objects.name))[2]
  )
);
