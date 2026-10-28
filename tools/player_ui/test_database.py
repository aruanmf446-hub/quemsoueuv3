"""Integração SQL REAL em PostgreSQL descartável, sem acesso a serviços remotos.

QSE_PG_BIN deve apontar ao diretório de binários PostgreSQL 17 (initdb/pg_ctl/psql).
O teste cria um cluster em /tmp, sem TCP, e o remove ao terminar.
Auth/Realtime têm só a superfície SQL local; não são testes de Auth/WebSocket reais.
"""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid
from jsonschema import Draft202012Validator, FormatChecker

from tools.progression.engine import validate_state
from tools.progression.rules import Rules

ROOT = Path(__file__).resolve().parents[2]


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


class DatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        binary = os.environ.get("QSE_PG_BIN", "")
        if not binary:
            raise unittest.SkipTest("QSE_PG_BIN ausente; nenhum banco remoto será usado")
        cls.binary = Path(binary).resolve()
        for name in ("initdb", "pg_ctl", "psql"):
            if not (cls.binary / name).is_file():
                raise RuntimeError(f"Binário PostgreSQL ausente: {name}")
        cls.temp = tempfile.TemporaryDirectory(prefix="qse-ui03-pg-", dir="/tmp")
        cls.base = Path(cls.temp.name)
        cls.cluster = cls.base / "cluster"
        cls.run_binary("initdb", "-D", str(cls.cluster), "-A", "trust", "--no-locale", "-E", "UTF8")
        cls.run_binary("pg_ctl", "-D", str(cls.cluster), "-l", str(cls.base / "postgres.log"),
                       "-o", f"-k {cls.base} -p 55439 -c listen_addresses=''", "start")
        cls.addClassCleanup(cls.shutdown)
        cls.sql((ROOT / "supabase/tests/bootstrap_local.sql").read_text())
        for file in sorted((ROOT / "supabase/migrations").glob("*.sql")):
            cls.sql(file.read_text())
        cls.rules = Rules(ROOT)
        cls.contracts = json.loads((ROOT / "data/ui/services.schema.json").read_text())

    @classmethod
    def shutdown(cls):
        cls.run_binary("pg_ctl", "-D", str(cls.cluster), "-m", "fast", "stop")
        cls.temp.cleanup()

    @classmethod
    def run_binary(cls, name, *args):
        result = subprocess.run([str(cls.binary / name), *args], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout

    @classmethod
    def sql(cls, sql, owner=None, role=None, error=False):
        prefix = ""
        if role:
            assert role in ("anon", "authenticated", "service_role")
            prefix += f"set role {role};"
        if owner:
            prefix += f"set request.jwt.claim.sub={literal(owner)};"
        process = subprocess.run([str(cls.binary / "psql"), "-X", "-q", "-t", "-A",
            "-h", str(cls.base), "-p", "55439", "-d", "postgres", "-v", "ON_ERROR_STOP=1"],
            input=prefix + sql, text=True, capture_output=True)
        if error:
            if not process.returncode:
                raise AssertionError("SQL deveria ter sido recusado")
            return process.stderr
        if process.returncode:
            raise AssertionError(process.stderr)
        lines = process.stdout.strip().splitlines()
        if not lines:
            return None
        try:
            return json.loads(lines[-1])
        except json.JSONDecodeError:
            return lines[-1]

    def player(self, nickname=None):
        owner = str(uuid.uuid4())
        self.sql(f"insert into auth.users values({literal(owner)},'fixture@example.invalid');")
        self.rpc(owner, "qse_profile_self")
        if nickname:
            self.rpc(owner, "qse_profile_update", literal(nickname))
        return owner

    def rpc(self, owner, name, args=""):
        result = self.sql(f"select public.{name}({args});", owner, "authenticated")
        definitions={"qse_profile_self":"profile","qse_profile_update":"profile","qse_profile_public":"public_profile",
            "qse_find_players":"search","qse_friends":"friends","qse_wallet":"wallet","qse_wallet_history":"history",
            "qse_account_preferences":"account_preferences","qse_friend_action":"friend_action"}
        if name in definitions and result and "error" not in result:
            schema={"$ref":"#/$defs/"+definitions[name],"$defs":self.contracts["$defs"]}
            Draft202012Validator(schema,format_checker=FormatChecker()).validate(result)
        return result

    def command(self, owner, operation, *, request_id=None, expected=None):
        if expected is None:
            expected = self.rpc(owner, "qse_progression_snapshot")["revision"]
        request = {"protocol_version": 2, "rules_version": "desert_progression_2.0.0",
            "request_id": request_id or str(uuid.uuid4()), "expected_revision": expected, "operation": operation}
        result = self.rpc(owner, "qse_progression_command", literal(json.dumps(request)) + "::jsonb")
        if "snapshot" in result:
            validate_state(self.rules, result["snapshot"])
        return result

    def action(self, owner, action, target, key=None):
        return self.rpc(owner, "qse_friend_action", ",".join(map(literal, (action,target,key or uuid.uuid4()))))

    def evidence(self, owner, phase, boss=None):
        evidence, attempt = str(uuid.uuid4()), str(uuid.uuid4())
        boss_sql = "null" if boss is None else literal(boss)
        self.sql(f"insert into qse_v3.completion_evidence values({literal(evidence)},{literal(owner)},"
            f"{literal(attempt)},{literal(phase)},true,{boss_sql},now()+interval '1 hour');")
        return {"type": "complete_phase", "phase_id": phase, "evidence_id": evidence, "attempt_id": attempt}

    def test_new_player_no_fabricated_stats_or_unlock(self):
        owner = self.player()
        state = self.rpc(owner, "qse_progression_snapshot")
        validate_state(self.rules, state)
        self.assertEqual(state["completed_phase_ids"], [])
        self.assertNotIn("el_fuego", state["unlocked_character_ids"])
        profile = self.rpc(owner, "qse_profile_self")
        self.assertIsNone(profile["level"])
        self.assertIsNone(profile["experience"])
        self.assertEqual(profile["statistics"], {})

    def test_wallet_zero_comes_from_database(self):
        wallet = self.rpc(self.player(), "qse_wallet")
        self.assertEqual((wallet["coins"], wallet["gems"]), ("0", "0"))
        self.assertEqual(wallet["transactions"], [])

    def test_anonymous_denied(self):
        self.assertIn("permission denied", self.sql("select public.qse_profile_self();", role="anon", error=True))

    def test_authenticated_without_subject_denied(self):
        self.assertIn("not_authenticated", self.sql("select public.qse_wallet();", role="authenticated", error=True))

    def test_private_rows_isolated_between_players(self):
        alice, bob = self.player(), self.player()
        for table in ("player_profiles", "account_preferences", "wallets", "player_loadout", "campaign_progress", "character_unlocks"):
            result = self.sql(f"select count(*) from qse_v3.{table} where user_id={literal(bob)};", alice, "authenticated")
            self.assertEqual(result, 0, table)

    def test_direct_writes_to_authority_denied(self):
        owner = self.player()
        for sql in (
            "update qse_v3.wallets set coins=9999;", "update qse_v3.campaign_progress set revision=99;",
            "insert into qse_v3.player_achievements values(auth.uid(),'desert_campaign_completed',now());",
            "update qse_v3.player_loadout set equipped_character_id='el_fuego';",
            "insert into qse_v3.friend_requests values(auth.uid(),auth.uid(),now());",
            "select qse_v3.ensure_player(auth.uid());", "select * from qse_v3.completion_evidence;",
            "select qse_v3.post_wallet_entry(auth.uid(),gen_random_uuid(),'coins',100,'forged');"):
            self.assertIn("permission denied", self.sql(sql,owner,"authenticated",error=True))

    def test_nickname_validation(self):
        owner = self.player()
        for nickname in ("a", "x"*25, "abc\nxyz"):
            self.assertEqual(self.rpc(owner, "qse_profile_update", literal(nickname))["error"], "invalid_nickname")
        self.assertEqual(self.rpc(owner,"qse_profile_update",literal("  Lua Azul  "))["nickname"], "Lua Azul")

    def test_search_minimum_and_no_self(self):
        owner = self.player("FixtureBusca")
        self.assertEqual(self.rpc(owner,"qse_find_players",literal("a"))["error"],"invalid_search")
        self.assertEqual(self.rpc(owner,"qse_find_players",literal("FixtureBusca"))["players"],[])

    def test_public_profile_contains_no_private_stats(self):
        alice, bob = self.player(), self.player("FixturePublico")
        profile = self.rpc(bob,"qse_profile_self")
        public = self.rpc(alice,"qse_profile_public",literal(profile["public_id"]))
        self.assertEqual(set(public), {"user_id","public_id","nickname","level","equipped_character_id"})

    def test_discovery_preferences_are_enforced(self):
        alice, bob = self.player(), self.player("FixturePrivado")
        public_id = self.rpc(bob,"qse_profile_self")["public_id"]
        self.rpc(bob,"qse_account_preferences","false")
        self.assertEqual(self.rpc(alice,"qse_profile_public",literal(public_id)),{})
        self.assertEqual(self.rpc(alice,"qse_find_players",literal("FixturePrivado"))["players"],[])
        self.assertEqual(self.action(alice,"send",bob)["error"],"player_not_found")

    def test_friend_request_sender_cannot_accept(self):
        alice, bob = self.player(),self.player()
        self.action(alice,"send",bob)
        self.assertEqual(self.action(alice,"accept",bob)["error"],"request_not_found")
        self.assertEqual(len(self.rpc(bob,"qse_friends")["incoming"]),1)

    def test_self_friend_rejected(self):
        owner = self.player()
        self.assertEqual(self.action(owner,"send",owner)["error"],"invalid_friend_request")

    def test_accept_remove_and_duplicate_request(self):
        alice, bob = self.player(),self.player()
        key = str(uuid.uuid4())
        first = self.action(alice,"send",bob,key)
        self.assertEqual(self.action(alice,"send",bob,key),first)
        self.assertEqual(len(self.rpc(bob,"qse_friends")["incoming"]),1)
        self.action(bob,"accept",alice)
        self.assertEqual(len(self.rpc(alice,"qse_friends")["friends"]),1)
        self.action(alice,"remove",bob)
        self.assertEqual(self.rpc(bob,"qse_friends")["friends"],[])

    def test_friend_idempotency_payload_conflict(self):
        alice,bob = self.player(),self.player()
        key = str(uuid.uuid4());self.action(alice,"send",bob,key)
        self.assertEqual(self.action(alice,"cancel",bob,key)["error"],"idempotency_conflict")

    def test_cross_requests_do_not_implicitly_accept(self):
        alice,bob=self.player(),self.player()
        self.action(alice,"send",bob)
        self.assertEqual(self.action(bob,"send",alice)["error"],"incoming_request_exists")

    def test_decline_and_cancel(self):
        alice,bob=self.player(),self.player()
        self.action(alice,"send",bob);self.action(bob,"decline",alice)
        self.assertEqual(self.rpc(alice,"qse_friends")["outgoing"],[])
        self.action(alice,"send",bob);self.action(alice,"cancel",bob)
        self.assertEqual(self.rpc(bob,"qse_friends")["incoming"],[])

    def test_wallet_ledger_idempotency_and_isolation(self):
        alice,bob=self.player(),self.player();key=str(uuid.uuid4())
        query=f"select qse_v3.post_wallet_entry({literal(alice)},{literal(key)},'coins',25,'fixture_test');"
        first=self.sql(query,role="service_role")
        self.assertEqual(self.sql(query,role="service_role"),first)
        self.assertEqual(self.rpc(alice,"qse_wallet")["coins"],"25")
        self.assertEqual(self.rpc(bob,"qse_wallet")["transactions"],[])
        self.assertIn("idempotency_conflict",self.sql(query.replace(",25,",",30,"),role="service_role",error=True))

    def test_wallet_no_overdraft_or_zero_mutation(self):
        owner=self.player()
        for amount in (-1,0):
            self.sql(f"select qse_v3.post_wallet_entry({literal(owner)},gen_random_uuid(),'coins',{amount},'fixture_test');",role="service_role",error=True)
        self.assertEqual(self.rpc(owner,"qse_wallet")["coins"],"0")

    def test_wallet_concurrent_same_idempotency_key(self):
        owner=self.player();key=str(uuid.uuid4())
        query=f"select qse_v3.post_wallet_entry({literal(owner)},{literal(key)},'gems',7,'fixture_test');"
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:self.sql(query,role="service_role"),range(2)))
        self.assertEqual(results[0],results[1])
        self.assertEqual(self.rpc(owner,"qse_wallet")["gems"],"7")

    def test_wallet_history_cursor(self):
        owner=self.player()
        for _ in range(23):
            self.sql(f"select qse_v3.post_wallet_entry({literal(owner)},gen_random_uuid(),'coins',1,'fixture_page');",role="service_role")
        wallet=self.rpc(owner,"qse_wallet");self.assertEqual(len(wallet["transactions"]),20)
        more=self.rpc(owner,"qse_wallet_history",literal(wallet["next_cursor"]))
        self.assertEqual(len(more["transactions"]),3)
        self.assertFalse({x["transaction_id"] for x in wallet["transactions"]} & {x["transaction_id"] for x in more["transactions"]})

    def test_locked_el_fuego_and_hostile_equipment_denied(self):
        owner=self.player()
        for character in ("el_fuego","cactus","malagueta"):
            self.assertEqual(self.command(owner,{"type":"equip_character","character_id":character})["status"],"rejected")

    def test_equipment_is_shared_by_own_and_public_profiles(self):
        owner,viewer=self.player(),self.player()
        result=self.command(owner,{"type":"equip_character","character_id":"lana"})
        self.assertEqual(result["status"],"applied")
        profile=self.rpc(owner,"qse_profile_self")
        self.assertEqual(profile["equipped_character_id"],"lana")
        self.assertEqual(self.rpc(viewer,"qse_profile_public",literal(profile["public_id"]))["equipped_character_id"],"lana")

    def test_skip_phase_rejected_and_protagonist_independent(self):
        owner=self.player()
        self.assertEqual(self.command(owner,{"type":"start_phase","phase_id":"desert_phase_10"})["code"],"phase_locked")
        self.assertEqual(self.command(owner,{"type":"start_phase","phase_id":"desert_phase_01"})["status"],"applied")
        self.assertNotIn("el_fuego",self.rpc(owner,"qse_progression_snapshot")["unlocked_character_ids"])

    def test_invalid_checkpoint_no_completion(self):
        owner=self.player();phase="desert_phase_01"
        self.command(owner,{"type":"start_phase","phase_id":phase})
        result=self.command(owner,{"type":"record_checkpoint","phase_id":phase,"checkpoint_id":"unknown"})
        self.assertEqual(result["code"],"invalid_checkpoint")
        result=self.command(owner,{"type":"record_checkpoint","phase_id":phase,"checkpoint_id":phase+"_checkpoint_01"})
        self.assertEqual(result["snapshot"]["completed_phase_ids"],[])

    def test_missing_proof_never_grants_completion(self):
        owner=self.player();phase="desert_phase_01"
        self.command(owner,{"type":"start_phase","phase_id":phase})
        result=self.command(owner,{"type":"complete_phase","phase_id":phase,"attempt_id":str(uuid.uuid4()),"evidence_id":str(uuid.uuid4())})
        self.assertEqual(result["code"],"verification_unavailable")

    def test_other_player_evidence_rejected(self):
        alice,bob=self.player(),self.player();phase="desert_phase_01"
        proof=self.evidence(bob,phase);self.command(alice,{"type":"start_phase","phase_id":phase})
        self.assertEqual(self.command(alice,proof)["code"],"verification_unavailable")

    def test_all_ten_only_then_unlock_and_duplicate_noop(self):
        owner=self.player()
        for number in range(1,11):
            phase=f"desert_phase_{number:02d}"
            self.command(owner,{"type":"start_phase","phase_id":phase})
            proof=self.evidence(owner,phase,"malagueta" if number==10 else None)
            result=self.command(owner,proof)
            self.assertEqual(result["status"],"applied")
            self.assertEqual("el_fuego" in result["snapshot"]["unlocked_character_ids"],number==10)
        self.assertEqual(self.command(owner,proof)["status"],"noop")
        self.assertEqual(self.command(owner,{"type":"equip_character","character_id":"el_fuego"})["status"],"applied")

    def test_request_replay_revision_conflict_and_concurrency(self):
        owner=self.player();key=str(uuid.uuid4());op={"type":"equip_character","character_id":"gus"}
        first=self.command(owner,op,request_id=key,expected=0)
        self.assertEqual(self.command(owner,op,request_id=key,expected=0),first)
        self.assertEqual(self.command(owner,{"type":"equip_character","character_id":"lana"},request_id=key,expected=0)["code"],"idempotency_conflict")
        self.assertEqual(self.command(owner,op,expected=0)["code"],"revision_conflict")

    def test_extra_grants_fields_rejected_and_float_revisions_accepted(self):
        owner=self.player()
        result=self.command(owner,{"type":"equip_character","character_id":"gus","grant":True})
        self.assertEqual(result["error"],"invalid_contract")
        result=self.command(owner,{"type":"equip_character","character_id":"gus"},expected=0.0)
        self.assertEqual(result["status"],"applied")

    def test_private_presence_scope_and_publication(self):
        alice,bob=self.player(),self.player();topic="friend-presence:"+bob
        allowed=lambda who,writing:self.sql(f"select qse_v3.presence_allowed({literal(topic)},{str(writing).lower()});",who,"authenticated")
        self.assertEqual(allowed(alice,False),"f")
        self.action(alice,"send",bob);self.action(bob,"accept",alice)
        self.assertEqual(allowed(alice,False),"t")
        self.assertEqual(allowed(alice,True),"f")
        self.assertEqual(allowed(bob,True),"t")
        self.action(alice,"remove",bob)
        self.assertEqual(allowed(alice,False),"f")

    def test_malagueta_proof_requires_boss_and_exit(self):
        owner=self.player()
        for exit_reached,boss in [("false", "'malagueta'"),("true","null")]:
            query=f"insert into qse_v3.completion_evidence values(gen_random_uuid(),{literal(owner)},gen_random_uuid(),'desert_phase_10',{exit_reached},{boss},now()+interval '1 hour');"
            self.assertIn("check constraint",self.sql(query,error=True))

    def test_expired_evidence_rejected(self):
        owner=self.player();phase="desert_phase_01"
        proof=self.evidence(owner,phase)
        self.sql(f"update qse_v3.completion_evidence set expires_at=now()-interval '1 minute' where evidence_id={literal(proof['evidence_id'])};")
        self.command(owner,{"type":"start_phase","phase_id":phase})
        self.assertEqual(self.command(owner,proof)["code"],"verification_unavailable")

    def test_authorization_guards_survive_broad_existing_realtime_policies(self):
        alice,bob=self.player(),self.player()
        self.sql("create policy fixture_open_read on realtime.messages for select to authenticated using(true);"
            "create policy fixture_open_write on realtime.messages for insert to authenticated with check(true);")
        try:
            topic="friend-presence:"+bob
            query=f"set realtime.topic={literal(topic)};insert into realtime.messages(extension,topic) values('presence',{literal(topic)});"
            self.assertIn("row-level security",self.sql(query,alice,"authenticated",error=True))
            self.sql(query,bob,"authenticated")
            read=f"set realtime.topic={literal(topic)};select count(*) from realtime.messages where topic={literal(topic)};"
            self.assertEqual(self.sql(read,alice,"authenticated"),0)
            self.action(alice,"send",bob);self.action(bob,"accept",alice)
            self.assertEqual(self.sql(read,alice,"authenticated"),1)
        finally:
            self.sql("drop policy fixture_open_read on realtime.messages;drop policy fixture_open_write on realtime.messages;")

    def test_concurrent_equipment_same_revision_only_one_applies(self):
        owner=self.player()
        def equip(character):
            return self.command(owner,{"type":"equip_character","character_id":character},expected=0)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(equip,["gus","lana"]))
        self.assertEqual(sorted(r["status"] for r in results),["applied","conflict"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
