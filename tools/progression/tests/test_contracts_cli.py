from copy import deepcopy
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from tools.progression.cli import check_reference
from tools.progression.codec import ROOT, ProgressionError, canonical, loads
from tools.progression.rules import Rules
from tools.progression.tests.helpers import rules, PLAYER


class ContractsAndCLITests(unittest.TestCase):
    def test_preserves_all_457_prior_files(self):
        result = check_reference()
        self.assertEqual(result["preserved_files"], 457)
        self.assertEqual(result["validated_save_examples"], 3)
        self.assertFalse(result["runtime_migration_applied"])

    def test_phase_nine_and_ten_cli_demo(self):
        process = subprocess.run([sys.executable, "-B", "-m", "tools.progression", "demo"], cwd=ROOT, capture_output=True)
        self.assertEqual(process.returncode, 0, process.stderr.decode())
        report = loads(process.stdout)
        self.assertEqual(len(report["phases"]), 10)
        self.assertFalse(report["phases"][8]["el_fuego_provisionally_unlocked"])
        self.assertTrue(report["phases"][9]["el_fuego_provisionally_unlocked"])
        self.assertFalse(report["definitive_online_unlocks_granted"])

    def test_cli_migration_creates_separate_bundle(self):
        with tempfile.TemporaryDirectory() as temp:
            parent = Path(temp);source = parent / "progress_dev.cfg";source.write_bytes(b"[flags]\ndesert_stage_completed=true\n")
            process = subprocess.run([sys.executable, "-B", "-m", "tools.progression", "migrate", "--player-id", PLAYER, "--source", str(source), "--out", str(parent / "new")], cwd=ROOT, capture_output=True)
            self.assertEqual(process.returncode, 0, process.stderr.decode())
            self.assertEqual(source.read_bytes(), b"[flags]\ndesert_stage_completed=true\n")
            self.assertTrue((parent / "new/status.complete").is_file())

    def test_cli_corrupt_save_returns_quarantine_exit_code(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "bad.json";source.write_bytes(b'{"schema_version":')
            process = subprocess.run([sys.executable, "-B", "-m", "tools.progression", "migrate", "--player-id", PLAYER, "--source", str(source)], cwd=ROOT, capture_output=True)
            self.assertEqual(process.returncode, 2)
            self.assertEqual(loads(process.stdout)["status"], "quarantined")
            self.assertEqual(list(Path(temp).iterdir()), [source])

    def test_bad_policy_cannot_authorize_legacy_flag(self):
        policy = loads((ROOT / "data/progression/migration_policy.v2.json").read_bytes())
        policy["flags_are_completion_evidence"] = True
        with self.assertRaises(ProgressionError): rules().contracts.validate("migration_policy", policy)

    def test_pinned_planning_change_rejected(self):
        config = loads((ROOT / "data/progression/rules.v2.json").read_bytes())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for relative in list(config["content_sources_sha256"]) + ["data/progression/rules.v2.json", "data/progression/contract.v2.schema.json"]:
                target = root / relative;target.parent.mkdir(parents=True, exist_ok=True);shutil.copyfile(ROOT / relative, target)
            target = root / "data/planning/desert/phase_01.json";target.write_bytes(target.read_bytes() + b"\n")
            with self.assertRaises(ProgressionError) as caught: Rules(root)
            self.assertEqual(caught.exception.code, "content_changed")

    def test_incomplete_or_unknown_character_classification_rejected(self):
        config = loads((ROOT / "data/progression/rules.v2.json").read_bytes())
        for change in (lambda c:c["characters"][0].update(classification="skin_enemy"), lambda c:c["classifications"].pop("minibosses")):
            value = deepcopy(config);change(value)
            with self.assertRaises(ProgressionError): rules().contracts.validate("rules", value)

    def test_checksum_canonicalization_handles_integer_float_equivalence(self):
        self.assertEqual(canonical({"schema_version": 2, "revision": 1}), canonical({"revision": 1.0, "schema_version": 2.0}))
        for value in (1.5, float("inf"), float("nan")):
            with self.assertRaises(ProgressionError): canonical({"revision": value})


if __name__ == "__main__":
    unittest.main()
