extends PlayerScreen
const Campaign=preload("res://scripts/desert/t15d/campaign_progress.gd")


func _ready() -> void:
	super._ready()
	heading.text = tr("Meu perfil")
	services.profile.changed.connect(_refresh_visible)
	services.inventory.changed.connect(_refresh_visible)
	services.session.changed.connect(_refresh_visible)
	if services.story_progress!=null:services.story_progress.changed.connect(_refresh_visible)


func _refresh_visible() -> void:
	if is_visible_in_tree():
		render()


func render() -> void:
	PlayerUI.clear(body)
	banner.show_state(services.profile.state)
	var row := PlayerUI.split(body)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var visual := PlayerUI.column(row)
	visual.add_child(PlayerUI.label("PERSONAGEM EQUIPADO", 13, PlayerUI.MUTED))
	preview(visual, services.inventory.equipped_id())
	visual.add_child(PlayerUI.button("Trocar skin", func() -> void: navigate_requested.emit("skins", {})))
	var info := PlayerUI.column(row)
	info.add_child(PlayerUI.label("JOGADOR", 13, PlayerUI.GOLD))
	info.add_theme_constant_override("separation", 8)
	var data := services.profile.data
	info.add_child(PlayerUI.label(str(data.get("nickname", "") if data.get("nickname") != null else "Sem nickname"), 32, PlayerUI.TEXT))
	info.add_child(PlayerUI.label("ID público: " + str(data.get("public_id", "—"))))
	info.add_child(PlayerUI.label("Nível: " + DevicePreferences.number(data.get("level"), services.preferences.values.locale)))
	info.add_child(PlayerUI.label("Experiência: " + DevicePreferences.number(data.get("experience"), services.preferences.values.locale)))
	if not services.session.authenticated():
		info.add_child(PlayerUI.label("Demonstração local", 14, PlayerUI.MUTED))
		account_button(info)
		return
	info.add_child(PlayerUI.label("O nickname é definitivo após o primeiro cadastro.", 15, PlayerUI.MUTED))
	info.add_child(PlayerUI.button("Atualizar", func() -> void: services.profile.refresh()))
	info.add_child(PlayerUI.label("Conta: " + str(services.session.user.get("email", "Conectada")), 14, PlayerUI.MUTED))
	var logout := PlayerUI.button("Desconectar / trocar conta", disconnect_account)
	logout.name = "DisconnectAccount"
	info.add_child(logout)
	var stats: Dictionary = data.get("statistics", {})
	info.add_child(PlayerUI.label("Estatísticas", 25, PlayerUI.GOLD))
	if stats.is_empty():
		info.add_child(PlayerUI.label("Ainda não há estatísticas registradas."))
	for key: String in stats:
		info.add_child(PlayerUI.label("%s: %s" % [key, DevicePreferences.number(stats[key], services.preferences.values.locale)]))
	var progress := PlayerUI.card(body)
	progress.add_child(PlayerUI.label("Conquistas e reinos", 25, PlayerUI.GOLD))
	var confirmed: Array=services.progression.data.get("completed_phase_ids",[]) if services.progression.state=="success" else []
	progress.add_child(PlayerUI.label("Deserto · %d de 10 fases concluídas" % maxi(Campaign.completed_orders().size(),confirmed.size())))
	if services.progression.state != "success":
		progress.add_child(PlayerUI.label("Conquistas confirmadas indisponíveis."))
	else:
		var snapshot := services.progression.data
		progress.add_child(PlayerUI.label("Reino do Deserto concluído" if PlayerContracts.ACHIEVEMENT in snapshot.achievement_ids else "Nenhuma conquista registrada."))
	progress.add_child(PlayerUI.label("Floresta · Mar · Lunar: campanhas futuras"))


func _save_nickname(_value: String) -> void:
	status(ServiceResult.failure("nickname_locked"))
