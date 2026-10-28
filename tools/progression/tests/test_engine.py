from copy import deepcopy
import unittest

from tools.progression import new_state, start_phase, record_checkpoint, complete_phase, equip_character
from tools.progression.codec import ProgressionError, canonical, loads, seal
from tools.progression.engine import available_phases, can_equip, can_use_campaign_character, validate_state
from tools.progression.saves import new_save, load_save, update_local_reference
from tools.progression.tests.helpers import rules, PLAYER


class EngineTests(unittest.TestCase):
    def setUp(self):
        self.rules = rules()
        self.state = new_state(self.rules, PLAYER)

    def advance(self, count):
        for phase in self.rules.phases[:count]:
            self.state = start_phase(self.rules, self.state, phase.id)
            self.state = complete_phase(self.rules, self.state, phase.id, defeated_boss_id=phase.boss_id)

    def error(self, code, function, *args, **kwargs):
        with self.assertRaises(ProgressionError) as caught:
            function(*args, **kwargs)
        self.assertEqual(caught.exception.code, code)

    def test_new_player_seven_heroes_and_first_phase_only(self):
        self.assertEqual(len(self.state["unlocked_character_ids"]), 7)
        self.assertEqual(available_phases(self.rules, self.state), ["desert_phase_01"])
        self.assertEqual(self.state["achievement_ids"], [])
        self.assertFalse(can_equip(self.rules, self.state, "el_fuego"))

    def test_locked_fuego_is_campaign_protagonist(self):
        self.assertTrue(can_use_campaign_character(self.rules, self.state, "desert_phase_01", "el_fuego"))
        self.assertFalse(can_use_campaign_character(self.rules, self.state, "desert_phase_01", "cowboy"))
        self.assertFalse(can_use_campaign_character(self.rules, self.state, "desert_phase_02", "el_fuego"))

    def test_partial_progress_unlocks_only_next_phase(self):
        self.advance(4)
        self.assertEqual(available_phases(self.rules, self.state), list(self.rules.phase_ids[:5]))
        self.assertEqual(self.state["achievement_ids"], [])
        self.assertNotIn("el_fuego", self.state["unlocked_character_ids"])

    def test_phase_one_cannot_unlock_fuego(self):
        self.advance(1)
        self.assertFalse(can_equip(self.rules, self.state, "el_fuego"))

    def test_phase_nine_does_not_award_campaign(self):
        self.advance(9)
        self.assertEqual(self.state["achievement_ids"], [])
        self.assertFalse(can_equip(self.rules, self.state, "el_fuego"))
        self.assertIn("desert_phase_10", available_phases(self.rules, self.state))

    def test_phase_ten_awards_once_after_all_ten(self):
        self.advance(10)
        self.assertEqual(self.state["completed_phase_ids"], list(self.rules.phase_ids))
        self.assertEqual(self.state["achievement_ids"], ["desert_campaign_completed"])
        self.assertTrue(can_equip(self.rules, self.state, "el_fuego"))
        self.assertEqual(self.state["unlocked_character_ids"].count("el_fuego"), 1)

    def test_missing_final_boss_evidence_rejected(self):
        self.advance(9)
        state = start_phase(self.rules, self.state, "desert_phase_10")
        self.error("boss_evidence_required", complete_phase, self.rules, state, "desert_phase_10")
        self.assertEqual(state["completed_phase_ids"], list(self.rules.phase_ids[:9]))

    def test_cannot_skip_phases(self):
        self.error("phase_locked", start_phase, self.rules, self.state, "desert_phase_10")
        self.error("phase_sequence", complete_phase, self.rules, self.state, "desert_phase_10", defeated_boss_id="malagueta")

    def test_cannot_complete_phase_without_start(self):
        self.error("phase_sequence", complete_phase, self.rules, self.state, "desert_phase_01")

    def test_checkpoint_does_not_complete_phase(self):
        state = start_phase(self.rules, self.state, "desert_phase_01")
        state = record_checkpoint(self.rules, state, "desert_phase_01", self.rules.phases[0].checkpoint_ids[0])
        self.assertEqual(state["completed_phase_ids"], [])
        self.assertEqual(state["achievement_ids"], [])
        self.assertEqual(state, record_checkpoint(self.rules, state, "desert_phase_01", self.rules.phases[0].checkpoint_ids[0]))

    def test_wrong_checkpoint_or_phase_rejected(self):
        state = start_phase(self.rules, self.state, "desert_phase_01")
        self.error("unknown_checkpoint", record_checkpoint, self.rules, state, "desert_phase_01", self.rules.phases[1].checkpoint_ids[0])
        self.error("phase_not_active", record_checkpoint, self.rules, state, "desert_phase_02", self.rules.phases[1].checkpoint_ids[0])

    def test_checkpoint_cleared_on_completion(self):
        state = start_phase(self.rules, self.state, "desert_phase_01")
        state = record_checkpoint(self.rules, state, "desert_phase_01", self.rules.phases[0].checkpoint_ids[0])
        state = complete_phase(self.rules, state, "desert_phase_01")
        self.assertIsNone(state["checkpoint"])
        self.assertIsNone(state["active_phase_id"])

    def test_duplicate_completion_is_noop(self):
        self.advance(10)
        self.assertEqual(self.state, complete_phase(self.rules, self.state, "desert_phase_10", defeated_boss_id="malagueta"))

    def test_locked_fuego_and_hostiles_cannot_equip(self):
        for id in ("el_fuego", "cactus", "malagueta", "unknown"):
            with self.subTest(character=id):
                self.error("character_locked", equip_character, self.rules, self.state, id)

    def test_categories_explicit_no_invented_minibosses(self):
        kinds = {c.classification for c in self.rules.characters.values()}
        self.assertEqual(kinds, {"playable_hero", "unlockable_hero", "common_enemy", "final_boss"})
        self.assertEqual(self.rules.characters["cactus"].scope, "campaign_only")
        self.assertEqual(self.rules.characters["malagueta"].scope, "campaign_only")

    def test_hero_equipment_and_duplicate_equip(self):
        state = equip_character(self.rules, self.state, "michelly")
        self.assertEqual(state["equipped_character_id"], "michelly")
        self.assertEqual(state, equip_character(self.rules, state, "michelly"))

    def test_state_tampering_does_not_create_entitlements(self):
        for mutate in (lambda s:s["unlocked_character_ids"].append("el_fuego"), lambda s:s["achievement_ids"].append("desert_campaign_completed"), lambda s:s["completed_phase_ids"].append("desert_phase_10")):
            state = deepcopy(self.state); mutate(state)
            with self.assertRaises(ProgressionError): validate_state(self.rules, state)

    def test_pure_reducer_does_not_mutate_inputs(self):
        original = deepcopy(self.state)
        start_phase(self.rules, self.state, "desert_phase_01")
        self.assertEqual(self.state, original)

    def test_save_roundtrip_and_checksum_failure(self):
        save = new_save(self.rules, PLAYER)
        self.assertEqual(load_save(self.rules, canonical(save)), save)
        save["local_state"]["equipped_character_id"] = "michelly"
        self.error("checksum_mismatch", load_save, self.rules, canonical(save))

    def test_online_mode_rejects_local_grants(self):
        save = new_save(self.rules, PLAYER, "online_authoritative")
        state = start_phase(self.rules, save["local_state"], "desert_phase_01")
        self.error("online_authority_required", update_local_reference, self.rules, save, state)

    def test_corrupt_unknown_future_and_duplicate_json(self):
        for raw in (b'{"schema_version":2,', b'{"schema_version":2,"schema_version":2}', b'{"schema_version":999}', b'{"revision":NaN}'):
            with self.subTest(raw=raw), self.assertRaises(ProgressionError): load_save(self.rules, raw)

    def test_bad_checksum_encoding_rejected(self):
        save = new_save(self.rules, PLAYER);save["integrity"]["digest"] = "é" * 64
        self.error("invalid_integrity", load_save, self.rules, canonical(save))


if __name__ == "__main__":
    unittest.main()
