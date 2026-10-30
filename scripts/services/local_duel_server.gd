class_name LocalDuelServer
extends Node
## Partida local do Duelo: o mesmo contrato das funções public.qse_duel_* do Supabase
## (supabase/migrations/202610300001_duel_rooms.sql e 202610300002_duel_match.sql), rodando
## neste aparelho, sem conta e sem rede. As regras são uma tradução direta das funções SQL:
## seleção secreta, contagem, ordem sorteada, turnos com voto, eliminação de personagem
## (atinge todos que têm a carta), vidas x cartas, faltas, bots, fim e volta ao lobby.
## O tempo avança de forma preguiçosa, como no servidor: toda chamada roda _advance().
##
## A sala local nunca é pública nem listada: só existe na memória deste jogo, com um único
## jogador humano (o próprio aparelho) e bots.

const DECKS_ROOT := "res://assets/duel/decks"
const VALID_ID := "^[a-z0-9_]{2,32}$"
const HUMAN := "local_player"
const SETTING_KEYS := ["max_players", "deck_ids", "cards_per_player", "bots_allowed", "turn_seconds",
	"selection_seconds", "tiebreak_base", "tiebreak_per_player"]
const BOT_NAMES := ["Bot Areia", "Bot Duna", "Bot Oásis", "Bot Miragem", "Bot Brasa", "Bot Lua", "Bot Vento",
	"Bot Cristal", "Bot Farol", "Bot Trovão", "Bot Neblina", "Bot Pedra", "Bot Aurora", "Bot Cometa",
	"Bot Tempestade", "Bot Sol", "Bot Eco", "Bot Faísca", "Bot Âmbar", "Bot Estrela"]
## Tempos fixos da apresentação (segundos), iguais a qse_v3.duel_timing.
const TIMING := {"countdown": 5.0, "suspense": 2.5, "reveal": 6.5, "timeout": 3.5, "finished": 9.0,
	"bot_think": 2.5, "disconnect": 30.0}
const LOBBY_STALE := 45.0

## Nome e skin do jogador humano (a tela de Duelo preenche com o perfil/skin equipada).
var nickname_provider: Callable
var skin_provider: Callable
## Personagens que os bots podem usar (ids do catálogo).
var bot_skins: Array = []
var rng := RandomNumberGenerator.new()
## Avanço artificial do relógio (testes): soma-se ao relógio do sistema.
var clock_offset := 0.0

var _decks: Array = []
var _room: Dictionary = {}
var _members: Array = []
var _match: Dictionary = {}
var _players: Array = []
var _cards: Dictionary = {}
var _events: Array = []
var _serial := 0


func _ready() -> void:
	rng.randomize()
	if bot_skins.is_empty():
		for entry: Dictionary in CharacterCatalog.load_entries():
			bot_skins.append(str(entry.get("id", "")))


## Mesmo envelope do SupabaseClient.call_rpc: {"error": código} vira falha.
func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	var data: Variant
	match name:
		"qse_duel_decks": data = {"decks": _decks_json([]), "defaults": default_settings()}
		"qse_duel_create": data = _create(params.get("p_name"), params.get("p_settings"))
		"qse_duel_list": data = {"rooms": []}
		"qse_duel_join": data = {"error": "room_not_found"}
		"qse_duel_leave": data = _leave(str(params.get("p_room", "")))
		"qse_duel_heartbeat": data = _heartbeat(str(params.get("p_room", "")))
		"qse_duel_room": data = _room_rpc(str(params.get("p_room", "")))
		"qse_duel_configure": data = _configure(str(params.get("p_room", "")), params.get("p_name"), params.get("p_settings"))
		"qse_duel_add_bot": data = _add_bot(str(params.get("p_room", "")))
		"qse_duel_kick": data = _kick(str(params.get("p_room", "")), str(params.get("p_member", "")))
		"qse_duel_start": data = _start(str(params.get("p_room", "")))
		"qse_duel_select": data = _select(str(params.get("p_room", "")), params.get("p_cards"))
		"qse_duel_pick": data = _pick(str(params.get("p_room", "")), params.get("p_card"))
		_: data = {"error": "request_failed"}
	if data is Dictionary and data.has("error"): return ServiceResult.failure(str(data.error))
	return ServiceResult.success(data)


func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset


# --- Decks (assets/duel/decks, mesmas regras de tools/duel/sync_decks.py) ------------------
func decks() -> Array:
	if not _decks.is_empty(): return _decks
	var valid := RegEx.create_from_string(VALID_ID)
	var folders := Array(DirAccess.get_directories_at(DECKS_ROOT))
	folders.sort()
	for folder: String in folders:
		if valid.search(folder) == null: continue
		var info: Dictionary = {}
		var info_path := "%s/%s/deck.json" % [DECKS_ROOT, folder]
		if FileAccess.file_exists(info_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(info_path))
			if parsed is Dictionary: info = parsed
		var cards: Array = []
		for file: String in DirAccess.get_files_at("%s/%s" % [DECKS_ROOT, folder]):
			# No jogo exportado as imagens aparecem como .png.import/.png.remap.
			var stem := file.trim_suffix(".import").trim_suffix(".remap")
			if not stem.ends_with(".png"): continue
			stem = stem.trim_suffix(".png")
			var id := "%s/%s" % [folder, stem]
			if valid.search(stem) != null and not cards.has(id): cards.append(id)
		cards.sort()
		if cards.size() < 2: continue
		_decks.append({"id": folder, "name": str(info.get("name", folder.replace("_", " ").capitalize())).left(32),
			"order": int(info.get("order", 99)), "cards": cards})
	_decks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.id < b.id if a.order == b.order else a.order < b.order)
	return _decks


func default_settings() -> Dictionary:
	var first: Array = [decks()[0].id] if not decks().is_empty() else []
	return {"max_players": 10, "deck_ids": first, "cards_per_player": 3, "bots_allowed": true, "turn_seconds": 60,
		"selection_seconds": 30, "tiebreak_base": 7, "tiebreak_per_player": 2}


func _decks_json(ids: Array) -> Array:
	var result: Array = []
	for deck: Dictionary in decks():
		if ids.is_empty() or ids.has(deck.id):
			result.append({"id": deck.id, "name": deck.name, "size": (deck.cards as Array).size()})
	return result


func _deck_cards(ids: Array) -> Array:
	var result: Array = []
	for deck: Dictionary in decks():
		if not ids.has(deck.id): continue
		for card: String in deck.cards:
			if not result.has(card): result.append(card)
	result.sort()
	return result


static func _int_ok(settings: Dictionary, key: String, low: int, high: int) -> bool:
	var value: Variant = settings.get(key)
	if not (value is int or value is float): return false
	return float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high


## qse_v3.duel_settings: junta a entrada sobre a base e valida; {} se algo for inválido.
func _settings(input: Variant, base: Dictionary) -> Dictionary:
	var result := (base if not base.is_empty() else default_settings()).duplicate(true)
	if input != null:
		if not input is Dictionary: return {}
		for key: String in input:
			if not SETTING_KEYS.has(key): return {}
			result[key] = input[key]
	if not (_int_ok(result, "max_players", 2, 20) and _int_ok(result, "cards_per_player", 1, 6)
			and _int_ok(result, "turn_seconds", 15, 180) and _int_ok(result, "selection_seconds", 10, 120)
			and _int_ok(result, "tiebreak_base", 4, 12) and _int_ok(result, "tiebreak_per_player", 1, 4)
			and result.get("bots_allowed") is bool and result.get("deck_ids") is Array
			and (result.deck_ids as Array).size() >= 1 and (result.deck_ids as Array).size() <= 5):
		return {}
	var ids: Array = []
	for id: Variant in result.deck_ids:
		if not id is String: return {}
		if not ids.has(id): ids.append(id)
	if _decks_json(ids).size() != ids.size(): return {}
	if _deck_cards(ids).size() < int(result.cards_per_player): return {}
	for key in ["max_players", "cards_per_player", "turn_seconds", "selection_seconds", "tiebreak_base", "tiebreak_per_player"]:
		result[key] = int(result[key])
	ids.sort()
	result.deck_ids = ids
	return result


# --- Estado interno -------------------------------------------------------------------------
func _new_id(prefix: String) -> String:
	_serial += 1
	return "%s-%d" % [prefix, _serial]


func _touch() -> void:
	_room.revision = int(_room.revision) + 1


func _valid_room(id: String) -> bool:
	return not _room.is_empty() and str(_room.id) == id


func _human() -> Dictionary:
	for member: Dictionary in _members:
		if member.user_id == HUMAN: return member
	return {}


func _member(id: String) -> Dictionary:
	for member: Dictionary in _members:
		if str(member.id) == id: return member
	return {}


func _player(member_id: String) -> Dictionary:
	for player: Dictionary in _players:
		if str(player.member_id) == member_id: return player
	return {}


func _player_count() -> int:
	return _members.filter(func(m: Dictionary) -> bool: return m.role == "player").size()


## Sala em que o humano está e que não foi encerrada (qse_v3.duel_lock_member_room).
func _member_room(room_id: String) -> bool:
	return _valid_room(room_id) and _room.status != "closed" and not _human().is_empty()


func _skin() -> String:
	var skin := str(skin_provider.call()) if skin_provider.is_valid() else ""
	return skin if not skin.is_empty() else (str(bot_skins[0]) if not bot_skins.is_empty() else "")


func _nickname() -> String:
	var name := str(nickname_provider.call()) if nickname_provider.is_valid() else ""
	return name if not name.strip_edges().is_empty() else "Você"


## ADM é sempre o humano; sem ele (saiu), a sala é encerrada mesmo com bots (qse_v3.duel_fix_admin).
func _fix_admin() -> void:
	if _room.is_empty() or _room.status == "closed": return
	var human := _human()
	if human.is_empty():
		_room.status = "closed"
		_room.admin_id = null
		_room.match_phase = null
		_room.phase_deadline = null
		_touch()
	elif _room.admin_id != human.id:
		_room.admin_id = human.id
		_touch()


## Quem parou de dar sinal no lobby deixa a sala (qse_v3.duel_sweep).
func _sweep() -> void:
	if _room.is_empty() or _room.status != "lobby": return
	var human := _human()
	if not human.is_empty() and float(human.last_seen) < now() - LOBBY_STALE:
		_members.erase(human)
		_touch()
	_fix_admin()


func _seen() -> void:
	var human := _human()
	if not human.is_empty(): human.last_seen = now()


# --- Partida (qse_v3.duel_* da etapa 2) -----------------------------------------------------
func _set_phase(phase: String, wait: float) -> void:
	_match.phase = phase
	_match.phase_deadline = now() + wait
	_room.match_phase = phase
	_room.phase_deadline = _match.phase_deadline
	_touch()


func _event(kind: String, actor: Variant, card: Variant, hits: Array, suspense: float) -> void:
	var seq := 1 if _events.is_empty() else int(_events.back().seq) + 1
	_events.append({"seq": seq, "kind": kind, "actor": actor, "card_id": card, "hits": hits, "created_at": now(),
		"reveal_at": now() + suspense})


func _eliminate(member_id: String, reason: String) -> bool:
	var player := _player(member_id)
	if player.is_empty() or player.eliminated_reason != null: return false
	player.eliminated_reason = reason
	return true


func _fill_cards(member_id: String) -> void:
	var pool: Array = (_match.pool as Array).duplicate()
	_shuffle(pool)
	_cards[member_id] = pool.slice(0, int(_match.settings.cards_per_player)).map(func(c: String) -> Dictionary:
		return {"card_id": c, "lost": false})


func _shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[other]
		items[other] = held


func _begin_match() -> void:
	var settings: Dictionary = _room.settings
	_match = {"id": _new_id("match"), "phase": "selection", "phase_deadline": now() + int(settings.selection_seconds),
		"settings": settings.duplicate(true), "pool": _deck_cards(settings.deck_ids), "removed": [], "turn_order": [],
		"turn_index": -1, "turn_member": null, "turn_started_at": null, "result": null}
	_players = []
	_cards = {}
	_events = []
	for member: Dictionary in _members:
		if member.role != "player": continue
		var bot: bool = member.user_id == null
		_players.append({"member_id": member.id, "is_bot": bot, "nickname": member.bot_name if bot else _nickname(),
			"skin_id": member.character_id, "lives": int(settings.cards_per_player), "faults": 0, "confirmed": false,
			"auto_selected": false, "eliminated_reason": null})
	# Bots escolhem na hora (cartas aleatórias) e já ficam PRONTOS.
	for player: Dictionary in _players:
		if player.is_bot:
			_fill_cards(player.member_id)
			player.confirmed = true
	_room.status = "in_match"
	_room.match_id = _match.id
	_room.match_phase = "selection"
	_room.phase_deadline = _match.phase_deadline
	_touch()


## Próximo jogador vivo na ordem sorteada (circular).
func _next_turn() -> void:
	var order: Array = _match.turn_order
	for step in range(1, order.size() + 1):
		var candidate := (int(_match.turn_index) + step) % order.size()
		var member: String = order[candidate]
		if _player(member).eliminated_reason == null:
			_match.turn_index = candidate
			_match.turn_member = member
			_match.turn_started_at = now()
			_set_phase("turns", int(_match.settings.turn_seconds))
			return


## Volta ao lobby da mesma sala, com as configurações preservadas.
func _return_to_lobby() -> void:
	_room.status = "lobby"
	_room.match_phase = null
	_room.phase_deadline = null
	_room.match_id = null
	_match = {}
	for member: Dictionary in _members:
		if member.role == "spectator" and _player_count() < int(_room.settings.max_players): member.role = "player"
	_touch()
	_fix_admin()


## Fim (qse_v3.duel_check_end): sem jogador real vivo a sala é encerrada (nunca há bot
## campeão); com 1 vivo, ele vence; com 0, empate.
func _check_end() -> bool:
	var alive := _players.filter(func(p: Dictionary) -> bool: return p.eliminated_reason == null)
	var winners: Array = alive.map(func(p: Dictionary) -> String: return str(p.member_id))
	if alive.filter(func(p: Dictionary) -> bool: return not p.is_bot).is_empty():
		_match.phase = "finished"
		_match.result = {"reason": "only_bots", "winners": []}
		_room.status = "closed"
		_room.match_phase = null
		_room.phase_deadline = null
		_room.admin_id = null
		_touch()
		return true
	if alive.size() <= 1:
		_match.result = {"reason": "last_standing" if alive.size() == 1 else "draw", "winners": winners}
		_event("finished", null, null, winners, 0.0)
		_set_phase("finished", TIMING.finished)
		return true
	return false


## A carta sai do jogo e atinge TODOS os vivos que a têm (inclusive quem escolheu). Cada
## atingido perde a carta e uma vida; sem vidas, é eliminado.
func _pick_card(actor: String, card: String) -> void:
	(_match.removed as Array).append(card)
	var hits: Array = []
	for player: Dictionary in _players:
		if player.eliminated_reason != null: continue
		for owned: Dictionary in _cards.get(player.member_id, []):
			if owned.card_id != card or owned.lost: continue
			owned.lost = true
			player.lives = maxi(int(player.lives) - 1, 0)
			if player.lives == 0: _eliminate(player.member_id, "lives")
			hits.append({"member_id": player.member_id, "lives": player.lives, "eliminated": player.eliminated_reason != null})
	_event("pick", actor, card, hits, TIMING.suspense)
	_set_phase("reveal", TIMING.reveal)


## Turno sem voto: 1ª falta tira uma vida (não tira carta); 2ª falta elimina.
func _apply_timeout(member_id: String) -> void:
	var player := _player(member_id)
	player.faults = mini(int(player.faults) + 1, 2)
	if player.faults >= 2:
		_eliminate(member_id, "faults")
	else:
		player.lives = maxi(int(player.lives) - 1, 0)
		if player.lives == 0: _eliminate(member_id, "lives")
	_event("timeout", member_id, null, [{"member_id": member_id, "lives": player.lives, "faults": player.faults,
		"eliminated": player.eliminated_reason != null}], 0.0)
	_set_phase("reveal", TIMING.timeout)


## Bot: carta disponível ao acaso, evitando as próprias quando possível.
func _bot_choice(member_id: String) -> Variant:
	var available: Array = (_match.pool as Array).filter(func(c: String) -> bool: return not (_match.removed as Array).has(c))
	if available.is_empty(): return null
	var own: Array = (_cards.get(member_id, []) as Array).filter(func(c: Dictionary) -> bool: return not c.lost) \
		.map(func(c: Dictionary) -> String: return str(c.card_id))
	_shuffle(available)
	var others := available.filter(func(c: String) -> bool: return not own.has(c))
	return others[0] if not others.is_empty() else available[0]


## Processa tudo que já venceu, em ordem (qse_v3.duel_advance).
func _advance() -> void:
	if _room.is_empty() or _room.status != "in_match" or _match.is_empty(): return
	var human := _human()
	for player: Dictionary in _players:
		if player.is_bot or player.eliminated_reason != null: continue
		var member := _member(player.member_id)
		if member.is_empty() or float(member.last_seen) < now() - TIMING.disconnect:
			if _eliminate(player.member_id, "disconnect"):
				_event("eliminated", player.member_id, null, [{"member_id": player.member_id, "eliminated": true, "reason": "disconnect"}], 0.0)
				_touch()
	if human.is_empty(): _fix_admin()
	for _guard in range(12):
		if _room.status != "in_match" or _match.is_empty(): return
		var deadline := float(_match.phase_deadline)
		match str(_match.phase):
			"selection":
				var waiting := _players.any(func(p: Dictionary) -> bool: return p.eliminated_reason == null and not p.confirmed)
				if now() < deadline and waiting: return
				for player: Dictionary in _players:
					if not player.confirmed:
						_fill_cards(player.member_id)
						player.confirmed = true
						player.auto_selected = true
				_set_phase("countdown", TIMING.countdown)
			"countdown":
				if now() < deadline: return
				if _check_end(): continue
				var order: Array = _players.filter(func(p: Dictionary) -> bool: return p.eliminated_reason == null) \
					.map(func(p: Dictionary) -> String: return str(p.member_id))
				_shuffle(order)
				_match.turn_order = order
				_match.turn_index = -1
				_next_turn()
			"turns":
				var current := _player(str(_match.turn_member))
				if current.eliminated_reason != null:
					if not _check_end(): _next_turn()
				elif current.is_bot and now() >= float(_match.turn_started_at) + TIMING.bot_think:
					var choice: Variant = _bot_choice(current.member_id)
					if choice == null: _apply_timeout(current.member_id)
					else: _pick_card(current.member_id, choice)
				elif now() >= deadline:
					_apply_timeout(current.member_id)
				else:
					return
			"reveal":
				if now() < deadline: return
				if not _check_end(): _next_turn()
			"finished":
				if now() < deadline: return
				_return_to_lobby()
			_:
				return


# --- Fotografia vista pelo jogador (qse_v3.duel_snapshot / duel_match_json) -----------------
static func _stamp(seconds: float) -> Variant:
	if seconds <= 0.0: return null
	var whole := floori(seconds)
	return "%s.%03d+00:00" % [Time.get_datetime_string_from_unix_time(whole), int((seconds - whole) * 1000.0)]


func _snapshot() -> Dictionary:
	var human := _human()
	var members: Array = []
	for member: Dictionary in _members:
		var bot: bool = member.user_id == null
		members.append({"member_id": member.id, "is_bot": bot, "is_admin": not bot and member.id == _room.admin_id,
			"is_you": not bot, "role": member.role, "character_id": member.character_id,
			"nickname": member.bot_name if bot else _nickname(), "public_id": null, "online": true})
	var room := {"id": _room.id, "code": _room.code, "name": _room.name, "is_public": false, "is_local": true,
		"status": _room.status, "match_phase": _room.match_phase,
		"phase_deadline": _stamp(float(_room.phase_deadline)) if _room.phase_deadline != null else null,
		"settings": _room.settings.duplicate(true), "revision": _room.revision, "decks": _decks_json(_room.settings.deck_ids)}
	return {"room": room, "members": members,
		"you": {"member_id": human.id, "role": human.role, "is_admin": human.id == _room.admin_id} if not human.is_empty() else null,
		"match": _match_json(str(human.get("id", ""))) if _room.match_id != null and not _match.is_empty() else null}


func _match_json(viewer: String) -> Dictionary:
	var order: Array = _match.turn_order
	var players := _players.duplicate()
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia := order.find(a.member_id)
		var ib := order.find(b.member_id)
		if ia != ib: return (ia if ia >= 0 else 9999) < (ib if ib >= 0 else 9999)
		return str(a.nickname) < str(b.nickname))
	var players_json: Array = []
	for player: Dictionary in players:
		var owned: Array = _cards.get(player.member_id, [])
		players_json.append({"member_id": player.member_id, "nickname": player.nickname, "skin_id": player.skin_id,
			"is_bot": player.is_bot, "lives": player.lives, "faults": player.faults, "confirmed": player.confirmed,
			"eliminated": player.eliminated_reason != null, "reason": player.eliminated_reason, "is_you": player.member_id == viewer,
			"cards_left": owned.filter(func(c: Dictionary) -> bool: return not c.lost).size(),
			"lost": owned.filter(func(c: Dictionary) -> bool: return c.lost).map(func(c: Dictionary) -> String: return str(c.card_id))})
	var mine: Array = (_cards.get(viewer, []) as Array).map(func(c: Dictionary) -> Dictionary: return c.duplicate())
	mine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.card_id) < str(b.card_id))
	var events: Array = []
	for event: Dictionary in _events.slice(maxi(_events.size() - 10, 0)):
		var revealed := now() >= float(event.reveal_at)
		events.append({"seq": event.seq, "kind": event.kind, "actor": event.actor, "card_id": event.card_id,
			"at": _stamp(event.created_at), "reveal_at": _stamp(event.reveal_at), "revealed": revealed,
			"hits": (event.hits as Array).duplicate(true) if revealed else null})
	return {"id": _match.id, "phase": _match.phase, "deadline": _stamp(float(_match.phase_deadline)), "server_now": _stamp(now()),
		"turn_member": _match.turn_member, "turn_order": order.duplicate(), "result": _match.result,
		"cards_per_player": int(_match.settings.cards_per_player),
		"pool": (_match.pool as Array).map(func(c: String) -> Dictionary: return {"card_id": c, "removed": (_match.removed as Array).has(c)}),
		"players": players_json, "my_cards": mine, "events": events}


# --- API (mesmos nomes, parâmetros e erros de public.qse_duel_*) ----------------------------
func _create(name: Variant, settings: Variant) -> Dictionary:
	if not name is String or (name as String).strip_edges().length() < 3 or (name as String).strip_edges().length() > 32:
		return {"error": "invalid_room_name"}
	if decks().is_empty(): return {"error": "no_decks"}
	var config := _settings(settings, {})
	if config.is_empty(): return {"error": "invalid_settings"}
	# Uma sala por vez: criar outra sai da anterior.
	if not _room.is_empty(): _leave(str(_room.id))
	var human := {"id": _new_id("member"), "user_id": HUMAN, "bot_name": null, "character_id": _skin(), "role": "player",
		"last_seen": now()}
	_room = {"id": _new_id("local"), "code": "LOCAL", "name": (name as String).strip_edges(), "status": "lobby",
		"match_phase": null, "phase_deadline": null, "admin_id": human.id, "settings": config, "revision": 1, "match_id": null}
	_members = [human]
	_match = {}
	return _snapshot()


func _leave(room_id: String) -> Dictionary:
	if not _valid_room(room_id): return {"left": true}
	var human := _human()
	if human.is_empty(): return {"left": true}
	# Saída voluntária durante a partida elimina (a disputa continua sem ele).
	if _room.status == "in_match" and not _match.is_empty() and _eliminate(human.id, "left"):
		_event("eliminated", human.id, null, [{"member_id": human.id, "eliminated": true, "reason": "left"}], 0.0)
	_members.erase(human)
	_touch()
	_fix_admin()
	_advance()
	return {"left": true}


func _heartbeat(room_id: String) -> Dictionary:
	if not _valid_room(room_id) or _human().is_empty():
		return {"member": false, "status": _room.get("status", "closed") if _valid_room(room_id) else "closed",
			"revision": _room.get("revision", 0) if _valid_room(room_id) else 0}
	_seen()
	_sweep()
	_advance()
	return {"member": not _human().is_empty(), "status": _room.status, "revision": _room.revision, "server_now": _stamp(now())}


func _room_rpc(room_id: String) -> Dictionary:
	if not _valid_room(room_id) or _human().is_empty(): return {"error": "not_member"}
	_seen()
	_advance()
	return _snapshot()


func _configure(room_id: String, name: Variant, settings: Variant) -> Dictionary:
	if not _member_room(room_id): return {"error": "not_member"}
	_seen()
	if _room.status != "lobby": return {"error": "match_in_progress"}
	if name != null and (not name is String or (name as String).strip_edges().length() < 3 or (name as String).strip_edges().length() > 32):
		return {"error": "invalid_room_name"}
	var config := _settings(settings, _room.settings)
	if config.is_empty(): return {"error": "invalid_settings"}
	if int(config.max_players) < _player_count(): return {"error": "max_below_players"}
	if not config.bots_allowed:
		_members = _members.filter(func(m: Dictionary) -> bool: return m.user_id != null)
	_room.settings = config
	if name != null: _room.name = (name as String).strip_edges()
	_touch()
	return _snapshot()


func _add_bot(room_id: String) -> Dictionary:
	if not _member_room(room_id): return {"error": "not_member"}
	_seen()
	if _room.status != "lobby": return {"error": "match_in_progress"}
	if not _room.settings.bots_allowed: return {"error": "bots_disabled"}
	if _player_count() >= int(_room.settings.max_players): return {"error": "room_full"}
	var used: Array = _members.map(func(m: Dictionary) -> Variant: return m.bot_name)
	var label := "Bot"
	for candidate: String in BOT_NAMES:
		if not used.has(candidate):
			label = candidate
			break
	var skin := str(bot_skins[rng.randi_range(0, bot_skins.size() - 1)]) if not bot_skins.is_empty() else ""
	_members.append({"id": _new_id("member"), "user_id": null, "bot_name": label, "character_id": skin, "role": "player",
		"last_seen": now()})
	_touch()
	return _snapshot()


func _kick(room_id: String, member_id: String) -> Dictionary:
	if not _member_room(room_id): return {"error": "not_member"}
	_seen()
	var target := _member(member_id)
	if target.is_empty(): return {"error": "member_not_found"}
	if target.user_id == HUMAN: return {"error": "cannot_kick_self"}
	if _room.status != "lobby" and not _player(member_id).is_empty() and _player(member_id).eliminated_reason == null:
		return {"error": "cannot_kick_active_player"}
	_members.erase(target)
	_touch()
	return _snapshot()


func _start(room_id: String) -> Dictionary:
	if not _member_room(room_id): return {"error": "not_member"}
	_seen()
	if _room.status != "lobby": return {"error": "match_in_progress"}
	_sweep()
	if _player_count() < 2: return {"error": "not_enough_players"}
	_begin_match()
	return _snapshot()


## Seleção secreta: exatamente N cartas distintas dos decks da partida.
func _select(room_id: String, cards: Variant) -> Dictionary:
	_advance()
	if not _member_room(room_id): return {"error": "not_member"}
	_seen()
	if _room.status != "in_match" or _match.is_empty() or _match.phase != "selection": return {"error": "not_selection_phase"}
	var player := _player(str(_human().id))
	if player.is_empty() or player.eliminated_reason != null: return {"error": "not_in_match"}
	if not cards is Array or (cards as Array).size() != int(_match.settings.cards_per_player): return {"error": "invalid_selection"}
	var distinct: Array = []
	for card: Variant in cards:
		if not card is String or distinct.has(card) or not (_match.pool as Array).has(card): return {"error": "invalid_selection"}
		distinct.append(card)
	_cards[player.member_id] = distinct.map(func(c: String) -> Dictionary: return {"card_id": c, "lost": false})
	player.confirmed = true
	_touch()
	_advance()
	return _snapshot()


## Voto do jogador da vez: a carta sai do jogo e atinge todos que a possuem.
func _pick(room_id: String, card: Variant) -> Dictionary:
	_advance()
	if not _member_room(room_id): return {"error": "not_member"}
	_seen()
	if _room.status != "in_match" or _match.is_empty() or _match.phase != "turns": return {"error": "not_your_turn"}
	if str(_human().id) != str(_match.turn_member): return {"error": "not_your_turn"}
	if not card is String or not (_match.pool as Array).has(card) or (_match.removed as Array).has(card):
		return {"error": "card_unavailable"}
	_pick_card(str(_human().id), card)
	return _snapshot()
