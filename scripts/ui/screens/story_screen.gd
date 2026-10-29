extends PlayerScreen

var _realm := "desert"
var _launching := false


func _ready() -> void:
	super._ready()
	services.progression.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


func render() -> void:
	PlayerUI.clear(body)
	heading.text = tr("Modo História")
	banner.show_state("success", "Demonstração local • nenhuma conclusão ou recompensa é concedida." if not services.session.authenticated() else "")
	var tabs := PlayerUI.row(body)
	for realm: Array in [["Deserto", "desert"], ["Floresta", "forest"], ["Mar", "sea"], ["Lunar", "lunar"]]:
		tabs.add_child(PlayerUI.button(realm[0], _select_realm.bind(realm[1])))
	if _realm != "desert":
		body.add_child(PlayerUI.label("Este reino faz parte de uma aventura futura. Ainda não há fases disponíveis.", 28, PlayerUI.GOLD))
		return
	var completed: Array = services.progression.data.get("completed_phase_ids", []) if services.progression.state == "success" else []
	body.add_child(PlayerUI.label("Protagonista: El Fuego · disponível na campanha antes do desbloqueio no lobby", 25, PlayerUI.GOLD))
	body.add_child(PlayerUI.label("%d de 10 fases concluídas" % completed.size() if services.progression.state == "success" else "Nenhum progresso online confirmado."))
	if services.session.authenticated() and services.progression.state != "success":
		banner.show_state(services.progression.state)
	var rules := PlayerContracts.read_json(PlayerContracts.RULES_PATH)
	for phase: Dictionary in rules.phases:
		var plan := PlayerContracts.read_json("res://data/planning/desert/phase_%02d.json" % phase.order)
		var card := PlayerUI.card(body)
		var row := PlayerUI.row(card)
		var info := PlayerUI.column(row)
		info.add_child(PlayerUI.label("%02d · %s" % [phase.order, phase.name], 26, PlayerUI.GOLD))
		info.add_child(PlayerUI.label(plan.get("narrative_description", ""), 19))
		var available := int(phase.order) <= completed.size() + 1
		var state_text := "Concluída" if phase.id in completed else ("Disponível" if available else "Bloqueada")
		var scene: Variant = plan.get("existing_runtime", {}).get("scene")
		var exists := scene is String and ResourceLoader.exists(scene, "PackedScene")
		info.add_child(PlayerUI.label(state_text + (" · Protótipo existente, sem progresso confirmado" if exists else " · Cena ainda não implementada"), 19))
		var start := PlayerUI.button("Iniciar protótipo" if exists else "Em desenvolvimento", _launch.bind(phase.id, str(scene)))
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
	var phase := packed.instantiate()
	host.add_child(phase)
	var layer := PrototypeReturnOverlay.new()
	layer.return_action = func() -> void:
		host.queue_free()
		menu.show()
		_launching = false
	host.add_child(layer)
	# A Fase 01 oferece pausa/retorno próprios; mantém o wrapper das fases legadas.
	if phase.has_signal("return_requested"):
		phase.connect("return_requested", layer.return_action)
		layer.hide()
		layer.process_mode = Node.PROCESS_MODE_DISABLED
		phase.tree_exiting.connect(func() -> void:
			if is_instance_valid(layer):
				layer.show()
				layer.process_mode = Node.PROCESS_MODE_INHERIT)
	menu.hide()
