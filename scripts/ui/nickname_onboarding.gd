extends Control
## Confirmação inicial da conta; convidados continuam podendo jogar localmente.
signal saved
var services: PlayerServices
var _entry: LineEdit
var _save_button: Button
var _retry_button: Button
var _leave_button: Button
var _notice: Label
var _saving := false
var _owner_id := ""

func setup(player_services: PlayerServices) -> void:
	services=player_services
	_owner_id=str(services.session.user.get("id",""))

func _ready() -> void:
	name="NicknameOnboarding"
	add_to_group("qse_web_input_modal")
	PlayerUI.apply_theme(self)
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.name="BlockingBackdrop"
	dim.color=Color(0.008,0.016,0.027,0.89)
	dim.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.name="NicknameCenter"
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name="NicknamePanel"
	panel.custom_minimum_size=Vector2(485,0)
	panel.add_theme_stylebox_override("panel",PlayerUI.frame_panel(24))
	center.add_child(panel)
	var content := PlayerUI.column(panel)
	content.add_theme_constant_override("separation",11)
	content.add_child(PlayerUI.label("BEM-VINDO AO QUEM SOU EU!",15,PlayerUI.GOLD))
	var title := PlayerUI.label("Como quer ser chamado?",27,PlayerUI.TEXT)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := PlayerUI.label("Escolha um nickname único. Ele será definitivo e aparecerá nas partidas.",15,PlayerUI.MUTED)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	_entry=LineEdit.new()
	_entry.name="NicknameInput"
	_entry.placeholder_text="Seu nickname (3 a 24 caracteres)"
	_entry.max_length=24
	_entry.custom_minimum_size.y=52
	_entry.text=""
	_entry.set_meta("qse_autocomplete","nickname")
	PlayerUI.style_field(_entry)
	content.add_child(_entry)
	WebTextBridge.attach(_entry)
	_notice=PlayerUI.label("",14,PlayerUI.MUTED)
	_notice.name="NicknameNotice"
	_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_notice)
	_save_button=PlayerUI.button("Confirmar nickname",_commit)
	_save_button.name="ConfirmNickname"
	PlayerUI.style_button(_save_button,true)
	content.add_child(_save_button)
	_retry_button=PlayerUI.button("Atualizar perfil",_retry)
	_retry_button.name="RetryNicknameProfile"
	content.add_child(_retry_button)
	_leave_button=PlayerUI.button("Sair da conta",_leave)
	_leave_button.name="LeaveNicknameAccount"
	content.add_child(_leave_button)
	_entry.text_changed.connect(func(_value: String) -> void:
		if _saving: return
		_notice.text=""
		_sync())
	_entry.text_submitted.connect(func(_value: String) -> void: _commit())
	if services!=null: services.profile.changed.connect(_sync)
	_sync()
	_entry.grab_focus.call_deferred()

func _sync() -> void:
	var ready := services!=null and services.session.authenticated() and services.profile.state=="success" and not services.profile.has_nickname()
	_entry.editable=ready and not _saving
	_save_button.disabled=not ready or _saving or not ProfileService.valid_nickname(_entry.text)
	_retry_button.visible=not ready
	_retry_button.disabled=_saving or (services!=null and services.profile.state=="loading")
	if not ready and not _saving:
		_notice.text="Carregando seu perfil…" if services!=null and services.profile.state=="loading" else "Atualize seu perfil para cadastrar o nickname."

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control]=[]
		if _entry.editable: controls.append(_entry)
		for button: Button in [_save_button,_retry_button,_leave_button]:
			if button.visible and not button.disabled: controls.append(button)
		var index := controls.find(get_viewport().gui_get_focus_owner())
		var direction := -1 if event.is_action_pressed("ui_focus_prev") else 1
		if not controls.is_empty(): controls[posmod(index+direction,controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _suggest() -> String:
	return ""

func _retry() -> void:
	if services==null or not services.session.authenticated(): return
	await services.profile.refresh()
	if is_inside_tree(): _sync()

func _leave() -> void:
	if services!=null: await services.session.sign_out()

func _commit() -> void:
	if _saving or services==null or not services.session.authenticated(): return
	if services.profile.state!="success":
		_sync()
		return
	var nickname := _entry.text.strip_edges()
	if not ProfileService.valid_nickname(nickname):
		_notice.text=ServiceResult.message(ServiceResult.failure("invalid_nickname"))
		return
	_saving=true
	_sync()
	_notice.text="Confirmando nickname…"
	var result: Dictionary=await services.profile.update_nickname(nickname)
	if not is_inside_tree(): return
	if str(services.session.user.get("id",""))!=_owner_id:
		queue_free()
		return
	_saving=false
	# O servidor preserva a grafia canônica (NFC). Confirmar o perfil da conta,
	# sem exigir igualdade byte a byte com a entrada antes da normalização.
	if result.ok and services.profile.has_nickname():
		saved.emit()
		queue_free()
		return
	_sync()
	_notice.text=ServiceResult.message(result) if not result.ok else "Atualize o perfil para conferir seu nickname."
	if result.get("code","")=="nickname_locked": _retry_button.show()
