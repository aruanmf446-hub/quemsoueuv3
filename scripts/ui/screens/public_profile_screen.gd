extends PlayerScreen

var _epoch := 0
var _report_dialog: Control
var _report_busy := false


func _ready() -> void:
	super._ready()
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_epoch += 1
			_close_report())
	services.session.changed.connect(func() -> void:
		_epoch += 1
		_close_report()
		PlayerUI.clear(body)
		banner.show_state("unauthorized"))


func render() -> void:
	_epoch += 1
	_close_report()
	var epoch := _epoch
	PlayerUI.clear(body)
	heading.text = tr("Perfil público")
	banner.show_state("loading")
	var result := await services.profile.public_profile(str(parameters.get("public_id", "")))
	if epoch != _epoch or not is_visible_in_tree():
		return
	status(result)
	if not result.ok:
		return
	if not result.data is Dictionary or result.data.is_empty():
		banner.show_state("empty", "Perfil não encontrado ou indisponível.")
		return
	var data: Dictionary = result.data
	var row := PlayerUI.split(body)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var visual := PlayerUI.column(row)
	preview(visual, str(data.get("equipped_character_id", "")))
	var info := PlayerUI.column(row)
	info.add_child(PlayerUI.label(str(data.get("nickname", "Sem nickname")), 32, PlayerUI.TEXT))
	info.add_child(PlayerUI.label("ID público: " + str(data.get("public_id", "—"))))
	info.add_child(PlayerUI.label("Nível: " + DevicePreferences.number(data.get("level"), services.preferences.values.locale)))
	info.add_child(PlayerUI.label(services.friends.presence_label(str(data.get("user_id", "")))))
	info.add_child(PlayerUI.label("Somente informações públicas do jogador são exibidas."))
	if str(data.get("user_id",""))!=str(services.session.user.get("id","")):
		var report := PlayerUI.button("Denunciar jogador",func()->void:
			_open_report(str(data.get("public_id",""))))
		report.name="ReportPlayer"
		info.add_child(report)


func handle_back() -> bool:
	if not is_instance_valid(_report_dialog): return false
	_close_report()
	return true


func _close_report() -> void:
	if is_instance_valid(_report_dialog):
		_report_dialog.hide()
		_report_dialog.queue_free()
	_report_dialog=null
	_report_busy=false


func _open_report(public_id: String) -> void:
	if is_instance_valid(_report_dialog): return
	var dialog := Control.new()
	dialog.name="PlayerReportDialog"
	_report_dialog=dialog
	var panel := PlayerUI.deck_modal(self,dialog)
	panel.add_child(PlayerUI.label("Denunciar jogador",30,PlayerUI.TEXT))
	panel.add_child(PlayerUI.label("Descreva o ocorrido. Não inclua senhas ou dados pessoais.",20,PlayerUI.MUTED))
	var reason := LineEdit.new()
	reason.name="PlayerReportReason"
	reason.placeholder_text=tr("Motivo da denúncia")
	reason.max_length=280
	PlayerUI.editor_control(reason)
	panel.add_child(reason)
	WebTextBridge.attach(reason)
	var feedback := PlayerUI.label("",20,PlayerUI.MUTED)
	feedback.name="PlayerReportFeedback"
	feedback.hide()
	panel.add_child(feedback)
	var actions := PlayerUI.row(panel)
	var cancel := PlayerUI.button("Cancelar",_close_report)
	cancel.name="CancelPlayerReport"
	var send := PlayerUI.button("Enviar denúncia",func()->void:
		await _send_report(public_id,dialog,reason,feedback))
	send.name="SubmitPlayerReport"
	for button: Button in [cancel,send]:
		PlayerUI.editor_control(button,button==send)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	reason.text_submitted.connect(func(_text: String)->void:send.pressed.emit())
	if not WebTextBridge.enabled(): reason.grab_focus.call_deferred()


func _send_report(public_id: String,dialog: Control,reason: LineEdit,feedback: Label) -> void:
	if _report_busy or dialog!=_report_dialog: return
	if reason.text.strip_edges().length()<3:
		feedback.text=FriendsService.report_message("invalid_reason")
		feedback.show()
		return
	_report_busy=true
	var send := dialog.find_child("SubmitPlayerReport",true,false) as Button
	send.disabled=true
	reason.editable=false
	feedback.text=tr("Enviando denúncia…")
	feedback.show()
	var epoch := _epoch
	var result := await services.friends.report_player(public_id,reason.text)
	if epoch!=_epoch or not is_instance_valid(dialog) or dialog!=_report_dialog: return
	_report_busy=false
	send.disabled=false
	reason.editable=true
	if result.ok:
		_close_report()
		banner.show_state("success",tr("Denúncia de jogador registrada. Obrigado por avisar."))
	else:
		feedback.text=FriendsService.report_message(str(result.code))
