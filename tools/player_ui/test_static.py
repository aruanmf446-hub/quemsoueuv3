"""Contratos/referências locais. Não renderiza cenas nem executa GDScript."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
import re
from pglast import parse_sql

from jsonschema import Draft202012Validator, FormatChecker

from tools.player_ui.check import ROOT, check, load_json, scene_tree, validate_catalog, validate_routes
from tools.progression.migration import migrate_sources
from tools.progression.rules import Rules


class StaticTests(unittest.TestCase):
    def setUp(self):
        self.rules = load_json(ROOT / "data/progression/rules.v2.json")
        self.catalog = load_json(ROOT / "data/characters.json")
        self.routes = load_json(ROOT / "data/ui/routes.json")["routes"]
        self.schema = load_json(ROOT / "data/ui/services.schema.json")

    def contract(self, name):
        return Draft202012Validator({"$ref":f"#/$defs/{name}","$defs":self.schema["$defs"]},format_checker=FormatChecker())

    def test_all_resources_scripts_and_preservation(self):
        report=check()
        self.assertEqual(report["routes"],len(self.routes))
        self.assertEqual(report["previous_offline_deliveries_unchanged"],82)
        self.assertFalse(report["godot_executed"])

    def test_catalog_duplicate_id_rejected(self):
        self.catalog["playable"].append(deepcopy(self.catalog["playable"][0]))
        with self.assertRaises(ValueError):validate_catalog(self.catalog,self.rules)

    def test_legacy_flag_cannot_authorize_catalog(self):
        self.catalog["unlockable"][0]["unlock"]={"type":"flag","flag":"desert_stage_completed"}
        with self.assertRaises(ValueError):validate_catalog(self.catalog,self.rules)

    def test_hostile_characters_not_in_inventory(self):
        self.assertTrue({"cactus","malagueta"}.isdisjoint(entry["id"] for entry in self.catalog["playable"]+self.catalog["unlockable"]))

    def test_missing_route_scene_rejected(self):
        self.routes["profile"]="res://scenes/player/not_implemented.tscn"
        with self.assertRaises(ValueError):validate_routes(self.routes)

    def test_duplicate_route_scene_rejected(self):
        self.routes["profile"]=self.routes["wallet"]
        with self.assertRaises(ValueError):validate_routes(self.routes)

    def test_incomplete_navigation_rejected(self):
        del self.routes["friends"]
        with self.assertRaises(ValueError):validate_routes(self.routes)

    def test_inherited_nodes_for_all_screens(self):
        for route,path in self.routes.items():
            nodes=scene_tree(ROOT/path.removeprefix("res://"))
            self.assertIn("Margin/Column/Header/Back",nodes,route)
            self.assertIn("Margin/Column/StateBanner",nodes,route)

    def test_missing_scene_resource_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"bad.tscn"
            path.write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://missing.gd" id="1"]\n[node name="Bad" type="Control"]\n')
            with self.assertRaises(ValueError):scene_tree(path)

    def test_duplicate_json_keys_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"bad.json";path.write_text('{"friends":1,"friends":2}')
            with self.assertRaises(ValueError):load_json(path)

    def test_only_existing_phase_has_runtime_scene(self):
        scenes=[]
        for number in range(1,11):
            phase=load_json(ROOT/f"data/planning/desert/phase_{number:02d}.json")
            path=phase.get("existing_runtime",{}).get("scene")
            if path is not None:
                self.assertTrue((ROOT/path.removeprefix("res://")).is_file())
                scenes.append(phase["id"])
        self.assertEqual(scenes,["desert_phase_01"])

    def test_catalog_ids_and_checkpoint_ids_match_sql_seed(self):
        source=(ROOT/"supabase/migrations/202610280001_player_foundation.sql").read_text()
        for entry in self.catalog["playable"]+self.catalog["unlockable"]:
            self.assertIn("'"+entry["id"]+"'",source)
        self.assertEqual([phase["order"] for phase in self.rules["phases"]],list(range(1,11)))

    def test_wallet_contract_rejects_client_grant_fields(self):
        value={"coins":"0","gems":"0","revision":"0","transactions":[],"next_cursor":None}
        self.contract("wallet").validate(value)
        value["grant_coins"]=100
        self.assertFalse(self.contract("wallet").is_valid(value))

    def test_wallet_negative_balance_rejected(self):
        value={"coins":"-1","gems":"0","revision":"0","transactions":[],"next_cursor":None}
        self.assertFalse(self.contract("wallet").is_valid(value))

    def test_public_profile_contract_rejects_private_fields(self):
        value={"user_id":"00000000-0000-4000-8000-000000000001","public_id":"QSE-"+"a"*32,
            "nickname":"Fixture","level":None,"equipped_character_id":"cowboy"}
        self.contract("public_profile").validate(value)
        for private in ["email","wallet","experience","completed_phase_ids"]:
            leaked={**value,private:"private"}
            self.assertFalse(self.contract("public_profile").is_valid(leaked),private)

    def test_public_profile_cannot_show_enemy_equipment(self):
        value={"user_id":"00000000-0000-4000-8000-000000000001","public_id":"QSE-"+"a"*32,
            "nickname":"Fixture","level":None,"equipped_character_id":"cactus"}
        self.assertFalse(self.contract("public_profile").is_valid(value))

    def test_local_migration_legacy_flags_never_unlock(self):
        owner="00000000-0000-4000-8000-000000000001"
        result=migrate_sources(Rules(ROOT),{"progress_dev.cfg":b"[flags]\ndesert_stage_completed=true\ndesert_campaign_completed=true\n"},owner)
        self.assertNotIn("el_fuego",result.save["local_state"]["unlocked_character_ids"])
        self.assertEqual(result.save["local_state"]["completed_phase_ids"],[])

    def test_supabase_configuration_contains_only_publishable_keys(self):
        config=load_json(ROOT/"data/backend/client.json")
        entries=[config]+[config["connections"][name] for name in ("chat","catalog")]
        for entry in entries:
            key=entry.get("publishable_key","")
            self.assertTrue(key=="" or key.startswith("sb_publishable_"),"só chave publicável no Git")
            self.assertRegex(entry.get("url",""),r"^(https://[a-z0-9]{20}\.supabase\.co)?$")
        self.assertEqual(len({e["url"] for e in entries if e.get("url")}),len([e for e in entries if e.get("url")]),"três projetos distintos")
        self.assertFalse(config["persist_session"])

    def test_rpc_names_and_parameter_names_match_sql(self):
        endpoints=load_json(ROOT/"data/ui/api.json")["endpoints"]
        functions={}
        for path in (ROOT/"supabase/migrations").glob("*.sql"):
            for raw in parse_sql(path.read_text()):
                node=raw.stmt
                if type(node).__name__=="CreateFunctionStmt" and node.funcname[0].sval=="public":
                    functions[node.funcname[-1].sval]=[param.name for param in node.parameters or ()]
        self.assertEqual(set(functions),set(endpoints))
        for name,endpoint in endpoints.items():self.assertEqual(functions[name],endpoint["parameters"],name)
        calls=set()
        for path in (ROOT/"scripts/services").glob("*.gd"):
            calls.update(re.findall(r'(?:rpc|load_rpc)\("(qse_\w+)"',path.read_text()))
        self.assertEqual(calls,set(endpoints))

    def test_api_contract_definition_paths_resolve(self):
        for endpoint in load_json(ROOT/"data/ui/api.json")["endpoints"].values():
            if endpoint["response_schema"]:
                path=ROOT/"data/ui"/endpoint["response_schema"]
                self.assertIn(endpoint["response_definition"],load_json(path)["$defs"])

    def test_exports_include_non_resource_json_data(self):
        presets=(ROOT/"export_presets.cfg").read_text()
        self.assertEqual(presets.count('include_filter="*.json"'),2)
        self.assertIn('permissions/internet=true',presets)
        self.assertIn('window/handheld/orientation=0',(ROOT/'project.godot').read_text())


if __name__=="__main__":unittest.main(verbosity=2)
