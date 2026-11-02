-- T24: arquivo em revisão/publicado é imutável para o dono.
-- RLS RESTRICTIVE compõe AND com as policies de propriedade do Storage (não OR).
drop policy if exists qse_t24_originals_insert_draft on storage.objects;
create policy qse_t24_originals_insert_draft on storage.objects as restrictive
for insert to authenticated
with check (
 bucket_id <> 'qse-deck-originals' or exists(
  select 1 from public.qse_creator_decks d
  where d.owner_id=(select auth.uid())
  and d.id::text=(storage.foldername(name))[2]
  and d.status='draft')
);
drop policy if exists qse_t24_originals_update_draft on storage.objects;
create policy qse_t24_originals_update_draft on storage.objects as restrictive
for update to authenticated
using (bucket_id <> 'qse-deck-originals' or exists(
  select 1 from public.qse_creator_decks d
  where d.owner_id=(select auth.uid())
  and d.id::text=(storage.foldername(name))[2]
  and d.status='draft'))
with check (bucket_id <> 'qse-deck-originals' or exists(
  select 1 from public.qse_creator_decks d
  where d.owner_id=(select auth.uid())
  and d.id::text=(storage.foldername(name))[2]
  and d.status='draft'));
drop policy if exists qse_t24_originals_delete_draft_or_orphan on storage.objects;
create policy qse_t24_originals_delete_draft_or_orphan on storage.objects as restrictive
for delete to authenticated using (
 bucket_id <> 'qse-deck-originals'
 or exists(select 1 from public.qse_creator_decks d
  where d.owner_id=(select auth.uid())
  and d.id::text=(storage.foldername(name))[2]
  and d.status='draft')
 or not exists(select 1 from public.qse_creator_decks d
  where d.owner_id=(select auth.uid())
  and d.id::text=(storage.foldername(name))[2])
);
