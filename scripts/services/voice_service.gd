class_name VoiceService
extends Node
## LiveKit no Web: áudio é opcional e isolado da lógica da partida.
## Não guarda o token em arquivo e nunca conecta em partidas locais.
signal changed

var client: SupabaseClient
var session: SessionService
var duel: DuelService
var state := "idle"
var error_code := ""
var microphone_on := false
var received_muted := false
var participants: Array = []

var _room_id := ""
var _requesting := false
var _generation := 0
var _poll: Timer
var _sync_elapsed := 0.0

func _ready() -> void:
    _poll = Timer.new()
    _poll.wait_time = 1.0
    _poll.timeout.connect(_tick)
    add_child(_poll)
    _poll.start()
    duel.changed.connect(_room_changed)
    duel.removed.connect(func(_reason: String) -> void: leave_voice())
    session.changed.connect(leave_voice)

func supported() -> bool:
    if not OS.has_feature("web") or OS.get_cmdline_args().has("--script"):
        return false
    return bool(JavaScriptBridge.eval("!!window.QSEVoice", true))

func eligible() -> bool:
    return supported() and session.authenticated() and not duel.is_local() and duel.in_room() and str(duel.room.get("room", {}).get("status", "")) in ["lobby", "in_match"]

func connect_voice() -> void:
    if _requesting or not eligible() or state in ["connected", "connecting", "reconnecting"]:
        return
    var id := duel.room_id()
    _generation += 1
    var attempt := _generation
    _requesting = true
    state = "connecting"
    error_code = ""
    changed.emit()
    var result := await client.send("/functions/v1/qse-voice-token", HTTPClient.METHOD_POST, {"room_id": id, "action": "token"})
    _requesting = false
    if attempt != _generation or not eligible() or id != duel.room_id():
        return
    if not result.ok or not result.data is Dictionary:
        state = "error"
        error_code = str(result.code)
        changed.emit()
        return
    var payload: Variant = result.data.get("data", {})
    if not payload is Dictionary or not str(payload.get("server_url", "")).begins_with("wss://") or str(payload.get("participant_token", "")).is_empty():
        state = "error"
        error_code = "invalid_voice_response"
        changed.emit()
        return
    _room_id = id
    # JSON.stringify escapa strings recebidas antes de enviá-las à ponte JavaScript.
    var url := JSON.stringify(str(payload.get("server_url", "")))
    var token := JSON.stringify(str(payload.get("participant_token", "")))
    JavaScriptBridge.eval("window.QSEVoice.connect(%s,%s)" % [url, token], true)
    changed.emit()

func leave_voice() -> void:
    var old_room := _room_id
    _generation += 1
    _room_id = ""
    _requesting = false
    _sync_elapsed = 0.0
    state = "idle"
    error_code = ""
    microphone_on = false
    participants.clear()
    if supported():
        JavaScriptBridge.eval("window.QSEVoice.disconnect()", true)
    changed.emit()
    # Conexão já foi encerrada no cliente: solicitar revogação best-effort.
    if not old_room.is_empty() and session.authenticated() and client != null:
        client.send("/functions/v1/qse-voice-token", HTTPClient.METHOD_POST, {"room_id": old_room, "action": "disconnect"})

func _room_changed() -> void:
    if not _room_id.is_empty() and (not eligible() or duel.room_id() != _room_id):
        disconnect()

func _tick() -> void:
    _room_changed()
    if _room_id.is_empty() or not supported():
        return
    var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.QSEVoice.status())", true)
    var data: Variant = JSON.parse_string(str(raw))
    if not data is Dictionary:
        return
    var next_state := str(data.get("status", "idle"))
    var next_mic := bool(data.get("mic", false))
    var next_muted := bool(data.get("muted", false))
    var next_participants: Array = data.get("participants", []) if data.get("participants", []) is Array else []
    var next_error := str(data.get("error", ""))
    if next_state != state or next_mic != microphone_on or next_muted != received_muted or next_participants != participants or next_error != error_code:
        state = next_state
        microphone_on = next_mic
        received_muted = next_muted
        participants = next_participants
        error_code = next_error
        changed.emit()
    if state == "connected":
        _sync_elapsed += 1.0
        if _sync_elapsed >= 20.0:
            _sync_elapsed = 0.0
            client.send("/functions/v1/qse-voice-token", HTTPClient.METHOD_POST, {"room_id": _room_id, "action": "sync"})

func microphone(enabled: bool) -> void:
    if supported() and state == "connected":
        JavaScriptBridge.eval("window.QSEVoice.microphone(%s)" % ("true" if enabled else "false"), true)

func mute_received(muted: bool) -> void:
    if supported() and state == "connected":
        JavaScriptBridge.eval("window.QSEVoice.muteReceived(%s)" % ("true" if muted else "false"), true)
        received_muted = muted
        changed.emit()

func volume(identity: String, amount: float) -> void:
    if supported() and state == "connected":
        JavaScriptBridge.eval("window.QSEVoice.volume(%s,%s)" % [JSON.stringify(identity), str(clampf(amount, 0.0, 1.0))], true)

func _exit_tree() -> void:
    if supported():
        JavaScriptBridge.eval("window.QSEVoice.disconnect()", true)
