from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from dataclasses import replace
import unittest

from tools.progression.codec import ProgressionError, canonical, seal
from tools.progression.engine import new_state
from tools.progression.server_reference import ServerReference, VerifiedCompletion
from tools.progression.saves import new_save, load_save
from tools.progression.sync import ClientSession
from tools.progression.tests.helpers import rules, PLAYER, OTHER, uid, request, verified_fixture, FixtureChannel


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.rules = rules()
        self.server = ServerReference(self.rules, PLAYER, completion_verifier=verified_fixture)

    def send(self, number, operation, server=None):
        server = server or self.server
        return server.handle(PLAYER, request(server, number, operation))

    def advance(self, count):
        for i, phase in enumerate(self.rules.phases[:count], 1):
            self.assertEqual(self.send(i * 10, {"type": "start_phase", "phase_id": phase.id})["status"], "applied")
            self.assertEqual(self.send(i * 10 + 1, {"type": "complete_phase", "phase_id": phase.id, "attempt_id": uid(1000 + i), "evidence_id": uid(2000 + i)})["status"], "applied")

    def test_default_server_rejects_completion_without_verifier(self):
        server = ServerReference(self.rules, PLAYER)
        self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"}, server)
        before = server.snapshot()
        result = self.send(2, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)}, server)
        self.assertEqual(result["code"], "verification_required");self.assertEqual(server.snapshot(), before)

    def test_nine_verified_phases_still_locked(self):
        self.advance(9)
        self.assertNotIn("el_fuego", self.server.snapshot()["unlocked_character_ids"])
        self.assertEqual(self.server.snapshot()["achievement_ids"], [])

    def test_ten_verified_phases_award_atomically(self):
        self.advance(10)
        state = self.server.snapshot()
        self.assertEqual(state["achievement_ids"], ["desert_campaign_completed"])
        self.assertEqual(state["unlocked_character_ids"].count("el_fuego"), 1)
        self.assertEqual(self.send(999, {"type": "equip_character", "character_id": "el_fuego"})["status"], "applied")

    def test_skip_is_rejected_without_consulting_verifier(self):
        calls = []
        self.server._verifier = lambda req, state: calls.append(req)
        result = self.send(1, {"type": "complete_phase", "phase_id": "desert_phase_10", "attempt_id": uid(90), "evidence_id": uid(91)})
        self.assertEqual(result["code"], "phase_sequence");self.assertEqual(calls, [])

    def test_client_cannot_send_unlock_or_verified_fields(self):
        for extra in ({"verified": True}, {"grant_character_id": "el_fuego"}, {"user_id": OTHER}, {"defeated_boss_id": "malagueta"}):
            operation = {"type": "equip_character", "character_id": "el_fuego", **extra}
            with self.assertRaises(ProgressionError): self.send(1, operation)
        self.assertEqual(self.server.snapshot()["revision"], 0)

    def test_identity_mismatch_does_not_disclose_state(self):
        with self.assertRaises(ProgressionError) as caught:
            self.server.handle(OTHER, request(self.server, 1, {"type": "equip_character", "character_id": "cowboy"}))
        self.assertEqual(caught.exception.code, "player_mismatch")

    def test_locked_and_hostile_equipment_rejected(self):
        for i, id in enumerate(("el_fuego", "cactus", "malagueta"), 1):
            self.assertEqual(self.send(i, {"type": "equip_character", "character_id": id})["code"], "character_locked")

    def test_fuego_protagonist_access_does_not_require_lobby_unlock(self):
        result = self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        self.assertEqual(result["status"], "applied")
        self.assertNotIn("el_fuego", result["snapshot"]["unlocked_character_ids"])

    def test_same_request_retry_returns_same_result(self):
        req = request(self.server, 1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        first = self.server.handle(PLAYER, req)
        self.assertEqual(self.server.handle(PLAYER, req), first)
        self.assertEqual(self.server.snapshot()["revision"], 1)

    def test_same_id_other_payload_or_revision_rejected(self):
        req = request(self.server, 1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        self.server.handle(PLAYER, req)
        changed = deepcopy(req);changed["expected_revision"] += 1
        self.assertEqual(self.server.handle(PLAYER, changed)["code"], "idempotency_conflict")
        changed = deepcopy(req);changed["operation"] = {"type": "equip_character", "character_id": "michelly"}
        self.assertEqual(self.server.handle(PLAYER, changed)["code"], "idempotency_conflict")

    def test_stale_revision_is_conflict_without_mutation(self):
        self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        before = self.server.snapshot()
        result = self.server.handle(PLAYER, request(self.server, 2, {"type": "equip_character", "character_id": "michelly"}, revision=0))
        self.assertEqual(result["status"], "conflict");self.assertEqual(self.server.snapshot(), before)

    def test_concurrent_retries_apply_once(self):
        self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        req = request(self.server, 2, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)})
        with ThreadPoolExecutor(max_workers=4) as pool:
            responses = list(pool.map(lambda _:self.server.handle(PLAYER, req), range(12)))
        self.assertTrue(all(r == responses[0] for r in responses))
        self.assertEqual(len(self.server.export_store()["evidence_ledger"]), 1)

    def test_concurrent_distinct_requests_conflict(self):
        self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        requests = [request(self.server, i, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)}) for i in (2, 3)]
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(lambda r:self.server.handle(PLAYER, r), requests))
        self.assertEqual({r["status"] for r in responses}, {"applied", "conflict"})

    def test_duplicate_completion_new_id_is_noop(self):
        self.advance(1)
        before = self.server.snapshot()
        result = self.send(999, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)})
        self.assertEqual(result["status"], "noop");self.assertEqual(self.server.snapshot(), before)

    def test_proof_wrong_player_phase_attempt_or_evidence_rejected(self):
        for key, value in (("player_id", OTHER), ("phase_id", "desert_phase_10"), ("attempt_id", uid(555)), ("evidence_id", uid(666))):
            server = ServerReference(self.rules, PLAYER, completion_verifier=lambda req, state:replace(verified_fixture(req, state), **{key: value}))
            self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"}, server)
            result = self.send(2, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)}, server)
            self.assertEqual(result["code"], "proof_mismatch")

    def test_exit_must_be_verified(self):
        self.server._verifier = lambda req, state:replace(verified_fixture(req, state), exit_reached=False)
        self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        self.assertEqual(self.send(2, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)})["code"], "exit_evidence_required")

    def test_verifier_exception_fails_closed(self):
        def failure(*args): raise RuntimeError("private implementation failure")
        self.server._verifier = failure
        self.send(1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        self.assertEqual(self.send(2, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)})["code"], "verification_failed")

    def test_reused_evidence_or_attempt_rejected(self):
        self.advance(1)
        self.send(100, {"type": "start_phase", "phase_id": "desert_phase_02"})
        for i, attempt, evidence in ((101, uid(1001), uid(9000)), (102, uid(9001), uid(2001))):
            result = self.send(i, {"type": "complete_phase", "phase_id": "desert_phase_02", "attempt_id": attempt, "evidence_id": evidence})
            self.assertEqual(result["code"], "evidence_reused")

    def test_missing_malagueta_proof_does_not_unlock(self):
        self.advance(9)
        self.server._verifier = lambda req, state:replace(verified_fixture(req, state), defeated_boss_id=None)
        self.send(1000, {"type": "start_phase", "phase_id": "desert_phase_10"})
        result = self.send(1001, {"type": "complete_phase", "phase_id": "desert_phase_10", "attempt_id": uid(90), "evidence_id": uid(91)})
        self.assertEqual(result["code"], "boss_evidence_required")
        self.assertNotIn("el_fuego", self.server.snapshot()["unlocked_character_ids"])

    def test_restart_preserves_idempotency_and_evidence(self):
        req = request(self.server, 1, {"type": "start_phase", "phase_id": "desert_phase_01"})
        response = self.server.handle(PLAYER, req)
        restored = ServerReference.from_store(self.rules, self.server.export_store(), completion_verifier=verified_fixture)
        self.assertEqual(restored.handle(PLAYER, req), response)
        self.assertEqual(restored.snapshot(), self.server.snapshot())

    def test_ten_phase_store_roundtrip(self):
        self.advance(10)
        restored = ServerReference.from_store(self.rules, self.server.export_store())
        self.assertEqual(restored.snapshot(), self.server.snapshot())

    def test_corrupt_journal_or_missing_evidence_detected(self):
        self.advance(1)
        store = self.server.export_store();store["journal"][0]["request_digest"] = "0" * 64
        with self.assertRaises(ProgressionError): ServerReference.from_store(self.rules, seal(store))
        store = self.server.export_store();store["evidence_ledger"] = []
        with self.assertRaises(ProgressionError): ServerReference.from_store(self.rules, seal(store))


class ClientSyncTests(unittest.TestCase):
    def setUp(self):
        self.rules = rules()
        self.server = ServerReference(self.rules, PLAYER, completion_verifier=verified_fixture)
        self.channel = FixtureChannel()
        self.client = ClientSession(self.rules, new_save(self.rules, PLAYER, "online_authoritative"), authenticated_decoder=self.channel.decode)

    def confirm(self):
        self.client.accept_snapshot(self.channel.publish(self.server.snapshot()))

    def send(self, operation, number):
        req = self.client.queue_operation(operation, uid(number))
        response = self.server.handle(PLAYER, req)
        self.client.receive_response(self.channel.publish(response))
        return req, response

    def test_online_starts_unconfirmed(self):
        with self.assertRaises(ProgressionError): self.client.can_equip("cowboy")
        self.confirm();self.assertTrue(self.client.can_use_protagonist("desert_phase_01"));self.assertFalse(self.client.can_equip("el_fuego"))

    def test_cached_or_edited_snapshot_is_not_authority(self):
        forged = new_save(self.rules, PLAYER, "online_authoritative")
        forged["server_cache"] = new_state(self.rules, PLAYER);forged["server_cache"]["revision"] = 999
        client = ClientSession(self.rules, seal(forged), authenticated_decoder=self.channel.decode)
        with self.assertRaises(ProgressionError): client.can_equip("cowboy")
        client.accept_snapshot(self.channel.publish(self.server.snapshot()))
        self.assertEqual(client.effective_state()["revision"], 0)

    def test_offline_complete_does_not_grant_online_skin(self):
        from tools.progression.codec import ROOT
        save = load_save(self.rules, (ROOT / "data/progression/examples/offline_complete.save.json").read_bytes())
        save["mode"] = "online_authoritative"
        client = ClientSession(self.rules, seal(save), authenticated_decoder=self.channel.decode)
        client.accept_snapshot(self.channel.publish(self.server.snapshot()))
        self.assertFalse(client.can_equip("el_fuego"))
        self.assertEqual(len(client.export_save()["local_state"]["completed_phase_ids"]), 10)

    def test_missing_or_invalid_authenticated_channel_rejected(self):
        client = ClientSession(self.rules, new_save(self.rules, PLAYER, "online_authoritative"))
        with self.assertRaises(ProgressionError): client.accept_snapshot(canonical(self.server.snapshot()))
        with self.assertRaises(ProgressionError): self.client.accept_snapshot(b"unregistered payload")

    def test_other_identity_or_other_player_snapshot_rejected(self):
        with self.assertRaises(ProgressionError): self.client.accept_snapshot(self.channel.publish(self.server.snapshot(), OTHER))
        snapshot = self.server.snapshot();snapshot["player_id"] = OTHER
        with self.assertRaises(ProgressionError): self.client.accept_snapshot(self.channel.publish(snapshot))

    def test_conflict_rebase_keeps_original_and_uses_new_id(self):
        self.confirm()
        req = self.client.queue_operation({"type": "equip_character", "character_id": "michelly"}, uid(1))
        self.server.handle(PLAYER, request(self.server, 2, {"type": "start_phase", "phase_id": "desert_phase_01"}))
        conflict = self.server.handle(PLAYER, req)
        self.assertTrue(self.client.receive_response(self.channel.publish(conflict))["requires_rebase"])
        rebased = self.client.rebase_request(uid(1), uid(3))
        self.assertEqual(rebased["expected_revision"], 1)
        self.assertEqual(self.client.export_save()["outbox"][0]["request"], req)
        self.assertEqual(self.client.export_save()["outbox"][0]["status"], "superseded")
        result = self.server.handle(PLAYER, rebased)
        self.client.receive_response(self.channel.publish(result))
        self.assertEqual(self.client.effective_state()["equipped_character_id"], "michelly")
        self.client.receive_response(self.channel.publish(conflict))
        self.assertEqual(self.client.effective_state()["revision"], 2)

    def test_applied_or_rejected_request_not_rebasable(self):
        self.confirm();self.send({"type": "equip_character", "character_id": "el_fuego"}, 1)
        with self.assertRaises(ProgressionError): self.client.rebase_request(uid(1), uid(2))
        self.assertEqual(self.client.export_save()["outbox"][0]["status"], "rejected")

    def test_same_revision_different_content_rejected(self):
        self.confirm();before = self.client.export_save()
        snapshot = self.server.snapshot();snapshot["equipped_character_id"] = "michelly"
        with self.assertRaises(ProgressionError) as caught:self.client.accept_snapshot(self.channel.publish(snapshot))
        self.assertEqual(caught.exception.code, "same_revision_conflict")
        self.assertEqual(self.client.export_save(), before)

    def test_delayed_response_does_not_roll_back_state(self):
        self.confirm();_, first = self.send({"type": "start_phase", "phase_id": "desert_phase_01"}, 1)
        self.send({"type": "record_checkpoint", "phase_id": "desert_phase_01", "checkpoint_id": self.rules.phases[0].checkpoint_ids[0]}, 2)
        resolution = self.client.receive_response(self.channel.publish(first))
        self.assertEqual(resolution["resolution"], "stale_ignored")
        self.assertEqual(self.client.effective_state()["revision"], 2)

    def test_higher_revision_cannot_remove_verified_progress(self):
        self.server.handle(PLAYER, request(self.server, 1, {"type": "start_phase", "phase_id": "desert_phase_01"}))
        self.server.handle(PLAYER, request(self.server, 2, {"type": "complete_phase", "phase_id": "desert_phase_01", "attempt_id": uid(90), "evidence_id": uid(91)}))
        self.confirm()
        snapshot = new_state(self.rules, PLAYER);snapshot["revision"] = 99
        with self.assertRaises(ProgressionError) as caught:self.client.accept_snapshot(self.channel.publish(snapshot))
        self.assertEqual(caught.exception.code, "remote_progress_rollback")

    def test_outbox_persisted_but_trust_not_persisted(self):
        self.confirm();self.send({"type": "start_phase", "phase_id": "desert_phase_01"}, 1)
        save = self.client.export_save()
        restored = ClientSession(self.rules, load_save(self.rules, canonical(save)), authenticated_decoder=self.channel.decode)
        self.assertEqual(restored.export_save()["outbox"], save["outbox"])
        with self.assertRaises(ProgressionError): restored.effective_state()
        restored.accept_snapshot(self.channel.publish(self.server.snapshot()))
        self.assertEqual(restored.effective_state(), self.server.snapshot())

    def test_unknown_response_not_applied(self):
        self.confirm();before = self.client.export_save()
        response = self.server.handle(PLAYER, request(self.server, 999, {"type": "start_phase", "phase_id": "desert_phase_01"}))
        with self.assertRaises(ProgressionError): self.client.receive_response(self.channel.publish(response))
        self.assertEqual(self.client.export_save(), before)

    def test_rules_version_mismatch_does_not_replace_cache(self):
        self.confirm();snapshot = self.server.snapshot();snapshot["rules_version"] = "future_rules_3"
        with self.assertRaises(ProgressionError): self.client.accept_snapshot(self.channel.publish(snapshot))


if __name__ == "__main__":
    unittest.main()
