class_name RevealOverlay
extends Control
## Resultado da rodada do Mata-Mata (design aprovado: azul-marinho, dourado, bordas iluminadas).
## Estados reais da partida, nunca simulados:
##   - Ninguém foi atingido: alvo riscado, dourado suave, "0 jogadores atingidos" (sem caveira).
##   - Jogadores atingidos: âmbar, avatares REAIS dos participantes entrando em sequência.
##   - Jogador eliminado: vermelho-escuro, avatar vai para preto e branco, borda vermelha,
##     carimbo diagonal "ELIMINADO" e caveira — só quando há eliminação real.
## Combinados: "Eliminados" e "Atingidos" em categorias separadas; quem foi eliminado aparece
## só em "Eliminados". A carta escolhida aparece à esquerda (é carta, não jogador).
## Não bloqueia a partida: só o botão Continuar recebe toque; some sozinho.
const SFX_PICK := preload("res://assets/audio/sfx/battle_pick.wav")
const SFX_HIT := preload("res://assets/audio/sfx/battle_hit.wav")
const SFX_ELIMINATE := preload("res://assets/audio/sfx/battle_eliminate.wav")
const GRADE := preload("res://scripts/ui/battle/battle_illustration.gdshader")
const NAVY := Color("#0c1626")
const NAVY_2 := Color("#13223a")
const GOLD := Color("#e7b766")
const GOLD_SOFT := Color("#f2cd8a")
const AMBER := Color("#d99a3a")
const RED := Color("#ff6f62")
const RED_DARK := Color("#3a1620")
const TEAL := Color("#6fd3c0")
const MUTED := Color("#aab3c0")

var _result_body: Control
var _result_title: Label
var _final_title := ""
var _final_title_color := Color.WHITE
var _reaction_rows: Array = []
var _audio: AudioStreamPlayer
var _closing := false
var _panel: PanelContainer
var _frame: StyleBoxFlat


## hits: [{name, skin, eliminated}] na ordem do servidor; spared: nomes não atingidos.
func present(card_id: String, card_name: String, actor_name: String, hits: Array, spared: Array = []) -> void:
	name = "RevealOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_audio)
	var eliminated := hits.filter(func(h: Dictionary) -> bool: return bool(h.get("eliminated", false)))
	var struck := hits.filter(func(h: Dictionary) -> bool: return not bool(h.get("eliminated", false)))
	var mode := "eliminated" if not eliminated.is_empty() else ("hit" if not struck.is_empty() else "none")
	var accent: Color = RED if mode == "eliminated" else (AMBER if mode == "hit" else GOLD)
	# Fundo: escurece o tabuleiro mantendo-o visível.
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "ResultPanel"
	# Centralizado pela âncora (não pelo CenterContainer): a escala de encaixe mantém o centro.
	add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = _box(NAVY, GOLD, 18, 2)
	_frame.shadow_color = Color(GOLD, 0.35)
	_frame.shadow_size = 18
	_frame.set_content_margin_all(26)
	_panel.add_theme_stylebox_override("panel", _frame)
	var column := _vbox(14)
	_panel.add_child(column)
	# Título + subtítulo.
	var title_text := ""
	match mode:
		"eliminated": title_text = "JOGADOR ELIMINADO!" if eliminated.size() == 1 else "%d JOGADORES ELIMINADOS!" % eliminated.size()
		"hit": title_text = "1 JOGADOR ATINGIDO!" if struck.size() == 1 else "%d JOGADORES ATINGIDOS!" % struck.size()
		_: title_text = "NINGUÉM FOI ATINGIDO"
	var title := _label(title_text, 36, RED.lightened(0.2) if mode == "eliminated" else GOLD_SOFT, true)
	_final_title_color=title.get_theme_color("font_color")
	title.add_theme_color_override("font_color",GOLD_SOFT)
	_result_title=title
	_final_title=title_text
	title.text="REVELANDO…"
	title.name = "ResultTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label("%s escolheu %s" % [actor_name, card_name], 18, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	# Carta escolhida (carta do deck — não é jogador).
	var card_box := PanelContainer.new()
	card_box.name = "ChosenCard"
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := _box(NAVY_2, Color("#56677f"), 14, 2)
	card_style.set_content_margin_all(14)
	card_box.add_theme_stylebox_override("panel", card_style)
	body.add_child(card_box)
	var card_col := _vbox(8)
	card_box.add_child(card_col)
	var card_head := _label("CARTA ESCOLHIDA", 15, MUTED, true)
	card_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_col.add_child(card_head)
	var art_frame := PanelContainer.new()
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_style := _box(Color.BLACK, GOLD, 8, 2)
	art_style.shadow_color = Color(GOLD, 0.35)
	art_style.shadow_size = 8
	art_frame.add_theme_stylebox_override("panel", art_style)
	card_col.add_child(art_frame)
	var art := TextureRect.new()
	art.name = "RevealCard"
	art.texture = DuelService.card_texture(card_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(170, 200)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art)
	var card_label := _label(card_name, 16, Color.WHITE, true)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.custom_minimum_size.x = 170
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_col.add_child(card_label)
	# Resultado.
	var result := _vbox(10)
	result.name = "ResultList"
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size.x = 440
	result.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(result)
	_result_body=result
	_result_body.modulate.a=0.0
	var animated: Array = []   # [node, sound, is_elimination]
	if mode == "none":
		var none_box := _vbox(6)
		none_box.name = "NoneHit"
		none_box.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := _icon("target_off", GOLD, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		none_box.add_child(icon)
		var none := _label("Ninguém foi atingido", 26, GOLD_SOFT, true)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_box.add_child(none)
		var zero := _label("0 jogadores atingidos", 17, MUTED)
		zero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_box.add_child(zero)
		result.add_child(none_box)
		animated.append([none_box, null, false])
	if not eliminated.is_empty():
		result.add_child(_section("ELIMINADOS" if not struck.is_empty() else "", RED))
		for hit: Dictionary in eliminated:
			var row := _eliminated_row(hit)
			_reaction_rows.append({"skin":hit.get("skin",""),"avatar":row.find_child("Avatar",true,false)})
			result.add_child(row)
			animated.append([row, SFX_ELIMINATE, true])
	if not struck.is_empty():
		result.add_child(_section("JOGADORES ATINGIDOS", GOLD))
		var grid := GridContainer.new()
		grid.columns = 1 if struck.size() <= 3 else 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.add_child(grid)
		for hit: Dictionary in struck:
			var row := _hit_row(hit, struck.size() > 3)
			grid.add_child(row)
			animated.append([row, SFX_HIT, false])
	var footer_text := ""
	if mode != "none":
		footer_text = ("Não atingidos: " + _join(spared)) if not spared.is_empty() else ""
		if mode == "eliminated" and spared.size() > 0 and struck.is_empty(): footer_text = "Outros jogadores continuam na partida"
	if not footer_text.is_empty():
		var footer := _label(footer_text, 16, TEAL)
		footer.name = "ResultFooter"
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.add_child(footer)
	var go := Button.new()
	go.name = "ContinueResult"
	go.text = "CONTINUAR"
	go.custom_minimum_size = Vector2(220, 52)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := _box(Color("#4a3418") if state != "hover" else Color("#5b4120"), GOLD, 14, 2)
		style.set_content_margin_all(10)
		go.add_theme_stylebox_override(state, style)
	go.add_theme_color_override("font_color", GOLD_SOFT)
	go.add_theme_color_override("font_hover_color", Color.WHITE)
	go.mouse_filter = Control.MOUSE_FILTER_STOP
	go.pressed.connect(close)
	column.add_child(go)
	_animate(animated, mode, accent)


var _intro := 1.0


## A escala é recalculada a cada quadro: o tamanho final dos textos só existe depois do layout.
func _process(_delta: float) -> void:
	if not is_instance_valid(_panel): return
	var room := size if size.y > 1.0 else get_viewport_rect().size
	_panel.size = _panel.get_combined_minimum_size()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.position = (room - _panel.size) * 0.5
	_panel.scale = Vector2.ONE * _fit_scale() * _intro


## Escala que faz o painel caber inteiro na área disponível (telas baixas, como iPhone).
func _fit_scale() -> float:
	var need := _panel.get_combined_minimum_size()
	var room := size if size.y > 1.0 else get_viewport_rect().size
	if need.x <= 0.0 or need.y <= 0.0: return 1.0
	return minf(1.0, minf(room.x * 0.96 / need.x, room.y * 0.94 / need.y))


func _animate(animated: Array, mode: String, accent: Color) -> void:
	modulate.a = 0.0
	_intro = 0.86
	for item: Array in animated: (item[0] as Control).modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(self, "_intro", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_play.bind(SFX_PICK))
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		_result_title.text=_final_title
		_result_title.add_theme_color_override("font_color",_final_title_color)
		_frame.shadow_color=Color(accent,0.35)
		_result_body.modulate.a=1.0)
	for item: Array in animated:
		var node := item[0] as Control
		if item[1] != null: tween.tween_callback(_play.bind(item[1]))
		node.position.x += 0.0
		tween.tween_property(node, "modulate:a", 1.0, 0.3)
		if bool(item[2]): tween.tween_callback(_eliminate_fx.bind(node))
		tween.tween_interval(0.25)
	# Iluminação breve nas bordas.
	tween.tween_method(func(v: float) -> void: _frame.border_color = GOLD.lerp(accent.lightened(0.25), v), 0.0, 1.0, 0.2)
	tween.tween_method(func(v: float) -> void: _frame.border_color = accent.lightened(0.25).lerp(GOLD, v), 0.0, 1.0, 0.45)
	tween.tween_interval(3.2 if mode != "none" else 2.4)
	tween.tween_callback(close)


## Eliminado: avatar colorido → preto e branco, borda vermelha acende, carimbo diagonal entra.
func _eliminate_fx(row: Control) -> void:
	var avatar := row.find_child("Avatar", true, false) as TextureRect
	var frame := row.get_meta("avatar_frame") as StyleBoxFlat
	var stamp := row.find_child("EliminatedStamp", true, false) as Control
	var tween := create_tween()
	if avatar != null and avatar.material is ShaderMaterial:
		tween.tween_method(func(v: float) -> void: (avatar.material as ShaderMaterial).set_shader_parameter("saturation", v), 1.0, 0.0, 0.45)
	if frame != null:
		tween.parallel().tween_method(func(v: float) -> void: frame.border_color = Color(RED, v), 0.2, 1.0, 0.45)
	if stamp != null and not stamp.get_parent().get_meta("animated_reaction",false):
		stamp.visible = true
		stamp.scale = Vector2.ONE * 1.8
		stamp.modulate.a = 0.0
		tween.tween_property(stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(stamp, "modulate:a", 1.0, 0.12)


func _eliminated_row(hit: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Eliminated_" + str(hit.get("name", ""))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(RED_DARK, Color(RED, 0.85), 14, 2)
	style.set_content_margin_all(18)
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 22)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var avatar_box := _avatar(str(hit.get("skin", "")), 100, RED)
	row.set_meta("avatar_frame", avatar_box.get_meta("frame"))
	line.add_child(avatar_box)
	var text := _vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(text)
	var nick := _label(str(hit.get("name", "Jogador")).to_upper(), 28, Color.WHITE, true)
	nick.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.add_child(nick)
	text.add_child(_label("ELIMINADO DA PARTIDA", 20, RED, true))
	text.add_child(_label("Ficou sem cartas restantes", 15, MUTED))
	var skull := _icon("skull", RED, 44)
	skull.name = "Skull"
	skull.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(skull)
	# Carimbo diagonal sobre o avatar.
	var stamp := Label.new()
	stamp.name = "EliminatedStamp"
	stamp.text = "ELIMINADO"
	stamp.add_theme_font_size_override("font_size", 16)
	stamp.add_theme_color_override("font_color", Color("#ffd9d4"))
	stamp.add_theme_stylebox_override("normal", _box(Color(0.75, 0.1, 0.12, 0.92), Color("#ffb3aa"), 4, 2))
	stamp.rotation_degrees = -16
	stamp.position = Vector2(4, 38)
	stamp.visible = false
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_box.add_child(stamp)
	stamp.pivot_offset = Vector2(48, 12)
	return row


func _hit_row(hit: Dictionary, compact: bool) -> Control:
	var row := PanelContainer.new()
	row.name = "Hit_" + str(hit.get("name", ""))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(NAVY_2, Color(AMBER, 0.85), 12, 2)
	style.shadow_color = Color(AMBER, 0.22)
	style.shadow_size = 6
	style.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	line.add_child(_avatar(str(hit.get("skin", "")), 52 if compact else 60, GOLD))
	var text := _vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(text)
	var nick := _label(str(hit.get("name", "Jogador")), 22, Color.WHITE, true)
	nick.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.add_child(nick)
	text.add_child(_label("Atingido nesta rodada", 14, MUTED))
	var pill := _label("−1 CARTA", 17, GOLD_SOFT, true)
	pill.add_theme_stylebox_override("normal", _box(Color("#4a3418"), GOLD, 8, 1))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.custom_minimum_size.x = 120
	line.add_child(pill)
	return row


func _avatar(skin: String, side: int, border: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _box(NAVY, border, 10, 2)
	box.add_theme_stylebox_override("panel", frame)
	box.set_meta("frame", frame)
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.texture = PlayerUI.portrait_texture(skin) if not skin.is_empty() else null
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.custom_minimum_size = Vector2(side, side)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = GRADE
	grade.set_shader_parameter("saturation", 1.0)
	avatar.material = grade
	box.add_child(avatar)
	return box


func _section(text: String, color: Color) -> Control:
	var label := _label(text, 16, color, true)
	label.visible = not text.is_empty()
	return label


func _join(names: Array) -> String:
	if names.size() <= 1: return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " e " + str(names.back())


func _play(stream: AudioStream) -> void:
	if not is_instance_valid(_audio): return
	_audio.stream = stream
	_audio.play()


func close() -> void:
	if _closing: return
	_closing = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(queue_free)


func _box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _vbox(gap: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _icon(icon_name: String, color: Color, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = PremiumUI.icon(icon_name, color, side * 2)
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Reutiliza um único palco no retrato eliminado, mantendo a carta escolhida visível.
func _react() -> void:
	if _reaction_rows.is_empty(): return
	var stage: LobbyStage=preload("res://scenes/lobby/lobby_stage.tscn").instantiate()
	stage.custom_minimum_size=Vector2(100,100)
	for row: Dictionary in _reaction_rows:
		var entries := CharacterCatalog.load_entries().filter(func(e: Dictionary)->bool:return str(e.id)==str(row.get("skin","")))
		if entries.is_empty() or not entries[0].get("animations",{}).has("anim_3"): continue
		var avatar: Control=row.avatar
		if stage.get_parent()!=null: stage.reparent(avatar.get_parent(),false)
		else: avatar.get_parent().add_child(stage)
		avatar.get_parent().move_child(stage,0)
		avatar.hide()
		avatar.get_parent().set_meta("animated_reaction",true)
		stage.modulate.a=0
		var entry: Dictionary=entries[0].duplicate(true)
		var actions: Dictionary=entry.animations
		entry.animations={}
		for alias: String in ["base","anim_3"]:
			if actions.has(alias): entry.animations[alias]=actions[alias]
		while CharacterSlot.entry_pending(entry):
			await get_tree().process_frame
			if not is_inside_tree(): return
		stage.show_character(entry)
		stage.character.play_animation(&"anim_3",false)
		var fade := create_tween()
		fade.tween_property(stage,"modulate:a",1.0,0.15)
		fade.tween_interval(1.5)
		fade.tween_property(stage,"modulate:a",0.0,0.15)
		await fade.finished
		avatar.show()
		avatar.get_parent().set_meta("animated_reaction",false)
		var stamp: Control=avatar.get_parent().get_node_or_null("EliminatedStamp")
		if stamp!=null: stamp.show()
	stage.queue_free()
