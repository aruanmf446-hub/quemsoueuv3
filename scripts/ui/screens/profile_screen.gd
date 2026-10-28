extends PlayerScreen


func _ready() -> void:
	super._ready()
	heading.text = tr("Meu perfil")
	services.profile.changed.connect(_refresh_visible)
	services.inventory.changed.connect(_refresh_visible)


func _refresh_visible() -> void:
	if is_visible_in_tree():
		render()


func render() -> void:
	PlayerUI.clear(body)
	banner.show_state(services.profile.state)
	var row := PlayerUI.row(body)
	var visual := PlayerUI.card(row)
	visual.add_child(PlayerUI.label("Herói equipado", 25, PlayerUI.GOLD))
	preview(visual, services.inventory.equipped_id())
	visual.add_child(PlayerUI.button("Trocar skin", func() -> void: navigate_requested.emit("skins", {})))
	var info := PlayerUI.card(row)
	info.add_child(PlayerUI.portrait(services.inventory.equipped_id()))
	var data := services.profile.data
	info.add_child(PlayerUI.label(str(data.get("nickname", "") if data.get("nickname") != null else "Sem nickname"), 32, PlayerUI.GOLD))
	info.add_child(PlayerUI.label("ID público: " + str(data.get("public_id", "—"))))
	info.add_child(PlayerUI.label("Nível: " + DevicePreferences.number(data.get("level"), services.preferences.values.locale)))
	info.add_child(PlayerUI.label("Experiência: " + DevicePreferences.number(data.get("experience"), services.preferences.values.locale)))
	if not services.session.authenticated():
		info.add_child(PlayerUI.label("Demonstração local • perfil e estatísticas online indisponíveis."))
		account_button(info)
		return
	var nickname := LineEdit.new()
	nickname.placeholder_text = tr("Novo nickname")
	nickname.max_length = 24
	nickname.custom_minimum_size.y = 52
	info.add_child(nickname)
	info.add_child(PlayerUI.button("Salvar nickname", func() -> void: _save_nickname(nickname.text)))
	info.add_child(PlayerUI.button("Atualizar", func() -> void: services.profile.refresh()))
	var stats: Dictionary = data.get("statistics", {})
	info.add_child(PlayerUI.label("Estatísticas", 25, PlayerUI.GOLD))
	if stats.is_empty():
		info.add_child(PlayerUI.label("Ainda não há estatísticas registradas."))
	for key: String in stats:
		info.add_child(PlayerUI.label("%s: %s" % [key, DevicePreferences.number(stats[key], services.preferences.values.locale)]))
	var progress := PlayerUI.card(body)
	progress.add_child(PlayerUI.label("Conquistas e reinos", 25, PlayerUI.GOLD))
	if services.progression.state != "success":
		progress.add_child(PlayerUI.label("Progresso confirmado indisponível."))
	else:
		var snapshot := services.progression.data
		progress.add_child(PlayerUI.label("Deserto · %d de 10 fases concluídas" % snapshot.completed_phase_ids.size()))
		progress.add_child(PlayerUI.label("Reino do Deserto concluído" if PlayerContracts.ACHIEVEMENT in snapshot.achievement_ids else "Nenhuma conquista registrada."))
	progress.add_child(PlayerUI.label("Floresta · Mar · Lunar: campanhas futuras"))


func _save_nickname(value: String) -> void:
	banner.show_state("loading")
	status(await services.profile.update_nickname(value))
