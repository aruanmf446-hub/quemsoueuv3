extends PlayerScreen

var _epoch := 0


func _ready() -> void:
	super._ready()
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _epoch += 1)
	services.session.changed.connect(func() -> void:
		_epoch += 1
		PlayerUI.clear(body)
		banner.show_state("unauthorized"))


func render() -> void:
	_epoch += 1
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
