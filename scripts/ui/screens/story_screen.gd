extends PlayerScreen

var _realm := "desert"
var _launching := false


func _ready() -> void:
	super._ready()
	ModernUI.style_header(self)
	body.add_theme_constant_override("separation", ModernUI.fs(18))
	services.progression.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	ModernUI.follow_resize(self)


func render() -> void:
	PlayerUI.clear(body)
	ModernUI.update_scale(self)
	heading.text = tr("Modo História")
	banner.show_state("success", "Demonstração local • nenhuma conclusão ou recompensa é concedida." if not services.session.authenticated() else "")
	var realms := HFlowContainer.new()
	realms.add_theme_constant_override("h_separation", ModernUI.fs(10))
	realms.add_theme_constant_override("v_separation", ModernUI.fs(10))
	body.add_child(realms)
	for realm: Array in [["Deserto", "desert"], ["Floresta", "forest"], ["Mar", "sea"], ["Lunar", "lunar"]]:
		realms.add_child(ModernUI.button(realm[0], _select_realm.bind(realm[1]), realm[1] == _realm))
	if _realm != "desert":
		var future := ModernUI.panel(body, 26)
		future.add_child(ModernUI.eyebrow("Em breve"))
		future.add_child(ModernUI.title("Este reino faz parte de uma aventura futura", 28))
		future.add_child(ModernUI.muted("Ainda não há fases disponíveis."))
		return
	var completed: Array = services.progression.data.get("completed_phase_ids", []) if services.progression.state == "success" else []
	_summary(completed)
	if services.session.authenticated() and services.progression.state != "success":
		banner.show_state(services.progression.state)
	var rules := PlayerContracts.read_json(PlayerContracts.RULES_PATH)
	for phase: Dictionary in rules.phases:
		_phase_row(phase, completed)


## Cabeçalho do reino: progresso confirmado e o protagonista da campanha.
func _summary(completed: Array) -> void:
	var summary := ModernUI.panel(body, 24)
	summary.add_child(ModernUI.eyebrow("Reino do Deserto"))
	var progress := ModernUI.title("%d de 10 fases concluídas" % completed.size() if services.progression.state == "success" else "Nenhum progresso online confirmado.", 28)
	summary.add_child(progress)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 10
	bar.value = completed.size() if services.progression.state == "success" else 0
	bar.show_percentage = false
	bar.custom_minimum_size.y = ModernUI.fs(12)
	bar.add_theme_stylebox_override("background", ModernUI._box(Color("#111b2c"), 6, ModernUI.PANEL_BORDER, 0))
	bar.add_theme_stylebox_override("fill", ModernUI._box(ModernUI.ACCENT, 6, ModernUI.ACCENT, 0))
	summary.add_child(bar)
	summary.add_child(ModernUI.muted("Protagonista: El Fuego · disponível na campanha antes do desbloqueio no lobby"))


## Uma fase: número, nome, narrativa, estado e ação. A ação só abre o protótipo existente.
func _phase_row(phase: Dictionary, completed: Array) -> void:
	var plan := PlayerContracts.read_json("res://data/planning/desert/phase_%02d.json" % phase.order)
	var card := ModernUI.panel(body, 20)
	var row := PlayerUI.row(card)
	row.add_theme_constant_override("separation", ModernUI.fs(18))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var number := ModernUI.title("%02d" % int(phase.order), 34)
	number.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	number.custom_minimum_size.x = ModernUI.fs(56)
	number.add_theme_color_override("font_color", ModernUI.ACCENT)
	row.add_child(number)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", ModernUI.fs(6))
	row.add_child(info)
	info.add_child(ModernUI.title(str(phase.name), 24))
	info.add_child(ModernUI.muted(str(plan.get("narrative_description", "")), 16))
	var available := int(phase.order) <= completed.size() + 1
	var state_text := "Concluída" if phase.id in completed else ("Disponível" if available else "Bloqueada")
	var scene: Variant = plan.get("existing_runtime", {}).get("scene")
	var exists := scene is String and ResourceLoader.exists(scene, "PackedScene")
	info.add_child(ModernUI.eyebrow(state_text + (" · protótipo existente, sem progresso confirmado" if exists else " · cena ainda não implementada")))
	var start := ModernUI.button("Iniciar protótipo" if exists else "Em desenvolvimento", _launch.bind(phase.id, str(scene)), available and exists)
	start.disabled = not available or not exists or (services.session.authenticated() and services.progression.state != "success")
	row.add_child(start)


func _select_realm(realm: String) -> void:
	_realm = realm
	render()


func _launch(phase_id: String, path: String) -> void:
	if _launching or phase_id != "desert_phase_01" or path != "res://scenes/desert/phase_01.tscn":
		return
	_launching = true
	var menu := get_tree().current_scene as Control
	if menu == null:
		_launching = false
		return
	# Apenas abre a cena original. Não há callback de vitória nem concessão por este menu.
	var packed := load(path) as PackedScene
	if packed == null:
		banner.show_state("error", "Não foi possível abrir o protótipo.")
		_launching = false
		return
	var host := Node.new()
	host.name = "StoryPrototypeSession"
	get_tree().root.add_child(host)
	host.add_child(packed.instantiate())
	var layer := PrototypeReturnOverlay.new()
	layer.return_action = func() -> void:
		host.queue_free()
		menu.show()
		_launching = false
	host.add_child(layer)
	menu.hide()
