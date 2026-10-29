extends PlayerScreen

const LocalCampaign = preload("res://scripts/desert/t15d/campaign_progress.gd")
const CampaignLayout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var _realm := "desert"
var _launching := false
var _unit := 1.0
var _font: FontFile
var _next_card: Control

func _ready() -> void:
	super._ready()
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	services.progression.changed.connect(func() -> void:
		if is_visible_in_tree(): render())

func _process(_delta: float) -> void:
	if is_visible_in_tree() and absf(_screen_unit()-_unit) > 0.02: render()

func render() -> void:
	_unit = _screen_unit()
	PlayerUI.clear(body)
	heading.text = tr("Modo História")
	heading.add_theme_font_override("font",_font)
	heading.add_theme_font_size_override("font_size",roundi(29*_unit))
	var back: Button = $Margin/Column/Header/Back
	back.custom_minimum_size.y = 48*_unit
	back.add_theme_font_override("font",_font)
	back.add_theme_font_size_override("font_size",roundi(18*_unit))
	banner.show_state("success","Avanço salvo neste aparelho • recompensas online não incluídas.")
	for label: Label in banner.find_children("*","Label",true,false):
		label.add_theme_font_override("font",_font)
		label.add_theme_font_size_override("font_size",roundi(15*_unit))
	var tabs := PlayerUI.row(body)
	tabs.add_theme_constant_override("separation",roundi(10*_unit))
	for realm: Array in [["Deserto","desert"],["Floresta","forest"],["Mar","sea"],["Lunar","lunar"]]:
		var tab := _button(realm[0],_select_realm.bind(realm[1]),realm[1] == _realm)
		tab.custom_minimum_size.x = 130*_unit
		tab.disabled = realm[1] != "desert"
		if tab.disabled: tab.tooltip_text = "Reino em desenvolvimento"
		tabs.add_child(tab)
	if _realm != "desert":
		body.add_child(_label("Este reino faz parte de uma aventura futura. Ainda não há fases disponíveis.",22,PlayerUI.GOLD))
		return
	var rules := PlayerContracts.read_json(PlayerContracts.RULES_PATH)
	var confirmed: Array = services.progression.data.get("completed_phase_ids",[]) if services.progression.state == "success" else []
	var online_unlocked := _confirmed_unlocked(confirmed)
	# Preserva acesso já confirmado pelo servidor sem registrar conclusão nova online.
	for order in range(1,mini(online_unlocked,10)):
		if not LocalCampaign.is_completed(order): LocalCampaign.complete(order)
	var local_completed := LocalCampaign.completed_orders()
	var unlocked := maxi(LocalCampaign.highest_unlocked(),online_unlocked)
	_next_card = null
	body.add_child(_label("CIDADE NO DESERTO  /  CAMPANHA NOTURNA",16,PlayerUI.GOLD))
	body.add_child(_label("El Fuego · %d/9 fases concluídas neste aparelho" % local_completed.size(),22))
	body.add_child(_label("Percursos de pelo menos 3 minutos nas fases 01–09. Ataque e defesa têm reposições no mapa; morrer reinicia a fase.",16,Color("#bac9d8")))
	for phase: Dictionary in rules.phases:
		var order := int(phase.order)
		var metadata: Dictionary = CampaignLayout.metadata(order) if order <= 9 else {"name":phase.name,"description":PlayerContracts.read_json("res://data/planning/desert/phase_10.json").get("narrative_description","")}
		var path := "res://scenes/desert/phase_%02d.tscn" % order
		var exists := ResourceLoader.exists(path,"PackedScene")
		var available := order <= unlocked
		var done := order in local_completed or str(phase.id) in confirmed
		var current := available and not done and order == unlocked
		var card := _card(current)
		card.get_parent().name = "PhaseCard%02d" % order
		if current: _next_card = card.get_parent()
		var row := PlayerUI.row(card)
		row.add_theme_constant_override("separation",roundi(16*_unit))
		var info := PlayerUI.column(row)
		info.add_theme_constant_override("separation",roundi(7*_unit))
		info.add_child(_label("%02d · %s" % [order,metadata.get("name",phase.name)],23,PlayerUI.GOLD if available else Color("#a3afbc")))
		info.add_child(_label(str(metadata.get("description","")),16,Color("#c1cfdd")))
		var status_text := "Concluída neste aparelho" if order in local_completed else ("Conclusão online confirmada" if str(phase.id) in confirmed else ("Liberada para jogar" if available else "Conclua a fase %02d para liberar" % (order-1)))
		if order == 10 and available: status_text = "Fase final liberada"
		info.add_child(_label(status_text,15,Color("#85cfba") if done else (Color("#dfc58f") if available else Color("#8f9eaf"))))
		var action := "Jogar novamente" if done else ("Continuar" if available and order > 1 else "Jogar")
		if not available: action = "Bloqueada"
		if not exists: action = "Indisponível"
		var start := _button(action,_launch.bind(str(phase.id),path),current)
		start.name = "Launch%02d" % order
		start.set_meta("phase_order",order)
		start.custom_minimum_size.x = 172*_unit
		start.disabled = not available or not exists
		row.add_child(start)
	call_deferred("_reveal_next")

func _reveal_next() -> void:
	await get_tree().process_frame
	if is_instance_valid(_next_card) and is_visible_in_tree():
		($Margin/Column/Scroll as ScrollContainer).ensure_control_visible(_next_card)

func _screen_unit() -> float:
	return get_viewport().get_visible_rect().size.y/maxf(get_window().size.y,1) if get_window().size.y < 600 else 1.0

func _label(text: String, pixels: int, color := PlayerUI.TEXT) -> Label:
	var label := PlayerUI.label(text,roundi(pixels*_unit),color)
	label.add_theme_font_override("font",_font)
	return label

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150,48)*_unit
	button.add_theme_font_override("font",_font)
	button.add_theme_font_size_override("font_size",roundi(17*_unit))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#dbc084") if primary else Color("#203a50")
		if state in ["hover","focus"]: style.bg_color = style.bg_color.lightened(0.10)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.10)
		if state == "disabled": style.bg_color = Color("#1a2837")
		style.border_color = Color("#d4b77b") if primary or state == "focus" else Color("#40546a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(roundi(5*_unit))
		style.content_margin_left = 14*_unit
		style.content_margin_right = 14*_unit
		button.add_theme_stylebox_override(state,style)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("#122436") if primary else Color("#f0e8d8"))
	button.add_theme_color_override("font_disabled_color",Color("#7f8c9d"))
	button.pressed.connect(action)
	return button

func _card(current: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#132b40") if current else Color("#142436")
	style.border_color = Color("#bb9a5d") if current else Color("#33485e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(roundi(8*_unit))
	style.content_margin_left = 16*_unit
	style.content_margin_right = 16*_unit
	style.content_margin_top = 14*_unit
	style.content_margin_bottom = 14*_unit
	panel.add_theme_stylebox_override("panel",style)
	body.add_child(panel)
	return PlayerUI.column(panel)

func _confirmed_unlocked(completed: Array) -> int:
	var result := 1
	for order in range(1,10):
		if "desert_phase_%02d" % order not in completed: break
		result = order+1
	return result

func _select_realm(realm: String) -> void:
	_realm = realm
	render()

func _launch(phase_id: String, path: String) -> void:
	if _launching: return
	var order := -1
	for candidate in range(1,11):
		if phase_id == "desert_phase_%02d" % candidate and path == "res://scenes/desert/phase_%02d.tscn" % candidate:
			order = candidate
			break
	if order < 1: return
	var confirmed: Array = services.progression.data.get("completed_phase_ids",[]) if services.progression.state == "success" else []
	if not LocalCampaign.is_unlocked(order) and order > _confirmed_unlocked(confirmed): return
	var menu := get_tree().current_scene as Control
	if menu == null: return
	var packed := load(path) as PackedScene
	if packed == null:
		banner.show_state("error","Não foi possível abrir a fase. Tente novamente.")
		return
	_launching = true
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
		render()
	host.add_child(layer)
	# As fases 01–09 oferecem pausa própria; o wrapper atende à fase 10 original.
	if phase.has_signal("return_requested"):
		phase.connect("return_requested",layer.return_action)
		layer.hide()
		layer.process_mode = Node.PROCESS_MODE_DISABLED
		phase.tree_exiting.connect(func() -> void:
			if is_instance_valid(layer):
				layer.show()
				layer.process_mode = Node.PROCESS_MODE_INHERIT)
	menu.hide()
