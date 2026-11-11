extends PanelContainer
## T33: chat de voz COMPACTO (lobby online e batalha online). Cabe na largura da coluna da
## direita sem alargá-la. Estados:
##   desconectado → só "Entrar na voz"
##   conectando   → "Conectando…" (botão desativado, sem pedidos repetidos)
##   conectado    → um botão de microfone (liga/desliga; começa desligado) + "Sair" discreto
##   erro         → mensagem curta + "Tentar de novo"
## Quem está falando aparece pelo nickname, com ponto verde animado (eventos reais do LiveKit).
## Partida local: oculto (sem voz).

const Style = preload("res://scripts/ui/battle/battle_style.gd")
const GREEN := Color("#5fe08a")
var services: PlayerServices
var _connect: Button
var _mic: Button
var _leave: Button
var _status: Label
var _speakers: HFlowContainer
var _signature := ""
var _pulse := 0.0


func setup(value: PlayerServices) -> void:
	services = value


func _ready() -> void:
	if services == null: return
	add_theme_stylebox_override("panel", Style.panel(5))
	# Nunca impor largura própria: a coluna da direita define o tamanho.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main := PlayerUI.column(self)
	main.add_theme_constant_override("separation", 4)
	var row := PlayerUI.row(main)
	row.add_theme_constant_override("separation", 6)
	var title := Style.label("Voz", 15, PlayerUI.GOLD)
	title.name = "VoiceTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	_status = Style.label("", 12, PlayerUI.MUTED)
	_status.name = "VoiceStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size.x = 1
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status)
	_mic = Button.new()
	_mic.name = "VoiceMicrophone"
	_mic.custom_minimum_size = Vector2(36, 32)
	_mic.add_theme_constant_override("icon_max_width", 20)
	_mic.focus_mode = Control.FOCUS_ALL
	PlayerUI.style_button(_mic, false)
	_mic.pressed.connect(_on_mic)
	row.add_child(_mic)
	_leave = Button.new()
	_leave.name = "VoiceLeave"
	_leave.text = "Sair"
	_leave.flat = true
	_leave.add_theme_font_size_override("font_size", 12)
	_leave.add_theme_color_override("font_color", PlayerUI.MUTED)
	_leave.tooltip_text = "Sair do chat de voz"
	_leave.pressed.connect(func() -> void: services.voice.disconnect_voice())
	row.add_child(_leave)
	_connect = Style.action("Entrar na voz", _on_connect)
	_connect.name = "VoiceConnect"
	_connect.custom_minimum_size = Vector2(0, 32)
	_connect.clip_text = true
	_connect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_connect)
	_speakers = HFlowContainer.new()
	_speakers.name = "VoiceSpeakers"
	_speakers.add_theme_constant_override("h_separation", 8)
	_speakers.add_theme_constant_override("v_separation", 2)
	main.add_child(_speakers)
	services.voice.changed.connect(_refresh)
	services.duel.changed.connect(_refresh)
	services.session.changed.connect(_refresh)
	_refresh()


func _on_connect() -> void:
	if services.voice.state in ["off", "error"]:
		services.voice.join_voice()


func _on_mic() -> void:
	# O toque é um gesto do usuário: aproveita para liberar o áudio bloqueado pelo navegador.
	services.voice.unlock_audio()
	services.voice.toggle_microphone()


func _refresh() -> void:
	if not is_inside_tree() or services == null: return
	var voice := services.voice
	visible = not services.duel.is_local()
	var connected := voice.state == "connected"
	var connecting := voice.state == "connecting"
	_connect.visible = not connected
	_connect.disabled = connecting or not voice.eligible()
	_connect.text = "Conectando…" if connecting else ("Tentar de novo" if voice.state == "error" else "Entrar na voz")
	_mic.visible = connected
	_mic.disabled = not connected or services.duel.spectating_match()
	_leave.visible = connected
	_mic.icon = PremiumUI.icon("mic" if voice.mic_enabled else "mic_off", GREEN if voice.mic_enabled else PlayerUI.MUTED, 40)
	_mic.tooltip_text = "Desligar microfone" if voice.mic_enabled else "Ligar microfone"
	match voice.state:
		"connected": _status.text = "Ouvindo" if services.duel.spectating_match() else ""
		"connecting": _status.text = ""
		"error": _status.text = "Falha na voz"
		_: _status.text = "" if voice.eligible() else "Indisponível"
	_status.add_theme_color_override("font_color", Color("#ff8f86") if voice.state == "error" else (GREEN if connected and voice.mic_enabled else PlayerUI.MUTED))
	_render_speakers(connected)


## Só quem está falando de verdade (LiveKit): nickname + ponto verde pulsando.
func _render_speakers(connected: bool) -> void:
	var names: Array[String] = []
	if connected:
		if services.voice.self_speaking: names.append("Você")
		for part: Variant in services.voice.participants:
			if part is Dictionary and bool(part.get("speaking", false)):
				var nick := str(part.get("name", "")).strip_edges()
				names.append(nick if not nick.is_empty() else "Jogador")
	var fingerprint := ",".join(names)
	if fingerprint == _signature: return
	_signature = fingerprint
	for child in _speakers.get_children(): child.queue_free()
	_speakers.visible = not names.is_empty()
	for nick: String in names:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var dot := ColorRect.new()
		dot.name = "SpeakingDot"
		dot.color = GREEN
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(dot)
		var label := Style.label(nick, 12, GREEN)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		item.add_child(label)
		_speakers.add_child(item)


func _process(delta: float) -> void:
	if not is_instance_valid(_speakers) or not _speakers.visible: return
	_pulse += delta * 6.0
	var alpha := 0.55 + 0.45 * absf(sin(_pulse))
	for item in _speakers.get_children():
		var dot := item.get_node_or_null("SpeakingDot") as ColorRect
		if dot != null: dot.modulate.a = alpha
