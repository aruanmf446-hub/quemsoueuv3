
-- Godot T21-B sends POST ...?on_conflict=id with resolution=merge-duplicates.
-- PostgreSQL runs BEFORE INSERT triggers even for rows later changed by ON CONFLICT.
-- Existing cards must not count as a new card when the deck already has 30 cards.
create or replace function qse_v3.t20_enforce_card_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- Serializes additions to the same deck; owner check stays in RLS + composite FK.
  perform 1 from public.qse_creator_decks
    where id = new.deck_id and owner_id = new.owner_id
    for update;

  if exists (
    select 1 from public.qse_creator_cards existing
    where existing.id = new.id
      and existing.deck_id = new.deck_id
      and existing.owner_id = new.owner_id
  ) then
    return new;
  end if;

  if (select count(*) from public.qse_creator_cards
      where deck_id = new.deck_id and owner_id = new.owner_id) >= 30 then
    raise exception 'Maximum of 30 cards per deck' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function qse_v3.t20_enforce_card_limit() from public, anon, authenticated;
