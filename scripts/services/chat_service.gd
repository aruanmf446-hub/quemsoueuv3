class_name ChatService
extends Node
## Cliente do CHAT (conexão "chat"). DESATIVADO: o backend ainda não verifica a identidade
## do GAME, então nada é enviado nem lido (enabled = false). Quando ativado, as mensagens
## serão temporárias: ficam só em memória e expiram após MESSAGE_TTL, sem salvar em disco e
## sem consultar o GAME a cada mensagem (o remetente vem da própria mensagem do CHAT).

signal changed

const MESSAGE_TTL := 15 * 60.0
const MAX_MESSAGES := 200
var client: SupabaseClient
var enabled := false
## conversation_id -> [{"id", "sender", "text", "at"}], mais antigas primeiro.
var _messages: Dictionary = {}


func send(_conversation_id: String, _text: String) -> Dictionary:
	# Envio só depois da identidade verificada no servidor do CHAT.
	return ServiceResult.failure("chat_unavailable", "offline")


## Guarda uma mensagem recebida do CHAT; descarta repetidas, vencidas e o excesso.
func receive(conversation_id: String, message: Dictionary) -> void:
	if not enabled: return
	var list: Array = _messages.get(conversation_id, [])
	if list.any(func(m: Dictionary) -> bool: return m.id == message.get("id")): return
	list.append(message)
	_messages[conversation_id] = list
	prune()
	changed.emit()


func messages(conversation_id: String) -> Array:
	prune()
	return (_messages.get(conversation_id, []) as Array).duplicate()


func prune() -> void:
	var limit := Time.get_unix_time_from_system() - MESSAGE_TTL
	for id: String in _messages.keys():
		var kept: Array = (_messages[id] as Array).filter(func(m: Dictionary) -> bool: return float(m.get("at", 0.0)) >= limit)
		_messages[id] = kept.slice(maxi(kept.size() - MAX_MESSAGES, 0))
		if (_messages[id] as Array).is_empty(): _messages.erase(id)


func clear() -> void:
	_messages.clear()
	changed.emit()
