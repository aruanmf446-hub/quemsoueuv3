extends Control
## Primeiro acesso: nickname é confirmado pelo usuário e gravado no Supabase GAME.
## Não cria usuário, não modifica identidade OAuth nem aceita valor fictício.
signal saved

var services: PlayerServices
var _input: LineEdit
var _save_button: Button
var _notice: Label
var _saving := false
var _owner_id := ""


func setup(player_services: PlayerServices) -> void:
	services = player_services
	_owner_id = str(services.session.user.get("id", ""))


func _ready() -> void:
	name = "NicknameOnboarding"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.name = "BlockingBackdrop"
	dim.color = Color(0.008, 0.016, 0.027, 0.89)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "NicknameCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "NicknamePanel"
	panel.custom_minimum_size = Vector2(485, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#131b27")
	frame.border_color = PlayerUI.GOLD
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(13)
	frame.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", frame)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	panel.add_child(content)
	content.add_child(PlayerUI.label("BEM-VINDO AO QUEM SOU EU!", 15, PlayerUI.GOLD))
	var title := PlayerUI.label("Como quer ser chamado?", 27, PlayerUI.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := PlayerUI.label("Seu apelido aparecerá nas partidas Mata-Mata e no seu perfil.", 15, PlayerUI.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	_input = LineEdit.new()
	_input.name = "NicknameInput"
	_input.placeholder_text = "Seu nickname (3 a 24 caracteres)"
	_input.max_length = 24
	_input.custom_minimum_size.y = 48
	_input.text = _suggest()
	PlayerUI.style_field(_input)
	content.add_child(_input)

	_notice = PlayerUI.label("", 14, Color("#ffb7a8"))
	_notice.name = "NicknameNotice"
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_notice)
	_save_button = PlayerUI.button("Confirmar apelido", _commit)
	_save_button.name = "ConfirmNickname"
	PlayerUI.style_button(_save_button, true)
	content.add_child(_save_button)
	_input.text_changed.connect(func(_v: String) -> void:
		_notice.text = ""
		_save_button.disabled = _input.text.strip_edges().length() < 3)
	_save_button.disabled = _input.text.strip_edges().length() < 3
	_input.text_submitted.connect(func(_v: String) -> void: _commit())
	_input.grab_focus.call_deferred()


func _suggest() -> String:
	if services == null:
		return ""
	var raw_meta: Variant = services.session.user.get("user_metadata", {})
	if not raw_meta is Dictionary:
		return ""
	var suggestion := str(raw_meta.get("name", raw_meta.get("full_name", raw_meta.get("preferred_username", ""))))
	suggestion = suggestion.replace("\n", " ").replace("\r", " ").strip_edges().left(24)
	return suggestion if suggestion.length() >= 3 else ""


func _commit() -> void:
	if _saving or services == null or not services.session.authenticated():
		return
	var nickname := _input.text.strip_edges()
	if nickname.length() < 3 or nickname.length() > 24:
		_notice.text = "Escolha um apelido de 3 a 24 caracteres."
		return
	_saving = true
	_save_button.disabled = true
	_notice.text = "Salvando no GAME…"
	var result: Dictionary = await services.profile.update_nickname(nickname)
	if not is_inside_tree():
		return
	if str(services.session.user.get("id", "")) != _owner_id:
		queue_free()
		return
	_saving = false
	if result.ok and str(services.profile.data.get("nickname", "")) == nickname:
		saved.emit()
		queue_free()
		return
	_notice.text = "Não foi possível salvar o apelido. Confira a conexão e tente novamente."
	_save_button.disabled = false
