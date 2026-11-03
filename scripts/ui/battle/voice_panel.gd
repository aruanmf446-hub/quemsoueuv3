extends PanelContainer
## Painel de voz compacto. A conexão é voluntária para preservar minutos Build.
const Style = preload("res://scripts/ui/battle/battle_style.gd")
var services: PlayerServices
var _status: Label
var _join: Button
var _mic: Button
var _hear: Button
var _users: VBoxContainer

func setup(value: PlayerServices) -> void:
    services = value

func _ready() -> void:
    name = "VoicePanel"
    add_theme_stylebox_override("panel", Style.panel(5))
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 3)
    add_child(root)
    var heading := Style.label("CHAT DE VOZ", 14, PlayerUI.GOLD)
    Style.strong(heading)
    root.add_child(heading)
    _status = Style.label("", 11, PlayerUI.MUTED)
    root.add_child(_status)
    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 4)
    root.add_child(controls)
    _join = Style.action("Entrar", _toggle_connection)
    _join.name = "VoiceConnect"
    _join.custom_minimum_size.y = 28
    controls.add_child(_join)
    _mic = Style.action("Mic desligado", _toggle_mic)
    _mic.name = "VoiceMicrophone"
    _mic.custom_minimum_size.y = 28
    controls.add_child(_mic)
    _hear = Style.action("Ouvir", _toggle_hearing)
    _hear.name = "VoiceListen"
    _hear.custom_minimum_size.y = 28
    controls.add_child(_hear)
    _users = VBoxContainer.new()
    _users.name = "VoiceParticipants"
    root.add_child(_users)
    if services != null and services.voice != null:
        services.voice.changed.connect(_refresh)
        services.duel.changed.connect(_refresh)
    _refresh()

func _toggle_connection() -> void:
    if services == null or services.voice == null: return
    if services.voice.state in ["connected", "connecting", "reconnecting"]:
        services.voice.disconnect()
    else:
        services.voice.connect_voice()

func _toggle_mic() -> void:
    if services != null and services.voice != null:
        services.voice.microphone(not services.voice.microphone_on)

func _toggle_hearing() -> void:
    if services != null and services.voice != null:
        services.voice.mute_received(not services.voice.received_muted)

func _refresh() -> void:
    if not is_inside_tree() or services == null or services.voice == null: return
    var v := services.voice
    var available := v.eligible()
    if not v.supported():
        _status.text = "Voz Web/PWA · APK e EXE em preparação"
    elif not available:
        _status.text = "Disponível apenas em salas online"
    else:
        match v.state:
            "connected": _status.text = "Conectado · microfone começa desligado"
            "connecting": _status.text = "Conectando ao LiveKit…"
            "reconnecting": _status.text = "Reconectando…"
            "error": _status.text = "Falha de voz: " + v.error_code
            "disconnected": _status.text = "Conexão encerrada · reconectar"
            _: _status.text = "Toque em Entrar para ouvir a sala"
    _join.visible = available
    _join.disabled = v.state == "connecting"
    _join.text = "Sair da voz" if v.state in ["connected", "reconnecting"] else "Entrar na voz"
    _mic.visible = v.state == "connected"
    _mic.text = "Mic ligado" if v.microphone_on else "Mic desligado"
    _hear.visible = v.state == "connected"
    _hear.text = "Som desligado" if v.received_muted else "Ouvir"
    for item in _users.get_children(): item.queue_free()
    if v.state == "connected":
        _users.add_child(Style.label("Outros conectados: %d" % v.participants.size(), 11, PlayerUI.MUTED))
        # Identidades pseudônimas; não apresentar IDs como nomes reais.
        for p in v.participants.slice(0, 20):
            if not p is Dictionary: continue
            var label := Style.label("● Falando" if bool(p.get("speaking", false)) else "● Participante", 11, PlayerUI.MUTED)
            _users.add_child(label)
