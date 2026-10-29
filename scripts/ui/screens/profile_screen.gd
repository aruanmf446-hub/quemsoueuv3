extends PlayerScreen


func _ready() -> void:
	super._ready()
	heading.text = tr("Meu perfil")
	ModernUI.style_header(self)
	body.add_theme_constant_override("separation", ModernUI.fs(18))
	services.profile.changed.connect(_refresh_visible)
	services.inventory.changed.connect(_refresh_visible)
	ModernUI.follow_resize(self)


func _refresh_visible() -> void:
	if is_visible_in_tree():
		render()


func render() -> void:
	PlayerUI.clear(body)
	ModernUI.update_scale(self)
	banner.show_state(services.profile.state)
	var locale: String = services.preferences.values.locale
	var top := _layout()
	# Herói: a única imagem do personagem nesta tela, com a troca de skin ao lado.
	var hero := ModernUI.panel(top, 18)
	hero.add_child(ModernUI.eyebrow("Herói equipado"))
	var stage := preview(hero, services.inventory.equipped_id())
	if stage != null:
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.fill_ratio = 0.86
		stage.frame_character()
	hero.add_child(ModernUI.button("Trocar skin", func() -> void: navigate_requested.emit("skins", {})))
	var identity := ModernUI.panel(top, 22)
	var data := services.profile.data
	identity.add_child(ModernUI.eyebrow("Perfil"))
	identity.add_child(ModernUI.title(str(data.get("nickname", "") if data.get("nickname") != null else "Sem nickname"), 36))
	var tiles := PlayerUI.row(identity)
	tiles.add_theme_constant_override("separation", ModernUI.fs(10))
	ModernUI.stat(tiles, "ID público", str(data.get("public_id", "—")), 24)
	ModernUI.stat(tiles, "Nível", DevicePreferences.number(data.get("level"), locale), 24)
	ModernUI.stat(tiles, "Experiência", DevicePreferences.number(data.get("experience"), locale), 24)
	if not services.session.authenticated():
		identity.add_child(ModernUI.muted("Demonstração local • perfil e estatísticas online indisponíveis."))
		identity.add_child(ModernUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}), true))
		return
	var editor := PlayerUI.row(identity)
	editor.add_theme_constant_override("separation", ModernUI.fs(10))
	var nickname := ModernUI.field("Novo nickname")
	nickname.max_length = 24
	nickname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(nickname)
	editor.add_child(ModernUI.button("Salvar nickname", func() -> void: _save_nickname(nickname.text), true))
	identity.add_child(ModernUI.button("Atualizar", func() -> void: services.profile.refresh()))
	var stats: Dictionary = data.get("statistics", {})
	identity.add_child(ModernUI.eyebrow("Estatísticas"))
	if stats.is_empty():
		identity.add_child(ModernUI.muted("Ainda não há estatísticas registradas."))
	for key: String in stats:
		identity.add_child(ModernUI.muted("%s: %s" % [key, DevicePreferences.number(stats[key], locale)], 18))
	var progress := ModernUI.panel(body, 22)
	progress.add_child(ModernUI.eyebrow("Conquistas e reinos"))
	if services.progression.state != "success":
		progress.add_child(ModernUI.muted("Progresso confirmado indisponível."))
	else:
		var snapshot := services.progression.data
		progress.add_child(ModernUI.title("Deserto · %d de 10 fases concluídas" % snapshot.completed_phase_ids.size(), 24))
		progress.add_child(ModernUI.muted("Reino do Deserto concluído" if PlayerContracts.ACHIEVEMENT in snapshot.achievement_ids else "Nenhuma conquista registrada."))
	progress.add_child(ModernUI.muted("Floresta · Mar · Lunar: campanhas futuras", 16))


## Dois blocos lado a lado em telas largas e empilhados em telas estreitas.
func _layout() -> BoxContainer:
	var layout: BoxContainer = VBoxContainer.new() if ModernUI.compact() else HBoxContainer.new()
	layout.add_theme_constant_override("separation", ModernUI.fs(18))
	body.add_child(layout)
	return layout


func _save_nickname(value: String) -> void:
	banner.show_state("loading")
	status(await services.profile.update_nickname(value))
