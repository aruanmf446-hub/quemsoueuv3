class_name FriendPresence
extends Node

## Realtime Presence em canais privados. O dono vem do tópico autorizado pelo RLS,
## nunca de metadados enviados por outro cliente. Sem conexão, presença é desconhecida.
var client: SupabaseClient
var friends: FriendsService
var session: SessionService
var _socket: WebSocketPeer
var _topics: Dictionary = {}
var _pending: Dictionary = {}
var _members: Dictionary = {}
var _reference := 0
var _heartbeat_at := 0.0
var _reply_deadline := 0.0
var _retry_at := 0.0
var _running := false
var _generation := 0


func _ready() -> void:
	friends.changed.connect(_reconcile)


func start() -> void:
	stop()
	if not session.authenticated() or friends.state != "success":
		return
	_running = true
	_generation = client.generation
	_connect_socket()


func stop() -> void:
	_running = false
	if _socket != null:
		_socket.close()
	_socket = null
	_topics.clear()
	_pending.clear()
	_members.clear()
	friends.online_ids.clear()
	friends.presence_known.clear()
	friends.presence_connected = false
	friends.changed.emit()


func _connect_socket() -> void:
	_socket = WebSocketPeer.new()
	var url := client.endpoint.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + client.publishable_key.uri_encode() + "&vsn=1.0.0"
	if _socket.connect_to_url(url) != OK:
		_disconnected()
	_reply_deadline = Time.get_ticks_msec() / 1000.0 + 15.0


func _process(_delta: float) -> void:
	if not _running:
		return
	if _generation != client.generation or not session.authenticated():
		stop()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _socket == null:
		if now >= _retry_at:
			_connect_socket()
		return
	_socket.poll()
	var ready := _socket.get_ready_state()
	if ready == WebSocketPeer.STATE_CLOSED or now > _reply_deadline:
		_disconnected()
		return
	if ready != WebSocketPeer.STATE_OPEN:
		return
	if _topics.is_empty():
		_reconcile()
		_heartbeat_at = now
	if now - _heartbeat_at >= 25.0:
		_send("phoenix", "heartbeat", {})
		_heartbeat_at = now
	while _socket.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
		if message is Dictionary:
			_receive(message)


func _reconcile() -> void:
	if not _running or _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var wanted := {str(session.user.id): true}
	for friend: Dictionary in friends.data.get("friends", []):
		wanted[str(friend.user_id)] = true
	for owner: String in _topics.keys():
		if not wanted.has(owner):
			_send(_topics[owner], "phx_leave", {})
			_topics.erase(owner)
			friends.online_ids.erase(owner)
			friends.presence_known.erase(owner)
			_members.erase(owner)
	for owner: String in wanted:
		if _topics.has(owner):
			continue
		var topic := "realtime:friend-presence:" + owner
		_topics[owner] = topic
		var reference := _send(topic, "phx_join", {"config": {"private": true,
			"presence": {"key": owner}, "broadcast": {"ack": false, "self": false}},
			"access_token": client.access_token})
		_pending[reference] = owner


func _send(topic: String, event: String, payload: Dictionary) -> String:
	_reference += 1
	var reference := str(_reference)
	_socket.send_text(JSON.stringify({"topic": topic, "event": event, "payload": payload, "ref": reference}))
	return reference


func _receive(message: Dictionary) -> void:
	var event := str(message.get("event", ""))
	var topic := str(message.get("topic", ""))
	var owner := topic.trim_prefix("realtime:friend-presence:")
	var payload: Dictionary = message.get("payload", {})
	if event == "phx_reply":
		_reply_deadline = Time.get_ticks_msec() / 1000.0 + 55.0
		var reference := str(message.get("ref", ""))
		if _pending.has(reference):
			var joined_owner: String = _pending[reference]
			_pending.erase(reference)
			if payload.get("status") != "ok":
				_disconnected()
				return
			if joined_owner == str(session.user.id):
				_send(topic, "presence", {"type": "presence", "event": "track", "payload": {}})
	elif event in ["phx_error", "phx_close"]:
		_disconnected()
	elif _topics.has(owner) and event == "presence_state":
		_members[owner] = {}
		_merge_members(owner, payload, false)
		_publish(owner)
	elif _topics.has(owner) and event == "presence_diff":
		if not _members.has(owner):
			return
		_merge_members(owner, payload.get("joins", {}), false)
		_merge_members(owner, payload.get("leaves", {}), true)
		_publish(owner)


func _merge_members(owner: String, payload: Dictionary, removing: bool) -> void:
	for key: String in payload:
		var group: Variant = payload[key]
		if not group is Dictionary:
			continue
		for meta: Dictionary in group.get("metas", []):
			var reference := str(meta.get("phx_ref", ""))
			if removing:
				_members[owner].erase(reference)
			else:
				_members[owner][reference] = true


func _publish(owner: String) -> void:
	friends.presence_known[owner] = true
	if _members[owner].is_empty():
		friends.online_ids.erase(owner)
	else:
		friends.online_ids[owner] = true
	friends.presence_connected = friends.presence_known.size() >= _topics.size()
	friends.changed.emit()


func _disconnected() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_topics.clear()
	_pending.clear()
	_members.clear()
	friends.online_ids.clear()
	friends.presence_known.clear()
	friends.presence_connected = false
	_retry_at = Time.get_ticks_msec() / 1000.0 + 10.0
	friends.changed.emit()
