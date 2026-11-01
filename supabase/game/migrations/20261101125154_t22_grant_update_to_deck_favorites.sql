-- T22 GAME: RLS permite apenas dados próprios, mas upsert também exige GRANT SQL UPDATE.
grant update on table public.qse_deck_favorites to authenticated;
