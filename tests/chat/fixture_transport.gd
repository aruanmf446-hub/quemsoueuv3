extends Node
## FIXTURE DE TESTE: imita o qse-chat-gateway (CHAT_API_V1) em memória. Não é usado pelo jogo.
var calls: Dictionary = {"open": 0, "messages": 0, "send": 0}
## Próximo erro a devolver (código do jogo), consumido na próxima chamada.
var fail_next := ""
var friends: Array = []
var conversations: Dictionary = {}
var store: Dictionary = {}
var request_ids: Dictionary = {}
var delay_frames := 1


func open_conversation(friend_id: String) -> Dictionary:
	calls.open += 1
	await _wait()
	if _failing(): return ServiceResult.failure(_take())
	if not friends.has(friend_id): return ServiceResult.failure("not_friend")
	if not conversations.has(friend_id): conversations[friend_id] = "conv-" + friend_id
	return ServiceResult.success({"conversation_id": conversations[friend_id]})


## Salas em que o jogador da fixture é membro (o GAME real confirma isso).
var rooms: Array = []
func open_room(room_id: String) -> Dictionary:
	calls.open += 1
	await _wait()
	if _failing(): return ServiceResult.failure(_take())
	if not rooms.has(room_id): return ServiceResult.failure("room_access_denied")
	return ServiceResult.success({"conversation_id": "room-" + room_id})


func list_messages(conversation_id: String, _after: Variant = null) -> Dictionary:
	calls.messages += 1
	await _wait()
	if _failing(): return ServiceResult.failure(_take())
	var now := Time.get_unix_time_from_system()
	var valid: Array = (store.get(conversation_id, []) as Array).filter(func(m: Dictionary) -> bool: return m.expires_at > now)
	return ServiceResult.success({"messages": valid.slice(maxi(valid.size() - 50, 0)), "complete": true})


func send_message(conversation_id: String, request_id: String, text: String, me_id: String = "") -> Dictionary:
	calls.send += 1
	await _wait()
	if _failing(): return ServiceResult.failure(_take())
	if request_ids.has(request_id): return ServiceResult.success({"message": request_ids[request_id], "duplicate": true})
	var message := deliver(conversation_id, me_id, text)
	request_ids[request_id] = message
	return ServiceResult.success({"message": message, "duplicate": false})


## Mensagem chegando (do amigo, ou com horário no passado para testar expiração).
func deliver(conversation_id: String, sender: String, text: String, age := 0.0) -> Dictionary:
	var sent := Time.get_unix_time_from_system() - age
	var list: Array = store.get(conversation_id, [])
	var message := {"id": "m%d" % (list.size() + 1 + randi() % 100000), "sender_id": sender, "text": text,
		"created_at": sent, "expires_at": sent + 24 * 3600.0}
	list.append(message)
	store[conversation_id] = list
	return message


func _wait() -> void:
	for _frame in range(delay_frames): await get_tree().process_frame


func _failing() -> bool:
	return not fail_next.is_empty()


func _take() -> String:
	var code := fail_next
	fail_next = ""
	return code
