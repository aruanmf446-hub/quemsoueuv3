extends PanelContainer
## T32: compact voice controls shared by online lobby and Mata-Mata battle.
## Default state: disconnected + microphone disabled. No local-room voice.

const Style = preload("res://scripts/ui/battle/battle_style.gd")
var services: PlayerServices
var _connect: Button
var _mic: Button
var _audio: Button
var _unlock: Button
var _status: Label
var _selector: OptionButton
var _mute: Button
var _selected_volume := {}
var _signature := ""


func setup(value: PlayerServices) -> void:
	services = value


func _ready() -> void:
	if services == null: return
	add_theme_stylebox_override("panel", Style.panel(5))
	var main := PlayerUI.column(self)
	main.add_theme_constant_override("separation", 3)
	var row := PlayerUI.row(main)
	row.add_theme_constant_override("separation", 4)
	var title := Style.label("Voz", 15, PlayerUI.GOLD)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(title)
	_status = Style.label("Desconectado", 12, PlayerUI.MUTED)
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_connect = Style.action("Entrar", _on_connect)
	_connect.name = "VoiceConnect"
	_connect.custom_minimum_size.y = 28
	row.add_child(_connect)
	_mic = Style.action("Mic", _on_mic)
	_mic.name = "VoiceMicrophone"
	_mic.custom_minimum_size.y = 28
	row.add_child(_mic)
	_audio = Style.action("Som", _on_audio)
	_audio.name = "VoiceOutput"
	_audio.custom_minimum_size.y = 28
	row.add_child(_audio)
	var detail := PlayerUI.row(main)
	detail.add_theme_constant_override("separation", 4)
	_unlock = Style.action("Liberar áudio", _on_unlock)
	_unlock.name = "VoiceUnlockAudio"
	detail.add_child(_unlock)
	_selector = OptionButton.new()
	_selector.name = "VoiceParticipants"
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector.clip_text = true
	detail.add_child(_selector)
	_mute = Style.action("Silenciar", _on_mute)
	_mute.name = "VoiceParticipantMute"
	detail.add_child(_mute)
	services.voice.changed.connect(_refresh)
	services.duel.changed.connect(_refresh)
	services.session.changed.connect(_refresh)
	_refresh()


func _on_connect() -> void:
	if services.voice.state in ["connected", "connecting"]:
		services.voice.disconnect_voice()
	else:
		services.voice.join_voice()


func _on_mic() -> void:
	services.voice.toggle_microphone()


func _on_audio() -> void:
	services.voice.toggle_audio()


func _on_unlock() -> void:
	services.voice.unlock_audio()


func _on_mute() -> void:
	if _selector.selected < 0: return
	var id := str(_selector.get_item_metadata(_selector.selected))
	if id.is_empty(): return
	var volume := 1.0 if float(_selected_volume.get(id, 1.0)) == 0.0 else 0.0
	_selected_volume[id] = volume
	services.voice.set_player_volume(id, volume)
	_mute.text = "Ouvir" if volume == 0.0 else "Silenciar"


func _refresh() -> void:
	if not is_inside_tree() or services == null: return
	var voice := services.voice
	visible = not services.duel.is_local()
	_connect.text = "Sair" if voice.state in ["connecting", "connected"] else "Entrar"
	_connect.disabled = not voice.eligible() or voice.state == "connecting"
	_mic.disabled = voice.state != "connected"
	_audio.disabled = voice.state != "connected"
	_unlock.disabled = voice.state != "connected"
	_mic.text = "Mic ligado" if voice.mic_enabled else "Mic desligado"
	_audio.text = "Som desligado" if voice.audio_muted else "Som ligado"
	match voice.state:
		"connected": _status.text = "Conectado · %d" % (voice.participants.size() + 1)
		"connecting": _status.text = "Conectando…"
		"error": _status.text = "Voz indisponível"
		_: _status.text = "Desconectado"
	# The options include ONLY remote participants, never the local identity.
	var parts: Array = voice.participants
	var fingerprint := ""
	for part: Variant in parts:
		if part is Dictionary:
			fingerprint += str(part.get("id", "")) + ":" + str(part.get("name", "")) + ";"
	if fingerprint != _signature:
		_signature = fingerprint
		_selector.clear()
		var n := 0
		for part: Variant in parts:
			if not part is Dictionary: continue
			var id := str(part.get("id", ""))
			if id.length() != 64: continue
			n += 1
			var name := str(part.get("name", "")).strip_edges()
			_selector.add_item(name if not name.is_empty() else "Jogador %d" % n)
			_selector.set_item_metadata(_selector.item_count - 1, id)
		if _selector.item_count > 0:
			_selector.select(0)
	_selector.visible = voice.state == "connected" and _selector.item_count > 0
	_mute.visible = _selector.visible
	_unlock.visible = voice.state == "connected"
