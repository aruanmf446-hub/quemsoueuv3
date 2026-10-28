"""Casos adversariais para o verificador; não executam nem modificam o jogo."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from common import ROOT, load_json, resource_path
from inspect_assets import FBX_MAGIC, BinaryFBX, inspect_fbx, inspect_glb, inspect_obj
from validate import (Report, PHASE_IDS, validate_schema, check_file_references,
                      check_protected_files, check_story, check_player_state, check_manifest)


def read(relative):
    return load_json(ROOT / relative)


class PlanningRules(unittest.TestCase):
    def setUp(self):
        self.registry = read("data/planning/character_registry.json")
        self.campaign = read("data/planning/desert_campaign.json")
        self.phases = [read(f"data/planning/desert/phase_{i:02d}.json") for i in range(1, 11)]
        self.runtime = read("data/characters.json")
        self.enemies = read("data/desert_enemies.json")
        self.resources = read("data/planning/resource_requirements.json")
        self.dependencies = read("data/planning/implementation_dependencies.json")

    def result(self):
        r = Report()
        check_story(self.registry, self.campaign, self.phases, self.runtime,
                    self.enemies, self.resources, self.dependencies, r)
        return r

    def rejected(self, code):
        self.assertIn(code, {e["code"] for e in self.result().errors})

    def test_consistent_proposal(self):
        self.assertEqual(self.result().errors, [])

    def test_duplicate_character(self):
        self.registry["entries"].append(copy.deepcopy(self.registry["entries"][0]))
        self.rejected("duplicate_id")

    def test_changed_existing_identifier(self):
        self.registry["entries"][0]["id"] = "another_cowboy"
        self.rejected("catalog_compatibility")

    def test_duplicate_runtime_identifier(self):
        self.runtime["unlockable"].append(copy.deepcopy(self.runtime["playable"][0]))
        self.rejected("duplicate_id")

    def test_enemy_cannot_be_skin(self):
        next(e for e in self.registry["entries"] if e["id"] == "cactus")["lobby"]["equippable"] = True
        self.rejected("hostile_playable")

    def test_boss_cannot_be_skin(self):
        next(e for e in self.registry["entries"] if e["id"] == "malagueta")["roles"].append("lobby_playable")
        self.rejected("hostile_playable")

    def test_no_initial_fuego_unlock(self):
        next(e for e in self.registry["entries"] if e["id"] == "el_fuego")["lobby"]["initially_unlocked"] = True
        self.rejected("fuego_unlock")

    def test_story_does_not_require_lobby_unlock(self):
        next(e for e in self.registry["entries"] if e["id"] == "el_fuego")["story"]["available_before_lobby_unlock"] = False
        self.rejected("fuego_story")

    def test_every_phase_uses_fuego(self):
        self.phases[4]["protagonist_id"] = "cowboy"
        self.rejected("wrong_protagonist")

    def test_no_skipping_prerequisites(self):
        self.phases[8]["prerequisite_phase_ids"] = []
        self.rejected("phase_prerequisites")

    def test_no_early_campaign_reward(self):
        self.phases[0]["future_rewards"].append({"type": "achievement", "target_id": "desert_campaign_completed", "status": "future"})
        self.rejected("reward_rule")

    def test_final_boss_is_required(self):
        self.phases[-1]["completion"]["required_boss_id"] = None
        self.rejected("final_boss")

    def test_no_automatic_legacy_grant(self):
        self.campaign["legacy_compatibility"]["automatic_legacy_grant"] = True
        self.rejected("unsafe_legacy_grant")

    def test_duplicate_phase(self):
        self.phases[-1]["id"] = self.phases[0]["id"]
        self.rejected("duplicate_id")

    def test_duplicate_checkpoint(self):
        self.phases[3]["checkpoints_planned"][0]["id"] = self.phases[0]["checkpoints_planned"][0]["id"]
        self.rejected("duplicate_id")

    def test_missing_resource_registry(self):
        self.phases[2]["resources_required"].append("missing_art")
        self.rejected("unknown_resource")

    def test_missing_dependency_registry(self):
        self.phases[2]["implementation_dependencies"].append("missing_system")
        self.rejected("unknown_dependency")

    def test_future_scene_not_claimed_implemented(self):
        self.phases[1]["existing_runtime"]["scene"] = "res://scenes/desert/phase_01.tscn"
        self.rejected("runtime_claim")

    def test_incomplete_and_invalid_data(self):
        schema = read("data/contracts/desert_phase.schema.json")
        cases = []
        missing = copy.deepcopy(self.phases[0]); del missing["narrative_description"]; cases.append(missing)
        wrong_type = copy.deepcopy(self.phases[0]); wrong_type["order"] = "1"; cases.append(wrong_type)
        empty = copy.deepcopy(self.phases[0]); empty["checkpoints_planned"] = []; cases.append(empty)
        invented_money = copy.deepcopy(self.phases[0]); invented_money["future_rewards"][0]["amount"] = 100; cases.append(invented_money)
        for case in cases:
            with self.subTest(case=case):
                r = Report(); self.assertFalse(validate_schema(case, schema, "phase", r))


class ProgressRules(unittest.TestCase):
    def setUp(self):
        self.registry = read("data/planning/character_registry.json")
        self.initial = read("data/contracts/examples/player_state.initial.json")
        self.completed = read("data/contracts/examples/player_state.completed.json")

    def check(self, state):
        r = Report(); check_player_state(state, self.registry, r); return r

    def test_valid_initial_and_completed(self):
        self.assertEqual(self.check(self.initial).errors, [])
        self.assertEqual(self.check(self.completed).errors, [])

    def test_phase_one_does_not_award_campaign(self):
        state = self.completed
        state["phase_completions"] = state["phase_completions"][:1]
        state["campaigns"][0]["completed_phase_ids"] = PHASE_IDS[:1]
        self.assertIn("achievement_evidence", {e["code"] for e in self.check(state).errors})

    def test_phase_ten_alone_does_not_award_campaign(self):
        state = self.completed
        state["phase_completions"] = state["phase_completions"][-1:]
        state["campaigns"][0]["completed_phase_ids"] = PHASE_IDS[-1:]
        errors = {e["code"] for e in self.check(state).errors}
        self.assertIn("completion_gap", errors); self.assertIn("achievement_evidence", errors)

    def test_locked_equipment_rejected(self):
        self.initial["equipped_character_id"] = "el_fuego"
        self.assertIn("equipped_locked", {e["code"] for e in self.check(self.initial).errors})

    def test_enemy_unlock_rejected(self):
        self.initial["character_unlocks"][0]["character_id"] = "cactus"
        self.assertIn("hostile_unlock", {e["code"] for e in self.check(self.initial).errors})

    def test_duplicate_completion_rejected(self):
        self.completed["phase_completions"].append(copy.deepcopy(self.completed["phase_completions"][0]))
        self.assertIn("duplicate_id", {e["code"] for e in self.check(self.completed).errors})

    def test_missing_initial_character_rejected(self):
        self.initial["character_unlocks"].pop()
        self.assertIn("unlock_set", {e["code"] for e in self.check(self.initial).errors})

    def test_client_cannot_choose_user_id(self):
        op = {"request_id": "00000000-0000-4000-8000-000000000001", "type": "equip_character", "character_id": "cowboy", "user_id": self.initial["profile"]["user_id"]}
        r = Report(); self.assertFalse(validate_schema(op, read("data/contracts/progress_operation.schema.json"), "operation", r))

    def test_invalid_uuid_and_unverified_completion_rejected(self):
        for field, value in [("completion_id", "not-a-uuid"), ("verified", False)]:
            state = copy.deepcopy(self.completed); state["phase_completions"][0][field] = value
            r = Report(); self.assertFalse(validate_schema(state, read("data/contracts/player_state.schema.json"), "state", r))


class FileIntegrity(unittest.TestCase):
    def test_missing_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = Report(); check_file_references(Path(tmp), {"model": "res://missing.fbx"}, r, "fixture")
            self.assertEqual(r.errors[0]["code"], "missing_file")

    def test_path_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            for uri in ("res://../escape", "res://a/../../escape", "res://a\\escape"):
                with self.subTest(uri=uri), self.assertRaises(ValueError): resource_path(tmp, uri)

    def test_protected_source_tampering(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / "scene.tscn").write_text("modified")
            r = Report(); check_protected_files(root, {"protected_files": {"scene.tscn": hashlib.sha256(b"original").hexdigest()}}, r)
            self.assertEqual(r.errors[0]["code"], "protected_changed")

    def test_duplicate_json_keys_and_nonfinite_numbers(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "data.json"
            for text in ('{"id":"a","id":"b"}', '{"height":NaN}'):
                path.write_text(text)
                with self.assertRaises(ValueError): load_json(path)

    def test_manifest_corruption_and_duplicate_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / "asset.fbx").write_bytes(b"actual")
            asset = {"asset_id": "source:asset.fbx", "source_path": "res://asset.fbx", "character_id": None, "realm_id": None, "format": "fbx", "size_bytes": 6, "sha256": "0" * 64, "proposed_object_key": "sources/v1/" + "0" * 64 + "/asset.fbx", "publication_status": "not_uploaded", "runtime_ready": False}
            r = Report(); check_manifest(root, {"assets": [asset, copy.deepcopy(asset)]}, {"files": [{"path": "res://asset.fbx", "character_id": None, "sha256": "0" * 64}]}, r)
            codes = {e["code"] for e in r.errors}; self.assertIn("asset_integrity", codes); self.assertIn("duplicate_id", codes)


class ModelInspection(unittest.TestCase):
    def test_actual_base_and_animation_only_fbx(self):
        base = inspect_fbx(ROOT / "assets/characters/malagueta/ataque de baixo pra cima.fbx")
        clip = inspect_fbx(ROOT / "assets/characters/malagueta/caminhar.fbx")
        self.assertGreater(base["mesh_count"], 0); self.assertGreater(base["skeleton_evidence"]["skin_deformers"], 0)
        self.assertEqual(clip["mesh_count"], 0); self.assertGreater(clip["animation_curve_count"], 0)
        self.assertEqual(base["skeleton_evidence"]["hierarchy_sha256"], clip["skeleton_evidence"]["hierarchy_sha256"])
        self.assertIn("mixamorig:Hips", base["skeleton_evidence"]["bone_names"])
        self.assertNotIn("mixamo.com.tak", base["texture_references"])

    def test_corrupt_binary_fbx(self):
        data = FBX_MAGIC + struct.pack("<I", 7700) + struct.pack("<QQQB", 99999, 0, 0, 1) + b"x"
        with self.assertRaises(ValueError): BinaryFBX(data).roots()

    def test_corrupt_glb(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.glb"; path.write_bytes(b"glTF")
            with self.assertRaises(ValueError): inspect_glb(path)

    def test_obj_is_static_and_counts_polygons(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "quad.obj"
            path.write_text("v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n")
            result = inspect_obj(path)
            self.assertEqual(result["vertex_count"], 4); self.assertEqual(result["triangulated_face_estimate"], 2)
            self.assertIn("não armazena", result["skeleton_evidence"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
