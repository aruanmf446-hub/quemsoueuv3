"""Duelo, etapas 1 e 2 (salas e partida): integração SQL REAL em PostgreSQL descartável, sem serviço remoto.

QSE_PG_BIN deve apontar ao diretório de binários PostgreSQL 17 (initdb/pg_ctl/psql).
O cluster é criado numa pasta temporária, só aceita conexões locais e é removido ao terminar.
Uso: QSE_PG_BIN=/caminho/bin python -m unittest tools.player_ui.test_duel_rooms
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
PORT = "55441"
CARDS = ("cowboy", "el_fuego", "gus", "halloween", "lana", "lorena", "michelly", "rodrigo")
MIGRATIONS = ("202610280001_player_foundation.sql", "202610280002_player_api.sql", "202610300001_duel_rooms.sql",
              "202610300002_duel_match.sql")


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


class DuelRoomTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        binary = os.environ.get("QSE_PG_BIN", "")
        if not binary:
            raise unittest.SkipTest("QSE_PG_BIN ausente; nenhum banco remoto será usado")
        cls.binary = Path(binary).resolve()
        suffix = ".exe" if os.name == "nt" else ""
        for name in ("initdb", "pg_ctl", "psql"):
            if not (cls.binary / (name + suffix)).is_file():
                raise RuntimeError(f"Binário PostgreSQL ausente: {name}")
        cls.temp = tempfile.TemporaryDirectory(prefix="qse-duel-pg-")
        cls.base = Path(cls.temp.name)
        cls.cluster = cls.base / "cluster"
        cls.run_binary("initdb", "-D", str(cls.cluster), "-A", "trust", "-U", "postgres", "--no-locale", "-E", "UTF8")
        listen = "-c listen_addresses=127.0.0.1" if os.name == "nt" else f"-k {cls.base} -c listen_addresses=''"
        cls.run_binary("pg_ctl", "-D", str(cls.cluster), "-l", str(cls.base / "postgres.log"),
                       "-o", f"-p {PORT} {listen}", "-w", "start")
        cls.addClassCleanup(cls.shutdown)
        cls.sql((ROOT / "supabase/tests/bootstrap_local.sql").read_text(encoding="utf-8"))
        # Catálogo mínimo de personagens (a migration 0001 cria a tabela; o projeto real já tem dados).
        for name in MIGRATIONS:
            cls.sql((ROOT / "supabase/migrations" / name).read_text(encoding="utf-8"))
            if name.endswith("0001_player_foundation.sql"):
                cls.ensure_catalog()
        # Deck de teste (no jogo, cada carta é um PNG em assets/duel/decks/<deck>/<carta>.png).
        cls.sql("insert into qse_v3.duel_decks(id,name,card_ids,sort_order) values ('teste','Teste',array["
                + ",".join(f"'teste/{name}'" for name in CARDS) + "],0);")

    @classmethod
    def ensure_catalog(cls):
        count = cls.sql("select count(*) from qse_v3.character_catalog;")
        if int(count or 0) == 0:
            columns = cls.sql("select string_agg(column_name||':'||is_nullable||':'||coalesce(column_default,''),',') "
                              "from information_schema.columns where table_schema='qse_v3' and table_name='character_catalog';")
            raise RuntimeError("character_catalog vazio no teste; colunas: " + str(columns))

    @classmethod
    def shutdown(cls):
        cls.run_binary("pg_ctl", "-D", str(cls.cluster), "-m", "fast", "-w", "stop")
        cls.temp.cleanup()

    @classmethod
    def run_binary(cls, name, *args):
        suffix = ".exe" if os.name == "nt" else ""
        # pg_ctl deixa o servidor herdando os pipes: no Windows, capturar a saída trava a espera.
        # A saída vai para um arquivo, lido só em caso de erro (o Windows pode não usar UTF-8).
        with open(cls.base / f"{name}.out", "wb") as output:
            result = subprocess.run([str(cls.binary / (name + suffix)), *args], stdout=output,
                                    stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
        if result.returncode:
            raise RuntimeError((cls.base / f"{name}.out").read_bytes().decode("utf-8", "replace"))

    @classmethod
    def sql(cls, sql, owner=None, role=None, error=False):
        prefix = ""
        if role:
            prefix += f"set role {role};"
        if owner:
            prefix += f"set request.jwt.claim.sub={literal(owner)};"
        host = "127.0.0.1" if os.name == "nt" else str(cls.base)
        suffix = ".exe" if os.name == "nt" else ""
        process = subprocess.run([str(cls.binary / ("psql" + suffix)), "-X", "-q", "-t", "-A", "-U", "postgres",
            "-h", host, "-p", PORT, "-d", "postgres", "-v", "ON_ERROR_STOP=1"],
            input=prefix + sql, text=True, capture_output=True, encoding="utf-8", errors="replace")
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

    def player(self, nickname):
        owner = str(uuid.uuid4())
        self.sql(f"insert into auth.users values({literal(owner)},'fixture@example.invalid');")
        self.rpc(owner, "qse_profile_self")
        self.rpc(owner, "qse_profile_update", literal(nickname))
        return owner

    def rpc(self, owner, name, args=""):
        return self.sql(f"select public.{name}({args});", owner, "authenticated")

    def create(self, owner, name="Sala de Teste", public=True, settings=None):
        return self.rpc(owner, "qse_duel_create",
            f"{literal(name)},{'true' if public else 'false'},{literal(json.dumps(settings or {}))}::jsonb")

    def room_id(self, snapshot):
        return literal(snapshot["room"]["id"]) + "::uuid"

    def listed(self, owner, term=""):
        return [room["code"] for room in self.rpc(owner, "qse_duel_list", f"{literal(term)},false")["rooms"]]

    def test_create_join_and_public_listing(self):
        ana, beto = self.player("Ana Duelo"), self.player("Beto Duelo")
        room = self.create(ana)
        code = room["room"]["code"]
        self.assertRegex(code, r"^[A-HJ-NP-Z2-9]{6}$")
        self.assertTrue(room["you"]["is_admin"])
        self.assertEqual(room["room"]["settings"]["max_players"], 10)
        self.assertEqual(room["room"]["settings"]["turn_seconds"], 60)
        self.assertEqual(room["room"]["settings"]["selection_seconds"], 30)
        self.assertIn(code, self.listed(beto))
        # Código digitado em minúsculas e com hífen também entra.
        joined = self.rpc(beto, "qse_duel_join", literal(code[:3].lower() + "-" + code[3:]))
        self.assertEqual(joined["you"]["role"], "player")
        self.assertFalse(joined["you"]["is_admin"])
        self.assertEqual(len(joined["members"]), 2)
        self.assertNotIn("user_id", json.dumps(joined))
        private = self.create(self.player("Caio Duelo"), "Sala Fechada", False)
        self.assertNotIn(private["room"]["code"], self.listed(beto))

    def test_settings_are_validated_and_admin_only(self):
        ana, beto = self.player("Ana Config"), self.player("Beto Config")
        room = self.create(ana, settings={"max_players": 4, "cards_per_player": 2, "turn_seconds": 45})
        self.assertEqual(room["room"]["settings"]["max_players"], 4)
        for bad in ({"max_players": 21}, {"max_players": 1}, {"cards_per_player": 99}, {"turn_seconds": "60"},
                    {"deck_ids": ["inexistente"]}, {"desconhecida": 1}, {"max_players": 3.5}):
            self.assertEqual(self.create(self.player("Erro Config"), settings=bad).get("error"), "invalid_settings", bad)
        self.rpc(beto, "qse_duel_join", literal(room["room"]["code"]))
        rid = self.room_id(room)
        self.assertEqual(self.rpc(beto, "qse_duel_configure", f"{rid},null,null,'{{}}'::jsonb")["error"], "not_admin")
        self.assertEqual(self.rpc(beto, "qse_duel_add_bot", rid)["error"], "not_admin")
        self.assertEqual(self.rpc(beto, "qse_duel_start", rid)["error"], "not_admin")
        changed = self.rpc(ana, "qse_duel_configure", f"{rid},'Sala Nova',false,'{{\"selection_seconds\":20}}'::jsonb")
        self.assertEqual(changed["room"]["name"], "Sala Nova")
        self.assertEqual(changed["room"]["settings"]["selection_seconds"], 20)
        self.assertEqual(changed["room"]["settings"]["max_players"], 4)
        # Não dá para baixar o limite abaixo de quem já está na sala (2 pessoas + 1 bot).
        self.rpc(ana, "qse_duel_add_bot", rid)
        self.assertEqual(self.rpc(ana, "qse_duel_configure", f"{rid},null,null,'{{\"max_players\":2}}'::jsonb")["error"], "max_below_players")

    def test_room_full_and_bots(self):
        ana = self.player("Ana Bots")
        room = self.create(ana, settings={"max_players": 3})
        rid = self.room_id(room)
        with_bot = self.rpc(ana, "qse_duel_add_bot", rid)
        bots = [m for m in with_bot["members"] if m["is_bot"]]
        self.assertEqual(len(bots), 1)
        self.assertFalse(bots[0]["is_admin"])
        self.rpc(ana, "qse_duel_add_bot", rid)
        self.assertEqual(self.rpc(ana, "qse_duel_add_bot", rid)["error"], "room_full")
        self.assertEqual(self.rpc(self.player("Lotado"), "qse_duel_join", literal(room["room"]["code"]))["error"], "room_full")
        # Proibir bots remove os que estavam na sala.
        without = self.rpc(ana, "qse_duel_configure", f"{rid},null,null,'{{\"bots_allowed\":false}}'::jsonb")
        self.assertFalse(any(m["is_bot"] for m in without["members"]))
        self.assertEqual(self.rpc(ana, "qse_duel_add_bot", rid)["error"], "bots_disabled")

    def test_admin_transfer_never_to_bot_and_bot_only_room_closes(self):
        ana, beto = self.player("Ana Adm"), self.player("Beto Adm")
        room = self.create(ana)
        rid = self.room_id(room)
        self.rpc(ana, "qse_duel_add_bot", rid)
        self.rpc(beto, "qse_duel_join", literal(room["room"]["code"]))
        self.rpc(ana, "qse_duel_leave", rid)
        after = self.rpc(beto, "qse_duel_room", rid)
        self.assertTrue(after["you"]["is_admin"])
        self.assertTrue(all(not m["is_admin"] for m in after["members"] if m["is_bot"]))
        # Último jogador real sai: só restam bots, a sala é encerrada.
        self.rpc(beto, "qse_duel_leave", rid)
        self.assertEqual(self.rpc(self.player("Tarde Demais"), "qse_duel_join", literal(room["room"]["code"]))["error"], "room_closed")
        self.assertNotIn(room["room"]["code"], self.listed(beto))

    def test_kick_rules(self):
        ana, beto, caio = self.player("Ana Kick"), self.player("Beto Kick"), self.player("Caio Kick")
        room = self.create(ana)
        rid, code = self.room_id(room), literal(room["room"]["code"])
        joined = self.rpc(beto, "qse_duel_join", code)
        beto_member = joined["you"]["member_id"]
        self.assertEqual(self.rpc(ana, "qse_duel_kick", f"{rid},{literal(room['you']['member_id'])}::uuid")["error"], "cannot_kick_self")
        kicked = self.rpc(ana, "qse_duel_kick", f"{rid},{literal(beto_member)}::uuid")
        self.assertEqual(len(kicked["members"]), 1)
        self.assertEqual(self.rpc(beto, "qse_duel_join", code)["error"], "kicked")
        # Em partida: jogador vivo não pode ser expulso; espectador pode.
        self.rpc(caio, "qse_duel_join", code)
        self.rpc(ana, "qse_duel_add_bot", rid)
        started = self.rpc(ana, "qse_duel_start", rid)
        self.assertEqual(started["room"]["status"], "in_match")
        caio_member = next(m["member_id"] for m in started["members"] if m["nickname"] == "Caio Kick")
        self.assertEqual(self.rpc(ana, "qse_duel_kick", f"{rid},{literal(caio_member)}::uuid")["error"], "cannot_kick_active_player")
        ghost = self.rpc(self.player("Davi Ghost"), "qse_duel_join", code)
        self.assertEqual(ghost["you"]["role"], "spectator")
        removed = self.rpc(ana, "qse_duel_kick", f"{rid},{literal(ghost['you']['member_id'])}::uuid")
        self.assertNotIn("Davi Ghost", [m["nickname"] for m in removed["members"]])

    def test_start_hides_room_and_needs_two_players(self):
        ana = self.player("Ana Start")
        room = self.create(ana)
        rid = self.room_id(room)
        self.assertEqual(self.rpc(ana, "qse_duel_start", rid)["error"], "not_enough_players")
        self.rpc(ana, "qse_duel_add_bot", rid)
        started = self.rpc(ana, "qse_duel_start", rid)
        self.assertEqual(started["room"]["match_phase"], "selection")
        self.assertIsNotNone(started["room"]["phase_deadline"])
        self.assertNotIn(room["room"]["code"], self.listed(self.player("Curioso")))
        self.assertEqual(self.rpc(ana, "qse_duel_configure", f"{rid},null,null,'{{}}'::jsonb")["error"], "match_in_progress")

    def test_one_room_at_a_time_and_stale_members_leave_lobby(self):
        ana, beto = self.player("Ana Uma"), self.player("Beto Uma")
        first = self.create(ana, "Primeira")
        second = self.create(ana, "Segunda")
        # Ana saiu da primeira (era a única pessoa real): a sala foi encerrada.
        self.assertEqual(self.rpc(beto, "qse_duel_join", literal(first["room"]["code"]))["error"], "room_closed")
        rid = self.room_id(second)
        self.rpc(beto, "qse_duel_join", literal(second["room"]["code"]))
        # Ana para de dar sinal: some do lobby e Beto vira ADM.
        self.sql(f"update qse_v3.duel_members set last_seen_at = now() - interval '2 minutes' where room_id = {rid} "
                 f"and user_id = {literal(ana)}::uuid;")
        beat = self.rpc(beto, "qse_duel_heartbeat", rid)
        self.assertTrue(beat["member"])
        after = self.rpc(beto, "qse_duel_room", rid)
        self.assertEqual(len(after["members"]), 1)
        self.assertTrue(after["you"]["is_admin"])
        self.assertFalse(self.rpc(ana, "qse_duel_heartbeat", rid)["member"])

    def test_tables_are_not_readable_directly(self):
        owner = self.player("Ana Sigilo")
        self.create(owner)
        for table in ("duel_rooms", "duel_members", "duel_kicks", "duel_decks"):
            self.sql(f"select * from qse_v3.{table};", owner, "authenticated", error=True)
        self.assertEqual(self.rpc(self.player("Bia Sigilo"), "qse_duel_room",
            literal(str(uuid.uuid4())) + "::uuid")["error"], "not_member")


    # --- Etapa 2: a partida ------------------------------------------------------------------
    def member_id(self, rid, owner):
        return self.sql(f"select id from qse_v3.duel_members where room_id = {rid} and user_id = {literal(owner)}::uuid;")

    def expire(self, rid):
        """Simula o tempo passando: o prazo da fase atual e o suspense da revelação vencem."""
        self.sql(f"update qse_v3.duel_matches set phase_deadline = now() - interval '1 second', "
                 f"turn_started_at = now() - interval '1 minute' where room_id = {rid};"
                 f"update qse_v3.duel_match_events set reveal_at = now() - interval '1 second' where match_id in "
                 f"(select id from qse_v3.duel_matches where room_id = {rid});")

    def match(self, owner, rid):
        return self.rpc(owner, "qse_duel_room", rid)["match"]

    def select(self, owner, rid, cards):
        array = "array[" + ",".join(literal(c) for c in cards) + "]::text[]"
        return self.rpc(owner, "qse_duel_select", f"{rid},{array}")

    def pick(self, owner, rid, card):
        return self.rpc(owner, "qse_duel_pick", f"{rid},{literal(card)}")

    def turn_to(self, rid, owner):
        member = literal(self.member_id(rid, owner)) + "::uuid"
        self.sql(f"update qse_v3.duel_matches set phase = 'turns', turn_member = {member}, "
                 f"turn_index = array_position(turn_order,{member}) - 1, turn_started_at = now(), "
                 f"phase_deadline = now() + interval '60 seconds' where room_id = {rid} and finished_at is null;")

    def game(self, names, cards, settings=None):
        """Sala com jogadores reais, partida iniciada, cartas escolhidas e a fase de turnos aberta."""
        owners = [self.player(name) for name in names]
        room = self.create(owners[0], settings=settings or {"cards_per_player": len(cards[0])})
        rid = self.room_id(room)
        for owner in owners[1:]:
            self.rpc(owner, "qse_duel_join", literal(room["room"]["code"]))
        self.rpc(owners[0], "qse_duel_start", rid)
        for owner, chosen in zip(owners, cards):
            self.assertIn(self.select(owner, rid, chosen)["match"]["phase"], ("selection", "countdown"))
        self.expire(rid)
        self.assertEqual(self.match(owners[0], rid)["phase"], "turns")
        return owners, rid, room

    def player_state(self, match, nickname):
        return next(p for p in match["players"] if p["nickname"] == nickname)

    def test_secret_selection_autofill_countdown_and_turn_order(self):
        ana, beto = self.player("Ana Secreta"), self.player("Beto Secreto")
        room = self.create(ana)
        rid = self.room_id(room)
        self.rpc(beto, "qse_duel_join", literal(room["room"]["code"]))
        self.rpc(ana, "qse_duel_add_bot", rid)
        started = self.rpc(ana, "qse_duel_start", rid)["match"]
        self.assertEqual(started["phase"], "selection")
        self.assertTrue(self.player_state(started, "Bot Areia")["confirmed"])
        self.assertEqual(self.select(ana, rid, ["teste/cowboy", "teste/cowboy", "teste/lana"])["error"], "invalid_selection")
        self.assertEqual(self.select(ana, rid, ["teste/cowboy", "teste/lana"])["error"], "invalid_selection")
        self.assertEqual(self.select(ana, rid, ["teste/cowboy", "teste/lana", "inexistente"])["error"], "invalid_selection")
        mine = self.select(ana, rid, ["teste/cowboy", "teste/lana", "teste/gus"])["match"]
        self.assertEqual(sorted(c["card_id"] for c in mine["my_cards"]), ["teste/cowboy", "teste/gus", "teste/lana"])
        # Beto vê que Ana está PRONTA, mas nunca as cartas dela.
        seen = self.match(beto, rid)
        self.assertTrue(self.player_state(seen, "Ana Secreta")["confirmed"])
        self.assertEqual(seen["my_cards"], [])
        self.assertNotIn("teste/gus", json.dumps(seen["players"]))
        # Tempo esgotado: o sistema completa as cartas de Beto e começa a contagem de 5 s.
        self.expire(rid)
        counting = self.match(beto, rid)
        self.assertEqual(counting["phase"], "countdown")
        self.assertEqual(len(counting["my_cards"]), 3)
        self.expire(rid)
        turns = self.match(ana, rid)
        self.assertEqual(turns["phase"], "turns")
        self.assertEqual(len(turns["turn_order"]), 3)
        self.assertIn(turns["turn_member"], turns["turn_order"])

    def test_all_confirmed_starts_countdown_without_waiting(self):
        ana, beto = self.player("Ana Rapida"), self.player("Beto Rapido")
        room = self.create(ana, settings={"cards_per_player": 1})
        rid = self.room_id(room)
        self.rpc(beto, "qse_duel_join", literal(room["room"]["code"]))
        self.rpc(ana, "qse_duel_start", rid)
        self.select(ana, rid, ["teste/cowboy"])
        self.assertEqual(self.select(beto, rid, ["teste/lana"])["match"]["phase"], "countdown")

    def test_pick_hits_everyone_with_the_card_including_the_picker(self):
        (ana, beto, caio), rid, _ = self.game(["Ana Pick", "Beto Pick", "Caio Pick"],
            [["teste/cowboy", "teste/lana", "teste/gus"], ["teste/cowboy", "teste/lorena", "teste/rodrigo"], ["teste/michelly", "teste/halloween", "teste/el_fuego"]])
        self.turn_to(rid, ana)
        self.assertEqual(self.pick(beto, rid, "teste/lana")["error"], "not_your_turn")
        picked = self.pick(ana, rid, "teste/cowboy")["match"]
        last = picked["events"][-1]
        # Suspense: logo após a escolha, ninguém sabe quem foi atingido.
        self.assertEqual((last["kind"], last["card_id"], last["revealed"], last["hits"]), ("pick", "teste/cowboy", False, None))
        self.expire(rid)
        after = self.match(caio, rid)
        hit = next(e for e in after["events"] if e["kind"] == "pick")
        self.assertEqual(sorted(h["lives"] for h in hit["hits"]), [2, 2])
        self.assertEqual(self.player_state(after, "Ana Pick")["lives"], 2)
        self.assertEqual(self.player_state(after, "Beto Pick")["lives"], 2)
        self.assertEqual(self.player_state(after, "Caio Pick")["lives"], 3)
        self.assertEqual(self.player_state(after, "Beto Pick")["lost"], ["teste/cowboy"])
        self.assertTrue(next(c for c in after["pool"] if c["card_id"] == "teste/cowboy")["removed"])
        self.turn_to(rid, beto)
        self.assertEqual(self.pick(beto, rid, "teste/cowboy")["error"], "card_unavailable")

    def test_card_nobody_has_is_removed_without_hits(self):
        (ana, beto), rid, _ = self.game(["Ana Ninguem", "Beto Ninguem"], [["teste/cowboy", "teste/lana"], ["teste/gus", "teste/lorena"]])
        self.turn_to(rid, ana)
        self.pick(ana, rid, "teste/halloween")
        self.expire(rid)
        state = self.match(beto, rid)
        event = next(e for e in state["events"] if e["kind"] == "pick")
        self.assertEqual(event["hits"], [])
        self.assertTrue(next(c for c in state["pool"] if c["card_id"] == "teste/halloween")["removed"])
        self.assertEqual([p["lives"] for p in state["players"]], [2, 2])
        self.assertEqual(state["phase"], "turns")

    def test_faults_remove_lives_not_cards_and_second_fault_eliminates(self):
        (ana, beto, caio), rid, _ = self.game(["Ana Falta", "Beto Falta", "Caio Falta"],
            [["teste/cowboy", "teste/lana", "teste/gus"], ["teste/lorena", "teste/rodrigo", "teste/michelly"], ["teste/halloween", "teste/el_fuego", "teste/cowboy"]])
        self.turn_to(rid, beto)
        self.expire(rid)  # Beto não votou
        state = self.match(ana, rid)
        beto_state = self.player_state(state, "Beto Falta")
        self.assertEqual((beto_state["lives"], beto_state["faults"], beto_state["cards_left"], beto_state["eliminated"]), (2, 1, 3, False))
        self.assertEqual(next(e for e in state["events"] if e["kind"] == "timeout")["actor"], self.member_id(rid, beto))
        # Beto vota normalmente depois; a próxima falta (não seguida) ainda elimina.
        self.turn_to(rid, beto)
        self.pick(beto, rid, "teste/gus")
        self.expire(rid)
        self.turn_to(rid, beto)
        self.expire(rid)
        beto_state = self.player_state(self.match(ana, rid), "Beto Falta")
        self.assertEqual((beto_state["eliminated"], beto_state["reason"], beto_state["cards_left"]), (True, "faults", 3))

    def test_last_standing_wins_and_room_returns_to_lobby(self):
        (ana, beto), rid, room = self.game(["Ana Final", "Beto Final"], [["teste/cowboy"], ["teste/lana"]])
        ghost = self.player("Gil Espectador")
        self.assertEqual(self.rpc(ghost, "qse_duel_join", literal(room["room"]["code"]))["you"]["role"], "spectator")
        self.assertEqual(self.pick(ghost, rid, "teste/lana")["error"], "not_your_turn")
        self.turn_to(rid, ana)
        self.pick(ana, rid, "teste/lana")
        self.expire(rid)
        done = self.match(ana, rid)
        self.assertEqual(done["phase"], "finished")
        self.assertEqual(done["result"]["winners"], [self.member_id(rid, ana)])
        self.expire(rid)
        lobby = self.rpc(ana, "qse_duel_room", rid)
        self.assertEqual(lobby["room"]["status"], "lobby")
        self.assertIsNone(lobby["match"])
        self.assertEqual(next(m for m in lobby["members"] if m["nickname"] == "Gil Espectador")["role"], "player")
        self.assertEqual(lobby["room"]["settings"]["cards_per_player"], 1)

    def test_only_bots_left_closes_the_room(self):
        ana = self.player("Ana Sozinha")
        room = self.create(ana, settings={"cards_per_player": 1})
        rid = self.room_id(room)
        self.rpc(ana, "qse_duel_add_bot", rid)
        self.rpc(ana, "qse_duel_start", rid)
        self.rpc(ana, "qse_duel_leave", rid)
        self.assertEqual(self.rpc(self.player("Visita"), "qse_duel_join", literal(room["room"]["code"]))["error"], "room_closed")

    def test_bot_plays_its_turn(self):
        ana = self.player("Ana Bot")
        room = self.create(ana, settings={"cards_per_player": 2})
        rid = self.room_id(room)
        bot_room = self.rpc(ana, "qse_duel_add_bot", rid)
        bot = next(m["member_id"] for m in bot_room["members"] if m["is_bot"])
        self.rpc(ana, "qse_duel_start", rid)
        self.select(ana, rid, ["teste/cowboy", "teste/lana"])
        # Todos prontos (o bot confirma na hora): a contagem já começou; vencida, abre os turnos.
        self.expire(rid)
        self.assertEqual(self.match(ana, rid)["phase"], "turns")
        self.sql(f"update qse_v3.duel_matches set phase = 'turns', turn_member = {literal(bot)}::uuid, "
                 f"turn_index = array_position(turn_order,{literal(bot)}::uuid) - 1, turn_started_at = now() - interval '5 seconds', "
                 f"phase_deadline = now() + interval '60 seconds' where room_id = {rid};")
        state = self.match(ana, rid)
        event = state["events"][-1]
        self.assertEqual((event["kind"], event["actor"]), ("pick", bot))

    def test_admin_moves_when_eliminated_and_silent_players_are_disconnected(self):
        (ana, beto, caio), rid, room = self.game(["Ana Queda", "Beto Queda", "Caio Queda"],
            [["teste/cowboy"], ["teste/lana"], ["teste/gus"]], {"cards_per_player": 1})
        self.turn_to(rid, beto)
        self.pick(beto, rid, "teste/cowboy")  # Ana perde a única vida e é eliminada
        self.expire(rid)
        state = self.rpc(beto, "qse_duel_room", rid)
        admins = [m["nickname"] for m in state["members"] if m["is_admin"]]
        self.assertEqual(len(admins), 1)
        self.assertIn(admins[0], ("Beto Queda", "Caio Queda"))
        # Caio para de dar sinal durante a partida: é eliminado por desconexão e, ao voltar,
        # continua na sala como espectador da disputa.
        self.sql(f"update qse_v3.duel_members set last_seen_at = now() - interval '2 minutes' where room_id = {rid} "
                 f"and user_id = {literal(caio)}::uuid;")
        self.rpc(beto, "qse_duel_heartbeat", rid)
        back = self.rpc(caio, "qse_duel_join", literal(room["room"]["code"]))
        mine = next(p for p in back["match"]["players"] if p["is_you"])
        self.assertEqual((mine["eliminated"], mine["reason"]), (True, "disconnect"))
        # Beto é o único vivo: venceu.
        self.assertEqual(back["match"]["phase"], "finished")
        self.assertEqual(back["match"]["result"]["winners"], [self.member_id(rid, beto)])

    def test_admin_can_remove_eliminated_player_but_not_alive_one(self):
        (ana, beto, caio), rid, _ = self.game(["Ana Ghost", "Beto Ghost", "Caio Ghost"],
            [["teste/cowboy", "teste/lana"], ["teste/gus", "teste/lorena"], ["teste/cowboy", "teste/michelly"]])
        self.assertEqual(self.rpc(ana, "qse_duel_kick", f"{rid},{literal(self.member_id(rid, beto))}::uuid")["error"],
                         "cannot_kick_active_player")
        self.turn_to(rid, beto)
        self.pick(beto, rid, "teste/cowboy")
        self.expire(rid)
        self.turn_to(rid, beto)
        self.pick(beto, rid, "teste/michelly")  # Caio fica sem vidas
        self.expire(rid)
        removed = self.rpc(ana, "qse_duel_kick", f"{rid},{literal(self.member_id(rid, caio))}::uuid")
        self.assertNotIn("Caio Ghost", [m["nickname"] for m in removed["members"]])
        # A expulsão não interrompe a disputa: os turnos seguem entre Ana e Beto.
        after = self.match(beto, rid)
        self.assertEqual(after["phase"], "turns")
        self.assertIn(after["turn_member"], (self.member_id(rid, ana), self.member_id(rid, beto)))


if __name__ == "__main__":
    unittest.main()
