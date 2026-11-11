class_name VoiceService
extends Node
## T32: optional LiveKit voice for ONLINE Mata-Mata only.
## The GAME session authorizes every token; only Web uses the JS SDK.
## No LiveKit credential, raw microphone audio or secret is stored in Godot.

signal changed

const POLL_SECONDS := 1.0
const RECONCILE_SECONDS := 30.0

var client: SupabaseClient
var session: SessionService
var duel: DuelService
var state := "off" # off / connecting / connected / error
var error_code := ""
var mic_enabled := false
var audio_muted := false
var audio_blocked := false
var participants: Array = []
## Fala do próprio jogador (evento real do LiveKit).
var self_speaking := false
var room_id := ""
var _epoch := 0
var _reconciling := false
var _reconcile_at := 0.0
var _bridge_started := false
var _access_signature := ""
var _poller: Timer


func _ready() -> void:
	_poller = Timer.new()
	_poller.wait_time = POLL_SECONDS
	_poller.timeout.connect(_poll)
	add_child(_poller)
	_poller.start()
	duel.changed.connect(_room_changed)
	duel.removed.connect(func(_reason: String) -> void: disconnect_voice())
	session.changed.connect(_room_changed)
	_room_changed()


func supported() -> bool:
	return OS.has_feature("web") and not OS.get_cmdline_args().has("--script")


func eligible() -> bool:
	if not supported() or not session.authenticated() or duel.is_local() or not duel.in_room():
		return false
	return str(duel.room.get("room", {}).get("status", "")) in ["lobby", "in_match"]


func _room_changed() -> void:
	if not eligible() or (not room_id.is_empty() and duel.room_id() != room_id):
		disconnect_voice()
	elif _bridge_started and state in ["connected","connecting"]:
		_sync_match_access()
	if state == "connected" and not room_id.is_empty():
		# A room revision (e.g. admin kick) triggers prompt roster reconciliation.
		_reconcile_at = minf(_reconcile_at, Time.get_ticks_msec() / 1000.0 + 3.0)


func _sync_match_access() -> void:
	var silent := []
	for player: Dictionary in duel.match().get("players",[]):
		if player.get("eliminated",false): silent.append(str(player.member_id))
	var signature := JSON.stringify([duel.spectating_match(),silent])
	if signature == _access_signature: return
	_access_signature = signature
	JavaScriptBridge.eval("window.QSEVoice.setMatchAccess.apply(null," + signature + ")")
	_reconcile_at = 0.0
	if duel.spectating_match():
		mic_enabled = false
		self_speaking = false
	changed.emit()

## Called explicitly by a player button; no background or lobby auto-join.
func join_voice() -> void:
	if not eligible() or state == "connecting" or state == "connected":
		return
	_epoch += 1
	var operation := _epoch
	room_id = duel.room_id()
	# Não deixe o polling do bridge anterior sobrescrever uma nova tentativa.
	_bridge_started = false
	state = "connecting"
	error_code = ""
	changed.emit()
	var result := await client.request(
		"/functions/v1/qse-voice-token",
		HTTPClient.METHOD_POST,
		{"action": "join", "room_id": room_id}
	)
	if operation != _epoch:
		return
	if not eligible() or duel.room_id() != room_id:
		disconnect_voice()
		return
	if not result.ok:
		_fail(str(result.get("code", "token_unavailable")))
		return
	if not result.data is Dictionary:
		_fail("invalid_token_response")
		return
	var data: Dictionary = result.data
	var url := str(data.get("server_url", ""))
	var token := str(data.get("participant_token", ""))
	if not url.begins_with("wss://") or token.is_empty():
		_fail("invalid_token_response")
		return
	if not bool(JavaScriptBridge.eval("typeof window.QSEVoice === 'object' && window.QSEVoice !== null", true)):
		_fail("bridge_unavailable")
		return
	_bridge_started = true
	_access_signature = ""
	_sync_match_access()
	JavaScriptBridge.eval("window.QSEVoice.join(" + JSON.stringify(url) + "," + JSON.stringify(token) + "," + JSON.stringify(data.get("participants", [])) + ")")
	_reconcile_at = Time.get_ticks_msec() / 1000.0 + RECONCILE_SECONDS


func _fail(code: String) -> void:
	state = "error"
	error_code = code
	changed.emit()


func disconnect_voice() -> void:
	var prior_room := room_id
	_epoch += 1
	if supported() and _bridge_started:
		JavaScriptBridge.eval("window.QSEVoice && window.QSEVoice.leave()")
	_bridge_started = false
	room_id = ""
	state = "off"
	error_code = ""
	mic_enabled = false
	audio_muted = false
	audio_blocked = false
	participants = []
	self_speaking = false
	changed.emit()
	# Revoke OUR LiveKit token even if GAME has already removed our membership.
	if not prior_room.is_empty() and session.authenticated() and not duel.is_local():
		client.request("/functions/v1/qse-voice-token", HTTPClient.METHOD_POST,
			{"action": "leave", "room_id": prior_room})


func toggle_microphone() -> void:
	if state != "connected" or not supported() or duel.spectating_match(): return
	JavaScriptBridge.eval("window.QSEVoice.setMic(" + str(not mic_enabled).to_lower() + ")")


func toggle_audio() -> void:
	if state != "connected" or not supported(): return
	JavaScriptBridge.eval("window.QSEVoice.setAudioMuted(" + str(not audio_muted).to_lower() + ")")


func unlock_audio() -> void:
	if state != "connected" or not supported(): return
	JavaScriptBridge.eval("window.QSEVoice.unlockAudio()")


func set_player_volume(identity: String, volume: float) -> void:
	if state != "connected" or not supported() or identity.length() != 64: return
	JavaScriptBridge.eval("window.QSEVoice.setPlayerVolume(" + JSON.stringify(identity) + "," + str(clampf(volume, 0.0, 1.0)) + ")")


func _poll() -> void:
	if not supported() or room_id.is_empty() or not _bridge_started: return
	if not eligible() or duel.room_id() != room_id:
		disconnect_voice()
		return
	var raw: Variant = JavaScriptBridge.eval(
		"window.QSEVoice ? JSON.stringify(window.QSEVoice.snapshot()) : ''", true)
	if not raw is String: return
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary: return
	var updated := "connected" if bool(parsed.get("connected", false)) else (
		"error" if str(parsed.get("status", "")) == "error" else "connecting")
	var next_error := str(parsed.get("error", ""))
	var next_mic := bool(parsed.get("mic", false))
	var next_audio := bool(parsed.get("audioMuted", false))
	var next_blocked := bool(parsed.get("audioBlocked", false))
	var next_players: Array = parsed.get("participants", []) if parsed.get("participants", []) is Array else []
	var next_self := bool(parsed.get("selfSpeaking", false))
	if state != updated or error_code != next_error or mic_enabled != next_mic or audio_muted != next_audio or audio_blocked != next_blocked or participants != next_players or self_speaking != next_self:
		self_speaking = next_self
		state = updated
		error_code = next_error
		mic_enabled = next_mic
		audio_muted = next_audio
		audio_blocked = next_blocked
		participants = next_players
		changed.emit()
	if state == "connected" and not _reconciling and Time.get_ticks_msec() / 1000.0 >= _reconcile_at:
		_reconcile.call_deferred()


func _reconcile() -> void:
	if _reconciling or state != "connected" or not eligible(): return
	_reconciling = true
	var target := room_id
	_reconcile_at = Time.get_ticks_msec() / 1000.0 + RECONCILE_SECONDS
	var result := await client.request("/functions/v1/qse-voice-token",
		HTTPClient.METHOD_POST, {"action": "reconcile", "room_id": target})
	_reconciling = false
	if target != room_id: return
	if result.ok and result.data is Dictionary:
		JavaScriptBridge.eval("window.QSEVoice && window.QSEVoice.setRoster(" + JSON.stringify(result.data.get("participants", [])) + ")")
	if not result.ok:
		# Fail closed for loss of GAME room authorization. A 503 does not interrupt
		# gameplay but voice is dropped until the player explicitly rejoins.
		disconnect_voice()
		_fail("voice_access_lost")
