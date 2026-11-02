-- T25 - non-destructive foreign-key indexes after the GAME security audit.
-- Preserve all existing RPC signatures, RLS policies and table contracts.
create index if not exists qse_t25_cards_deck_owner_fk_idx
  on public.qse_creator_cards (deck_id, owner_id);
create index if not exists qse_t25_decks_cover_card_fk_idx
  on public.qse_creator_decks (cover_card_id);
create index if not exists qse_t25_campaign_active_phase_fk_idx
  on qse_v3.campaign_progress (active_phase_id);
create index if not exists qse_t25_unlocks_character_fk_idx
  on qse_v3.character_unlocks (character_id);
create index if not exists qse_t25_unlocks_achievement_fk_idx
  on qse_v3.character_unlocks (user_id, achievement_id);
create index if not exists qse_t25_evidence_phase_fk_idx
  on qse_v3.completion_evidence (phase_id);
create index if not exists qse_t25_invites_sender_fk_idx
  on qse_v3.duel_friend_invites (sender_id);
create index if not exists qse_t25_invite_links_creator_fk_idx
  on qse_v3.duel_invite_links (created_by);
create index if not exists qse_t25_friendships_high_fk_idx
  on qse_v3.friendships (user_high);
create index if not exists qse_t25_completions_phase_fk_idx
  on qse_v3.phase_completions (phase_id);
create index if not exists qse_t25_completions_evidence_fk_idx
  on qse_v3.phase_completions (user_id, phase_id, evidence_id);
create index if not exists qse_t25_loadout_equipped_fk_idx
  on qse_v3.player_loadout (user_id, equipped_character_id);
