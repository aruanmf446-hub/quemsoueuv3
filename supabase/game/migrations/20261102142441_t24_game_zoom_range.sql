alter table public.qse_creator_cards
 drop constraint qse_creator_cards_portrait_zoom_check,
 drop constraint qse_creator_cards_duel_zoom_check;
alter table public.qse_creator_cards
 add constraint qse_creator_cards_portrait_zoom_check check (portrait_zoom between 0.35 and 6),
 add constraint qse_creator_cards_duel_zoom_check check (duel_zoom between 0.35 and 6);
