class_name ChatService
extends Node
## CHAT privado entre amigos. Identidade e amigos vêm do GAME (já em cache no FriendsService);
## conversas e mensagens vêm do CHAT por um transporte. O transporte real é o gateway
## qse-chat-gateway (Tarefa 16A); enquanto o contrato não estiver publicado e validado,
## `gateway_ready()` é falso e nada é enviado nem consultado. Testes usam um transporte local.
##
## Economia: só consulta com uma conversa ABERTA e o jogo em primeiro plano; uma requisição
## por vez; intervalo cresce quando não chegam mensagens; só pede mensagens novas (after).
## Histórico temporário: só em memória, respeita expires_at do servidor (24 h) e é limpo ao
## trocar de conta.

signal changed
## Uma mensagem nova chegou ou saiu (a tela atualiza só a conversa aberta).
signal messages_changed(conversation_id: String)

const SERVER_RETENTION := 24 * 3600.0
const MAX_MESSAGES := 200
const MAX_LENGTH := 500
## Intervalos de consulta com a conversa aberta: começa rápido e cresce sem atividade.
const POLL_ACTIVE := 3.0
const POLL_IDLE_MAX := 20.0
const POLL_ERROR := 15.0

var client: SupabaseClient
## Transporte: objeto com open_conversation(friend_id), list_messages(conversation_id, after),
## send_message(conversation_id, client_id, text). Cada um devolve um ServiceResult.
var transport: Object
var me_id := ""
## "closed" | "loading" | "ready" | "error" | "unavailable"
var state := "closed"
var error_code := ""
var friend: Dictionary = {}
var conversation_id := ""
var sending := false

var _messages: Dictionary = {}
var _conversations: Dictionary = {}
var _inflight := false
var _pending_ids: Dictionary = {}
var _focused := true
var _poll_wait := POLL_ACTIVE
var _next_poll := INF
var _epoch := 0


func gateway_ready() -> bool:
	return transport != null


## Abre (ou recupera) a conversa com um amigo autorizado. Não cria duplicadas: o id da
## conversa fica em cache por amigo e o servidor devolve a existente.
func open(friend_data: Dictionary) -> Dictionary:
	_epoch += 1
	var epoch := _epoch
	friend = friend_data
	conversation_id = ""
	error_code = ""
	if not gateway_ready():
		state = "unavailable"
		changed.emit()
		return ServiceResult.failure("chat_unavailable", "offline")
	var friend_id := str(friend_data.get("user_id", ""))
	if friend_id.is_empty():
		return _fail("not_friend")
	state = "loading"
	changed.emit()
	if _conversations.has(friend_id):
		conversation_id = _conversations[friend_id]
	else:
		var opened: Dictionary = await transport.open_conversation(friend_id)
		if epoch != _epoch: return opened
		if not opened.ok: return _fail(str(opened.code))
		conversation_id = str((opened.data as Dictionary).get("conversation_id", ""))
		if conversation_id.is_empty(): return _fail("invalid_contract")
		_conversations[friend_id] = conversation_id
	state = "ready"
	_poll_wait = POLL_ACTIVE
	changed.emit()
	await poll()
	return ServiceResult.success({"conversation_id": conversation_id})


## Fecha a conversa: as consultas param na hora.
func close() -> void:
	_epoch += 1
	friend = {}
	conversation_id = ""
	state = "closed"
	_next_poll = INF
	changed.emit()


func is_open() -> bool:
	return not conversation_id.is_empty() and state == "ready"


## Busca só mensagens novas da conversa aberta. Ignorado se fechada, em segundo plano ou
## com outra consulta em andamento.
func poll() -> Dictionary:
	if not is_open() or not _focused or _inflight: return ServiceResult.failure("skipped")
	_inflight = true
	var epoch := _epoch
	var id := conversation_id
	var list: Array = _messages.get(id, [])
	var after: Variant = list.back().id if not list.is_empty() else null
	var result: Dictionary = await transport.list_messages(id, after)
	_inflight = false
	if epoch != _epoch or id != conversation_id: return result
	if not result.ok:
		error_code = str(result.code)
		if error_code in ["not_friend", "conversation_unavailable", "not_authenticated"]: state = "error"
		_schedule(POLL_ERROR)
		changed.emit()
		return result
	error_code = ""
	var added := _merge(id, (result.data as Dictionary).get("messages", []))
	_schedule(POLL_ACTIVE if added > 0 else minf(_poll_wait * 1.6, POLL_IDLE_MAX))
	if added > 0 or prune(): messages_changed.emit(id)
	return result


## Envia uma mensagem. Vazias, longas demais e repetidas enquanto a anterior não volta
## não são enviadas. O client_id permite ao servidor ignorar reenvios.
func send(text: String) -> Dictionary:
	text = text.strip_edges()
	if text.is_empty(): return ServiceResult.failure("empty_message")
	if text.length() > MAX_LENGTH: return ServiceResult.failure("message_too_long")
	if not is_open(): return ServiceResult.failure("chat_unavailable", "offline")
	if sending: return ServiceResult.failure("duplicate_send")
	sending = true
	changed.emit()
	var id := conversation_id
	var client_id := PlayerContracts.uuid()
	_pending_ids[client_id] = true
	var result: Dictionary = await transport.send_message(id, client_id, text)
	_pending_ids.erase(client_id)
	sending = false
	if result.ok and id == conversation_id:
		var message: Variant = (result.data as Dictionary).get("message")
		if message is Dictionary: _merge(id, [message])
		_poll_wait = POLL_ACTIVE
		_schedule(POLL_ACTIVE)
		messages_changed.emit(id)
	elif not result.ok:
		error_code = str(result.code)
	changed.emit()
	return result


func messages(id: String = conversation_id) -> Array:
	return (_messages.get(id, []) as Array).duplicate()


func is_mine(message: Dictionary) -> bool:
	return not me_id.is_empty() and str(message.get("sender_id", "")) == me_id


## Remove mensagens vencidas (expires_at do servidor, ou 24 h da criação). Devolve se mudou.
func prune() -> bool:
	var now := Time.get_unix_time_from_system()
	var changed_any := false
	for id: String in _messages.keys():
		var kept: Array = (_messages[id] as Array).filter(func(m: Dictionary) -> bool: return _expires(m) > now)
		kept = kept.slice(maxi(kept.size() - MAX_MESSAGES, 0))
		if kept.size() != (_messages[id] as Array).size(): changed_any = true
		_messages[id] = kept
	return changed_any


## Troca de conta ou saída: nada da conversa anterior fica em memória.
func clear() -> void:
	_epoch += 1
	_messages.clear()
	_conversations.clear()
	_pending_ids.clear()
	friend = {}
	conversation_id = ""
	sending = false
	state = "closed"
	error_code = ""
	_next_poll = INF
	changed.emit()


func _process(_delta: float) -> void:
	if is_open() and _focused and Time.get_ticks_msec() / 1000.0 >= _next_poll:
		_next_poll = INF
		poll()
	if not _messages.is_empty() and Engine.get_process_frames() % 120 == 0 and prune():
		messages_changed.emit(conversation_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		if is_open(): _schedule(0.0)


func _schedule(wait: float) -> void:
	_poll_wait = maxf(wait, POLL_ACTIVE) if wait > 0.0 else _poll_wait
	_next_poll = Time.get_ticks_msec() / 1000.0 + wait


func _merge(id: String, incoming: Array) -> int:
	var list: Array = _messages.get(id, [])
	var known := {}
	for message: Dictionary in list: known[str(message.id)] = true
	var added := 0
	for message: Variant in incoming:
		if not message is Dictionary or not (message as Dictionary).has("id") or not (message as Dictionary).get("text") is String: continue
		if known.has(str(message.id)): continue
		known[str(message.id)] = true
		list.append(message)
		added += 1
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("created_at", 0)) < float(b.get("created_at", 0)))
	_messages[id] = list
	prune()
	return added


static func _expires(message: Dictionary) -> float:
	if message.get("expires_at") is float or message.get("expires_at") is int: return float(message.expires_at)
	return float(message.get("created_at", 0)) + SERVER_RETENTION


func _fail(code: String) -> Dictionary:
	error_code = code
	state = "error"
	changed.emit()
	return ServiceResult.failure(code)


## Texto curto para a tela (sem detalhes técnicos).
static func message_for(code: String) -> String:
	match code:
		"chat_unavailable": return "O chat ainda não está disponível."
		"network", "timeout": return "Sem conexão. Tentando de novo…"
		"not_authenticated", "session_changed": return "Sua sessão expirou. Entre novamente."
		"not_friend": return "Vocês não são mais amigos."
		"conversation_unavailable": return "Esta conversa não está disponível."
		"message_blocked": return "Mensagem não enviada."
		"rate_limit": return "Muitas mensagens. Aguarde um pouco."
		"duplicate_send": return "Enviando a mensagem anterior…"
		"empty_message": return "Escreva uma mensagem."
		"message_too_long": return "Mensagem longa demais."
	return "Não foi possível falar com o chat agora."
