class_name PresentationCarousel
extends Control
## Cartões editoriais em tela cheia. A imagem e a legenda deslizam juntas.

signal advanced(count: int)
signal skip_requested
signal close_requested
signal story_finished

var cards: Array = []
var dwell_seconds := 2.1
var show_close := false
var allow_skip := true
var manual_story := false
var show_counter := true
var index := 0
var advances := 0
var _front: Control
var _timer: Timer
var _moving := false
var _font: FontFile
var _skip: Button
var _close: Button
var _back: Button
var _forward: Button
var _story_next: Button
var _dots: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	PlayerUI.apply_theme(self)
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(next)
	add_child(_timer)
	_skip = _button("Pular abertura", func() -> void: skip_requested.emit())
	_close = _button("Fechar", func() -> void: close_requested.emit())
	_back = _button("‹", previous)
	_forward = _button("›", next)
	_story_next = _button("Próximo", next)
	_dots = Label.new()
	_dots.add_theme_font_override("font", _font)
	_dots.add_theme_color_override("font_color", Color("#f7e6c1"))
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_dots)
	resized.connect(_layout)
	if not cards.is_empty():
		_front = _card(index)
		add_child(_front)
		move_child(_front, 0)
	_start_timer()
	_layout()

func set_cards(group: String) -> void:
	var source := FileAccess.get_file_as_string("res://data/ui/presentation.json")
	var parsed: Variant = JSON.parse_string(source)
	set_cards_data(parsed.get(group, []) if parsed is Dictionary else [])

func set_cards_data(entries: Array) -> void:
	cards = entries
	index = 0
	advances = 0
	if is_inside_tree():
		if is_instance_valid(_front): _front.queue_free()
		_front = _card(index) if not cards.is_empty() else null
		if _front != null:
			add_child(_front)
			move_child(_front, 0)
		_start_timer()
		_layout()

func next() -> void:
	if manual_story and index >= cards.size() - 1:
		story_finished.emit()
		return
	_slide(1)

func previous() -> void:
	_slide(-1)

func focus_close() -> void:
	if is_instance_valid(_close): _close.grab_focus()

func _slide(direction: int) -> void:
	if _moving or cards.size() < 2: return
	if manual_story and index + direction < 0: return
	_moving = true
	_timer.stop()
	var upcoming := posmod(index + direction, cards.size())
	var next_card := _card(upcoming)
	add_child(next_card)
	move_child(next_card, 0)
	next_card.position.x = size.x * direction
	var old := _front
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old, "position:x", -size.x * direction, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(next_card, "position:x", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(old): old.queue_free()
	_front = next_card
	index = upcoming
	advances += 1
	_moving = false
	_layout()
	advanced.emit(advances)
	_start_timer()

func _start_timer() -> void:
	if _timer == null: return
	_timer.stop()
	if not manual_story and cards.size() > 1:
		_timer.start(dwell_seconds)

func _card(card_index: int) -> Control:
	var data: Dictionary = cards[card_index]
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.name = "Image"
	image.texture = load(str(data.get("image", ""))) as Texture2D
	if data.has("atlas_region") and image.texture != null:
		var tile: Array = data.atlas_region
		var atlas := AtlasTexture.new()
		atlas.atlas = image.texture
		var cell := Vector2(image.texture.get_width()/float(tile[2]),image.texture.get_height()/float(tile[3]))
		atlas.region = Rect2(Vector2(float(tile[0]),float(tile[1]))*cell,cell)
		atlas.filter_clip = true
		image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	# Fotos editoriais remotas: a imagem original acompanha como fallback.
	var service: EditorContentService = PlayerServices.current.editor_content if PlayerServices.current != null else null
	if service != null:
		service.attach_cover(image, str(data.get("cover_path", "")))
	var tint := ColorRect.new()
	tint.name = "Tint"
	tint.color = Color(0.015, 0.026, 0.05, 0.27)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tint)
	var caption := Panel.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel",PlayerUI.plate())
	frame.add_child(caption)
	for field in ["eyebrow", "title", "message"]:
		var label := Label.new()
		label.name = field.capitalize()
		# Tradução pelo texto original (data/ui/<idioma>.json); o rótulo não traduz de novo.
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = tr(str(data.get(field, ""))).replace("\n\n","\n")
		label.add_theme_font_override("font", _font)
		label.add_theme_color_override("font_color", Color("#e4bc78") if field == "eyebrow" else Color.WHITE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = false
		if field == "message": label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_child(label)
	_layout_card(frame)
	return frame

func _layout_card(frame: Control) -> void:
	frame.size = size
	var panel := frame.get_node("Caption") as Panel
	var side := 32.0
	var height := 370.0 if manual_story else 260.0
	var panel_width := maxf(1.0,size.x-side*2)
	# No modo história o botão "Próximo" fica no canto direito do bloco: o texto não passa por baixo.
	var message_width := maxf(1.0,panel_width-48.0-(264.0 if manual_story else 0.0))
	if manual_story:
		# Fundo do tamanho do texto (pedido do dono): só o necessário, nunca maior que antes.
		var message := panel.get_node("Message") as Label
		var text_height := _font.get_multiline_string_size(message.text,HORIZONTAL_ALIGNMENT_LEFT,message_width,24).y
		height = clampf(108.0+text_height+22.0,188.0,370.0)
	panel.position = Vector2(side,size.y-height-24.0)
	panel.size = Vector2(panel_width,height)
	for row: Array in [["Eyebrow",16.0,18,28.0],["Title",50.0,34,48.0],["Message",108.0,24,height-124.0]]:
		var label := panel.get_node(row[0]) as Label
		label.position = Vector2(24,float(row[1]))
		label.size = Vector2(message_width if row[0] == "Message" else maxf(1.0,panel_width-48),float(row[3]))
		label.add_theme_font_size_override("font_size",int(row[2]))
func _layout() -> void:
	if _front != null: _layout_card(_front)
	if _skip == null: return
	_skip.visible = allow_skip and not show_close
	_skip.text = "Pular história" if manual_story else "Pular abertura"
	_close.visible = show_close
	_back.visible = show_close or (manual_story and index > 0)
	_forward.visible = show_close
	_story_next.visible = manual_story
	_story_next.text = "Começar fase" if manual_story and index == cards.size()-1 else "Próximo"
	var touch_height := 88.0 if UIScale.is_iphone() else 64.0
	for button: Button in [_skip,_close,_back,_forward,_story_next]:
		var navigation := button == _back or button == _forward
		button.custom_minimum_size = Vector2(touch_height,touch_height) if navigation else Vector2(224,touch_height)
		button.size = button.custom_minimum_size
		button.add_theme_font_size_override("font_size",30 if navigation else 24)
	_skip.position = Vector2(size.x-_skip.size.x-32,24)
	_story_next.position = Vector2(size.x-_story_next.size.x-56,size.y-_story_next.size.y-40)
	_close.position = Vector2(size.x-_close.size.x-32,24)
	var arrow_y := size.y*0.34
	if UIScale.is_iphone() and manual_story:
		# Fora do bloco de legenda mesmo na menor altura útil; alvo de88unidades.
		arrow_y = maxf(120.0,(size.y-394.0-touch_height)*0.5)
	_back.position = Vector2(32,arrow_y)
	_forward.position = Vector2(size.x-_forward.size.x-32,arrow_y)
	_dots.text = "%02d / %02d" % [index+1,cards.size()]
	_dots.position = Vector2(size.x*0.43,24)
	_dots.size = Vector2(size.x*0.14,40)
	_dots.add_theme_font_size_override("font_size",22)
	_dots.visible = show_counter and not cards.is_empty()

func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", _font)
	PlayerUI.style_button(button,false)
	button.pressed.connect(action)
	add_child(button)
	return button
