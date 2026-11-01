
-- T21-B: CreatorSync.remove deletes a private deck first and its image objects second.
-- Deleting private image objects must still work after the deck's row was removed.
-- Authorization continues to require both GAME auth.uid() and storage.owner_id.
-- Other players' image objects remain inaccessible.
alter policy qse_deck_originals_remove on storage.objects
using (
  bucket_id = 'qse-deck-originals'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(storage.objects.name), 1) = 2
);
