class_name DuelService
extends Node
## Duelo, etapa 1: salas online no Supabase (funções public.qse_duel_*). O servidor decide
## tudo; aqui só pedimos ações e mantemos a sala atual em dia. Enquanto o jogador está numa
## sala, um sinal de vida a cada 2 s mantém a presença e avisa quando a sala mudou
## (revisão); só então a sala inteira é buscada de novo.

signal changed
## Saiu da sala sem pedir: "closed" (sala encerrada), "removed" (expulso ou caiu do lobby).
signal removed(reason: String)

const HEARTBEAT_SECONDS := 2.0
var client: SupabaseClient
var session: SessionService
## Última sala recebida do servidor ({} = fora de sala).
var room: Dictionary = {}
var decks: Array = []
var defaults: Dictionary = {}
var _beat: Timer
var _beating := false
var _received_at := -1.0


func _ready() -> void:
	_beat = Timer.new()
	_beat.wait_time = HEARTBEAT_SECONDS
	_beat.timeout.connect(_heartbeat)
	add_child(_beat)


func in_room() -> bool:
	return not room.is_empty()


func room_id() -> String:
	return str(room.get("room", {}).get("id", ""))


func me() -> Dictionary:
	return room.get("you", {}) if room.get("you") is Dictionary else {}


func is_admin() -> bool:
	return bool(me().get("is_admin", false))


func clear() -> void:
	room = {}
	_beat.stop()
	changed.emit()


func load_decks() -> Dictionary:
	var result := await client.call_rpc("qse_duel_decks")
	if result.ok and result.data is Dictionary:
		decks = result.data.get("decks", [])
		defaults = result.data.get("defaults", {})
	return result


func list_rooms(term: String, only_open: bool) -> Dictionary:
	return await client.call_rpc("qse_duel_list", {"p_term": term.strip_edges(), "p_only_open": only_open})


func create(name: String, public: bool, settings: Dictionary) -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_create", {"p_name": name.strip_edges(), "p_public": public, "p_settings": settings}))


func join(code: String) -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_join", {"p_code": code}))


func configure(name: Variant, public: Variant, settings: Dictionary) -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_configure", {"p_room": room_id(), "p_name": name, "p_public": public, "p_settings": settings}))


func add_bot() -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_add_bot", {"p_room": room_id()}))


func kick(member_id: String) -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_kick", {"p_room": room_id(), "p_member": member_id}))


func start() -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_start", {"p_room": room_id()}))


## Seleção secreta: exatamente N cartas distintas dos decks da sala.
func select_cards(cards: Array) -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_select", {"p_room": room_id(), "p_cards": cards}))


## Voto do jogador da vez.
func pick(card_id: String) -> Dictionary:
	return _apply(await client.call_rpc("qse_duel_pick", {"p_room": room_id(), "p_card": card_id}))


## Imagem e nome de uma carta "<deck>/<arquivo>" (assets/duel/decks/<deck>/<arquivo>.png).
static var _deck_info := {}
static func card_texture(card_id: String) -> Texture2D:
	var path := "res://assets/duel/decks/%s.png" % card_id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func card_name(card_id: String) -> String:
	var deck := card_id.get_slice("/", 0)
	var file := card_id.get_slice("/", 1)
	if not _deck_info.has(deck):
		var path := "res://assets/duel/decks/%s/deck.json" % deck
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_deck_info[deck] = parsed if parsed is Dictionary else {}
	var names: Variant = _deck_info[deck].get("cards", {})
	if names is Dictionary and names.has(file): return str(names[file])
	return file.replace("_", " ").capitalize()


func match() -> Dictionary:
	return room.get("match") if room.get("match") is Dictionary else {}


## Segundos até o prazo da fase atual, pelo relógio do servidor (o do aparelho pode estar
## adiantado ou atrasado): diferença calculada na chegada e descontada localmente.
func seconds_left() -> float:
	var data := match()
	if data.is_empty() or _received_at < 0.0: return 0.0
	var remaining := _timestamp(str(data.get("deadline", ""))) - _timestamp(str(data.get("server_now", "")))
	return maxf(remaining - (Time.get_ticks_msec() / 1000.0 - _received_at), 0.0)


## "2026-10-30T04:20:52.35+00:00": segundos com fração. Fuso igual nos dois carimbos
## (vêm do mesmo servidor), então ele se cancela na diferença.
static func _timestamp(text: String) -> float:
	if text.length() < 19: return 0.0
	var seconds := float(Time.get_unix_time_from_datetime_string(text.substr(0, 19)))
	if text.length() > 19 and text[19] == ".":
		var digits := ""
		for index in range(20, text.length()):
			if not text[index].is_valid_int(): break
			digits += text[index]
		if not digits.is_empty(): seconds += float("0." + digits)
	return seconds


func refresh() -> Dictionary:
	if not in_room(): return ServiceResult.failure("not_member")
	return _apply(await client.call_rpc("qse_duel_room", {"p_room": room_id()}))


func leave() -> Dictionary:
	if not in_room(): return ServiceResult.success({})
	var id := room_id()
	clear()
	return await client.call_rpc("qse_duel_leave", {"p_room": id})


## Toda resposta com sala vira o estado atual; o sinal de vida começa/continua.
func _apply(result: Dictionary) -> Dictionary:
	if result.ok:
		if not result.data is Dictionary or not result.data.get("room") is Dictionary:
			return ServiceResult.failure("invalid_contract")
		room = result.data
		_received_at = Time.get_ticks_msec() / 1000.0
		# Durante a partida o sinal de vida é mais frequente: turnos e revelações têm prazo curto.
		_beat.wait_time = 1.0 if str(room.room.get("status", "")) == "in_match" else HEARTBEAT_SECONDS
		if _beat.is_stopped(): _beat.start()
		changed.emit()
	return result


func _heartbeat() -> void:
	if _beating or not in_room(): return
	_beating = true
	var id := room_id()
	var result := await client.call_rpc("qse_duel_heartbeat", {"p_room": id})
	_beating = false
	if not result.ok or not result.data is Dictionary or id != room_id(): return
	if not bool(result.data.get("member", false)):
		var reason := "closed" if str(result.data.get("status", "")) == "closed" else "removed"
		clear()
		removed.emit(reason)
	elif int(result.data.get("revision", 0)) != int(room.room.get("revision", 0)):
		await refresh()


static func message(code: String) -> String:
	match code:
		"room_not_found": return "Nenhuma sala com esse código."
		"room_closed": return "Esta sala foi encerrada."
		"room_full": return "A sala está cheia."
		"kicked": return "Você foi removido desta sala pelo administrador."
		"not_admin": return "Só o administrador pode fazer isso."
		"match_in_progress": return "A partida já começou."
		"invalid_room_name": return "Use de 3 a 32 caracteres no nome da sala."
		"invalid_settings": return "Confira as configurações da sala."
		"max_below_players": return "Já há mais participantes do que esse limite."
		"bots_disabled": return "Bots estão desativados nesta sala."
		"not_enough_players": return "São necessários pelo menos 2 participantes."
		"cannot_kick_active_player": return "Durante a partida, só espectadores podem ser removidos."
		"cannot_kick_self": return "Você não pode remover a si mesmo."
		"not_member": return "Você não está mais nesta sala."
		"invalid_selection": return "Escolha a quantidade certa de cartas diferentes."
		"no_decks": return "Nenhum deck de cartas foi publicado no servidor ainda."
		"not_selection_phase": return "A seleção de cartas já terminou."
		"not_in_match": return "Você não está participando desta partida."
		"not_your_turn": return "Não é a sua vez."
		"card_unavailable": return "Essa carta já foi eliminada."
	return ServiceResult.message({"code": code})
