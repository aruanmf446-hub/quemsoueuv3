from copy import deepcopy
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.progression.codec import ROOT, ProgressionError, canonical, loads, seal
from tools.progression.migration import migrate_sources
from tools.progression.saves import new_save
from tools.progression.storage import write_migration_bundle, inspect_migration_bundle, write_new_file
from tools.progression.tests.helpers import rules, PLAYER, OTHER


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.rules = rules()
        self.sources = {"progress_dev.cfg": b"[flags]\n\ndesert_stage_completed=true\n", "lobby.cfg": b'[lobby]\ncharacter_id="el_fuego"\n'}

    def migrate(self, sources=None):
        return migrate_sources(self.rules, self.sources if sources is None else sources, PLAYER)

    def test_legacy_flag_and_equipment_do_not_grant_skin(self):
        result = self.migrate()
        self.assertEqual(result.report["status"], "migrated_unverified")
        self.assertTrue(result.report["requires_server_review"])
        self.assertEqual(result.save["local_state"]["completed_phase_ids"], [])
        self.assertNotIn("el_fuego", result.save["local_state"]["unlocked_character_ids"])
        self.assertEqual(result.save["migration_receipt"]["prior_equipped_character_id"], "el_fuego")

    def test_canonical_flag_alone_is_not_completion_proof(self):
        result = self.migrate({"progress.cfg": b"[flags]\ndesert_campaign_completed=true\n"})
        self.assertEqual(result.save["local_state"]["achievement_ids"], [])
        self.assertNotIn("el_fuego", result.save["local_state"]["unlocked_character_ids"])

    def test_false_flag_and_initial_equipment_preserved(self):
        result = self.migrate({"progress.cfg": b"[flags]\ndesert_stage_completed=false\n", "lobby.cfg": b'[lobby]\ncharacter_id="michelly"\n'})
        self.assertEqual(result.save["local_state"]["equipped_character_id"], "michelly")
        self.assertFalse(result.report["requires_server_review"])

    def test_boss_equipment_is_retained_for_review_not_equipped(self):
        result = self.migrate({"lobby.cfg": b'[lobby]\ncharacter_id="malagueta"\n'})
        self.assertEqual(result.save["local_state"]["equipped_character_id"], "cowboy")
        self.assertEqual(result.save["migration_receipt"]["prior_equipped_character_id"], "malagueta")

    def test_v1_verified_true_file_is_still_untrusted(self):
        source = (ROOT / "data/contracts/examples/player_state.completed.json").read_bytes()
        result = self.migrate({"old.json": source})
        self.assertEqual(result.save["migration_receipt"]["claimed_completed_phase_ids"], list(self.rules.phase_ids))
        self.assertEqual(result.save["local_state"]["achievement_ids"], [])
        self.assertNotIn("el_fuego", result.save["local_state"]["unlocked_character_ids"])

    def test_v1_partial_claims_preserved_without_grants(self):
        source = loads((ROOT / "data/contracts/examples/player_state.completed.json").read_bytes())
        source["phase_completions"] = source["phase_completions"][:4]
        source["campaigns"][0]["completed_phase_ids"] = list(self.rules.phase_ids[:4])
        result = self.migrate({"old.json": canonical(source)})
        self.assertEqual(result.save["migration_receipt"]["claimed_completed_phase_ids"], list(self.rules.phase_ids[:4]))
        self.assertEqual(result.save["local_state"]["completed_phase_ids"], [])

    def test_v1_cannot_migrate_to_another_player(self):
        source = loads((ROOT / "data/contracts/examples/player_state.initial.json").read_bytes());source["profile"]["user_id"] = OTHER
        result = self.migrate({"old.json": canonical(source)})
        self.assertIsNone(result.save);self.assertIn("player_mismatch", result.report["errors"])

    def test_v1_skipped_or_duplicate_phases_quarantined(self):
        original = loads((ROOT / "data/contracts/examples/player_state.completed.json").read_bytes())
        for phases in ([original["phase_completions"][-1]], original["phase_completions"] + original["phase_completions"][:1]):
            source = deepcopy(original);source["phase_completions"] = phases
            result = self.migrate({"old.json": canonical(source)})
            self.assertIsNone(result.save);self.assertEqual(result.report["status"], "quarantined")

    def test_current_v2_migration_is_idempotent(self):
        original = self.migrate().save
        result = self.migrate({"save.json": canonical(original)})
        self.assertEqual(result.report["status"], "already_current")
        self.assertEqual(result.save, original)

    def test_same_legacy_input_has_stable_migration_id(self):
        a, b = self.migrate(), self.migrate()
        self.assertEqual(a.report, b.report);self.assertEqual(a.save, b.save)

    def test_current_v2_and_cfg_not_merged_silently(self):
        result = self.migrate({"save.json": canonical(new_save(self.rules, PLAYER)), **self.sources})
        self.assertIsNone(result.save);self.assertIn("mixed_current_and_legacy", result.report["errors"])

    def test_unknown_future_version_quarantined(self):
        result = self.migrate({"future.json": b'{"schema_version":3}'})
        self.assertIsNone(result.save);self.assertIn("unsupported_save_version", result.report["errors"])

    def test_corrupt_json_cfg_flags_and_duplicate_keys(self):
        cases = [{"old.json": b'{"schema_version":1,'}, {"old.json": b'{"schema_version":1,"schema_version":2}'}, {"old.cfg": b'[flags]\ndesert_stage_completed="true"'}, {"old.cfg": b'[flags]\ndesert_stage_completed=true\ndesert_stage_completed=false'}, {"old.cfg": b'[lobby]\ncharacter_id="unterminated'}, {"old.cfg": b'no section or assignment'}]
        for source in cases:
            with self.subTest(source=list(source)):
                result = self.migrate(source);self.assertIsNone(result.save);self.assertTrue(result.report["errors"])

    def test_conflicting_legacy_sources_quarantined(self):
        result = self.migrate({"one.cfg": b"[flags]\ndesert_stage_completed=true", "two.cfg": b"[flags]\ndesert_stage_completed=false"})
        self.assertIsNone(result.save);self.assertIn("conflicting_legacy_sources", result.report["errors"])

    def test_unknown_cfg_values_and_comments_are_not_executed(self):
        source = b'[unknown]\nvalue=Vector3(1, 2, 3)\ntext="a#b;c" ; comment\n[flags]\ndesert_stage_completed=false # comment\n'
        result = self.migrate({"old.cfg": source})
        self.assertIsNotNone(result.save)
        self.assertEqual(result.report["source_sha256"]["old.cfg"], hashlib.sha256(source).hexdigest())

    def test_source_names_cannot_escape_bundle(self):
        with self.assertRaises(ProgressionError): self.migrate({"../progress.cfg": b""})

    def test_backups_exact_and_sources_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            parent = Path(temp)
            originals = {name: parent / name for name in self.sources}
            for name, path in originals.items(): path.write_bytes(self.sources[name])
            result = self.migrate()
            target = write_migration_bundle(self.rules, self.sources, result, parent / "migration")
            self.assertEqual(inspect_migration_bundle(self.rules, target)["originals_verified"], 2)
            index = loads((target / "originals_index.json").read_bytes())
            for backup, name in index.items():
                self.assertEqual((target / "originals" / backup).read_bytes(), self.sources[name])
                self.assertEqual(originals[name].read_bytes(), self.sources[name])

    def test_existing_destination_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "existing";path.mkdir();(path / "keep").write_bytes(b"original")
            with self.assertRaises(FileExistsError): write_migration_bundle(self.rules, self.sources, self.migrate(), path)
            self.assertEqual((path / "keep").read_bytes(), b"original")

    def test_corrupt_save_keeps_backup_without_new_progress(self):
        with tempfile.TemporaryDirectory() as temp:
            source = {"bad.json": b'{"schema_version":2,'}
            target = write_migration_bundle(self.rules, source, self.migrate(source), Path(temp) / "quarantine")
            self.assertFalse((target / "save.v2.json").exists())
            self.assertEqual((target / "originals/source_01.bin").read_bytes(), source["bad.json"])
            self.assertEqual(inspect_migration_bundle(self.rules, target)["status"], "quarantined")

    def test_corrupted_backup_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            target = write_migration_bundle(self.rules, self.sources, self.migrate(), Path(temp) / "migration")
            (target / "originals/source_01.bin").write_bytes(b"changed")
            with self.assertRaises(ProgressionError) as caught: inspect_migration_bundle(self.rules, target)
            self.assertEqual(caught.exception.code, "backup_checksum_mismatch")

    def test_mismatched_backup_input_rejected_before_creating_output(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "migration"
            with self.assertRaises(ProgressionError): write_migration_bundle(self.rules, {"wrong.cfg": b""}, self.migrate(), target)
            self.assertFalse(target.exists())

    def test_interrupted_output_is_not_complete(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "migration"
            with patch("tools.progression.storage.os.link", side_effect=OSError("filesystem unavailable")):
                with self.assertRaises(OSError): write_migration_bundle(self.rules, self.sources, self.migrate(), target)
            self.assertFalse((target / "status.complete").exists())
            with self.assertRaises(ProgressionError): inspect_migration_bundle(self.rules, target)

    def test_atomic_file_creation_never_replaces_existing_file(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "save.json";target.write_bytes(b"original")
            with self.assertRaises(FileExistsError): write_new_file(target, b"new")
            self.assertEqual(target.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()
