extends PlayerScreen

const LocalCampaign = preload("res://scripts/desert/t15d/campaign_progress.gd")
const CampaignLayout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var _realm := "desert"
var _launching := false
var _unit := 1.0
var _font: FontFile
var _next_card: Control

const ART := [
	preload("res://assets/desert/night_city/outskirts.png"),
	preload("res://assets/desert/night_city/bazaar.png"),
	preload("res://assets/desert/night_city/citadel.png"),
]
const GOLD := Color("#f2c76e")
const PANEL := Color(0.035, 0.06, 0.11, 0.94)
var _compact := false
var _rail: ScrollContainer

## Seleção de fases em cartões lado a lado (estilo seleção de fase de jogos de console),
## sobre o fundo sólido compartilhado. A arte das fases fica dentro dos cartões.
func _ready() -> void:
	manages_own_scale = true
	super._ready()
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	services.progression.changed.connect(func() -> void:
		if is_visible_in_tree(): render())

func _process(_delta: float) -> void:
	if is_visible_in_tree() and absf(_screen_unit()-_unit) > 0.02: render()

## Tamanho em unidades do viewport: no desktop o valor direto; no celular, pontos da tela.
func _px(desktop: float, phone_points: float) -> float:
	return phone_points*_unit if _compact else desktop

func render() -> void:
	_compact = UIScale.is_compact()
	_unit = _screen_unit()
	PlayerUI.clear(body)
	var margin: MarginContainer = $Margin
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side, roundi(_px(64,18)))
	margin.add_theme_constant_override("margin_top", roundi(_px(40,10)))
	margin.add_theme_constant_override("margin_bottom", roundi(_px(36,8)))
	$Margin/Column.add_theme_constant_override("separation", roundi(_px(16,6)))
	body.add_theme_constant_override("separation", roundi(_px(18,6)))
	heading.text = tr("MODO HISTÓRIA")
	heading.add_theme_font_override("font",_font)
	heading.add_theme_font_size_override("font_size",roundi(_px(40,24)))
	heading.add_theme_color_override("font_color",Color.WHITE)
	var back: Button = $Margin/Column/Header/Back
	_style_slanted(back,false)
	back.custom_minimum_size = Vector2(_px(150,76),_px(52,44))
	back.add_theme_font_override("font",_font)
	back.add_theme_font_size_override("font_size",roundi(_px(20,14)))
	banner.hide()
	var tabs := PlayerUI.row(body)
	tabs.add_theme_constant_override("separation",roundi(_px(2,1)))
	for realm: Array in [["Deserto","desert"],["Floresta","forest"],["Mar","sea"],["Lunar","lunar"]]:
		var tab := Button.new()
		tab.text = realm[0] if realm[1] == "desert" else realm[0]+"  🔒"
		tab.toggle_mode = true
		tab.button_pressed = realm[1] == _realm
		tab.disabled = realm[1] != "desert"
		if tab.disabled: tab.tooltip_text = "Reino em desenvolvimento"
		tab.custom_minimum_size = Vector2(_px(150,78),_px(42,40))
		tab.add_theme_font_override("font",_font)
		tab.add_theme_font_size_override("font_size",roundi(_px(17,14)))
		_style_slanted(tab,realm[1] == _realm)
		tab.pressed.connect(_select_realm.bind(realm[1]))
		tabs.add_child(tab)
	if _realm != "desert":
		body.add_child(_label("Este reino faz parte de uma aventura futura. Ainda não há fases disponíveis.",22,GOLD))
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
	# Resumo: reino, protagonista e progresso em nove segmentos.
	var summary := PlayerUI.row(body)
	summary.add_theme_constant_override("separation",roundi(_px(18,8)))
	var info := PlayerUI.column(summary)
	info.add_theme_constant_override("separation",0)
	info.add_child(_label("REINO DO DESERTO  ·  CIDADE NOTURNA",_px(15,11)/_unit_or_one(),GOLD))
	info.add_child(_label("El Fuego  —  %d de 9 fases concluídas" % local_completed.size(),_px(22,14)/_unit_or_one()))
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(_px(300,150),_px(14,10))
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.draw.connect(func() -> void:
		var w := pips.size.x/9.0
		for index in range(9):
			var rect := Rect2(index*w+1, 0, w-3, pips.size.y)
			pips.draw_rect(rect, GOLD if index < local_completed.size() else (Color(1,1,1,0.35) if index < unlocked else Color(1,1,1,0.10))))
	summary.add_child(pips)
	_rail = ScrollContainer.new()
	_rail.name = "PhaseRail"
	_rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if _compact else ScrollContainer.SCROLL_MODE_AUTO
	_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Os cartões ocupam a altura que sobrar: tudo cabe numa tela, sem rolar para baixo
	# (no iPhone a barra do navegador deixa só ~320 pontos de altura).
	_rail.custom_minimum_size.y = _px(360,150)
	var page: ScrollContainer = $Margin/Column/Scroll
	page.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_rail)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation",roundi(_px(20,10)))
	_rail.add_child(cards)
	for phase: Dictionary in rules.phases:
		var order := int(phase.order)
		var metadata: Dictionary = CampaignLayout.metadata(order) if order <= 9 else {"name":phase.name,"description":PlayerContracts.read_json("res://data/planning/desert/phase_10.json").get("narrative_description","")}
		var path := "res://scenes/desert/phase_%02d.tscn" % order
		var exists := ResourceLoader.exists(path,"PackedScene")
		var available := order <= unlocked
		var done := order in local_completed or str(phase.id) in confirmed
		var current := available and not done and order == unlocked
		var card := _phase_card(cards,order,str(metadata.get("name",phase.name)),str(metadata.get("description","")),available,done,current)
		card.name = "PhaseCard%02d" % order
		if current: _next_card = card
		var action := "JOGAR NOVAMENTE" if done else ("CONTINUAR" if available and order > 1 else "JOGAR")
		if not available: action = "BLOQUEADA"
		if not exists: action = "INDISPONÍVEL"
		var start := Button.new()
		start.name = "Launch%02d" % order
		start.text = action
		start.set_meta("phase_order",order)
		start.disabled = not available or not exists
		start.custom_minimum_size.y = _px(50,44)
		start.add_theme_font_override("font",_font)
		start.add_theme_font_size_override("font_size",roundi(_px(18,14)))
		_style_slanted(start,current or (available and not done))
		start.pressed.connect(_launch.bind(str(phase.id),path))
		card.get_meta("footer").add_child(start)
	call_deferred("_reveal_next")

func _unit_or_one() -> float:
	return _unit if _compact else 1.0

func _phase_card(parent: Control, order: int, title: String, description: String, available: bool, done: bool, current: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_px(380,220),0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = GOLD if current else (Color("#5fbf9f") if done else Color(1,1,1,0.10))
	style.set_border_width_all(roundi(_px(3,2)) if current else 1)
	style.set_corner_radius_all(roundi(_px(4,4)))
	style.shadow_color = Color(GOLD,0.35) if current else Color(0,0,0,0.45)
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",0)
	panel.add_child(column)
	# Arte da cidade com o número da fase por cima.
	var art := TextureRect.new()
	art.texture = ART[(order-1)%ART.size()]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y = _px(150,46)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.1
	art.modulate = Color.WHITE if available else Color(0.32,0.34,0.4)
	art.clip_contents = true
	column.add_child(art)
	var number := Label.new()
	number.text = "%02d" % order
	number.add_theme_font_override("font",_font)
	number.add_theme_font_size_override("font_size",roundi(_px(64,32)))
	number.add_theme_color_override("font_color",Color.WHITE if available else Color(1,1,1,0.5))
	number.add_theme_color_override("font_outline_color",Color(0,0,0,0.85))
	number.add_theme_constant_override("outline_size",roundi(_px(2,1)))
	number.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	number.grow_vertical = Control.GROW_DIRECTION_BEGIN
	number.offset_left = _px(16,8)
	number.offset_bottom = _px(-2,-1)
	number.offset_top = number.offset_bottom
	art.add_child(number)
	var chip := Label.new()
	chip.text = "✓ CONCLUÍDA" if done else ("▶ PRÓXIMA" if current else ("LIBERADA" if available else "🔒 BLOQUEADA"))
	chip.add_theme_font_override("font",_font)
	chip.add_theme_font_size_override("font_size",roundi(_px(14,10)))
	chip.add_theme_color_override("font_color",Color("#0e1a12") if done else (Color("#151006") if current else Color.WHITE))
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color("#6fd3ad") if done else (GOLD if current else Color(0,0,0,0.65))
	chip_style.set_corner_radius_all(roundi(_px(4,2)))
	chip_style.content_margin_left = _px(10,5)
	chip_style.content_margin_right = _px(10,5)
	chip_style.content_margin_top = _px(3,1)
	chip_style.content_margin_bottom = _px(3,1)
	chip.add_theme_stylebox_override("normal",chip_style)
	chip.position = Vector2(_px(12,6),_px(12,6))
	art.add_child(chip)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",roundi(_px(8,3)))
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.size_flags_stretch_ratio = 1.0
	for side in ["left","right"]: pad.add_theme_constant_override("margin_"+side,roundi(_px(18,9)))
	pad.add_theme_constant_override("margin_top",roundi(_px(14,6)))
	pad.add_theme_constant_override("margin_bottom",roundi(_px(16,7)))
	column.add_child(pad)
	pad.add_child(content)
	var name_label := _plain(title,_px(26,16),GOLD if available else Color("#9aa6b3"))
	content.add_child(name_label)
	var text := _plain(description if available else "Conclua a fase %02d para liberar." % (order-1),_px(17,12),Color("#c3cfdc") if available else Color("#7f8b98"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 4 if not _compact else 2
	text.clip_text = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(text)
	var footer := VBoxContainer.new()
	content.add_child(footer)
	panel.set_meta("footer",footer)
	return panel

func _plain(text: String, size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",_font)
	label.add_theme_font_size_override("font_size",roundi(size))
	label.add_theme_color_override("font_color",color)
	label.custom_minimum_size.x = 10
	return label

## Botões e abas inclinados como os menus de jogos esportivos.
func _style_slanted(button: Button, primary: bool) -> void:
	PlayerUI.style_button(button, primary)

func _reveal_next() -> void:
	await get_tree().process_frame
	if is_instance_valid(_next_card) and is_instance_valid(_rail) and is_visible_in_tree():
		_rail.ensure_control_visible(_next_card)

func _screen_unit() -> float:
	return UIScale.unit_for(get_viewport()) if UIScale.is_compact() else 1.0

func _label(text: String, pixels: float, color := PlayerUI.TEXT) -> Label:
	var label := PlayerUI.label(text,roundi(pixels*_unit),color)
	label.add_theme_font_override("font",_font)
	return label

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
	# Sincroniza o inicio da fase no GAME (conta autenticada). A conclusao
	# local não substitui a prova antifraude exigida pelo backend.
	var cloud_start_ok := false
	if services.session.authenticated():
		var started: Dictionary = await services.progression.campaign_command({"type": "start_phase", "phase_id": phase_id})
		cloud_start_ok = started.ok
		if not cloud_start_ok:
			push_warning("Fase iniciada localmente; checkpoint GAME indisponível: " + str(started.code))
	var confirmed: Array = services.progression.data.get("completed_phase_ids",[]) if services.progression.state == "success" else []
	if not LocalCampaign.is_unlocked(order) and order > _confirmed_unlocked(confirmed): return
	var menu := get_tree().current_scene as Control
	if menu == null: return
	_launching = true
	var loading := CampaignLoading.new()
	loading.name = "CampaignLoading"
	get_tree().root.add_child(loading)
	loading.cancelled.connect(func() -> void: _launching = false)
	loading.begin(path, _present_phase_story.bind(menu, order))

func _present_phase_story(packed: PackedScene, menu: Control, order: int) -> void:
	if not is_instance_valid(menu): return
	menu.hide()
	var story := PhaseStory.new()
	story.name = "PhaseStory"
	get_tree().root.add_child(story)
	story.finished.connect(_open_loaded_phase.bind(packed, menu))
	story.cancelled.connect(func() -> void:
		if is_instance_valid(menu): menu.show()
		_launching = false)
	story.begin(order)

func _open_loaded_phase(packed: PackedScene, menu: Control) -> void:
	if not is_instance_valid(menu): return
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
