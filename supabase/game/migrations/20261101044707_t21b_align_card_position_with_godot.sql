
-- T21-B: align column names exactly with Godot CreatorSync.SCHEMA.
-- No existing cards when this migration is applied; preserves uuid identifiers,
-- owner_id RLS, and the existing FK to the creator deck.
alter table public.qse_creator_cards
  rename column sort_order to position;

alter table public.qse_creator_cards
  drop constraint qse_creator_cards_sort_order_check;
alter table public.qse_creator_cards
  add constraint qse_creator_cards_position_check
  check (position between 0 and 29);

alter index public.qse_creator_cards_deck_order_idx
  rename to qse_creator_cards_deck_position_idx;

notify pgrst, 'reload schema';
