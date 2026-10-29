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
	if _timer != null and not manual_story and cards.size() > 1:
		_timer.start(dwell_seconds)

func _card(card_index: int) -> Control:
	var data: Dictionary = cards[card_index]
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.name = "Image"
	image.texture = load(str(data.get("image", ""))) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	var tint := ColorRect.new()
	tint.name = "Tint"
	tint.color = Color(0.015, 0.026, 0.05, 0.27)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tint)
	var caption := Panel.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.047, 0.08, 0.90)
	style.border_color = Color("#c79a56")
	style.border_width_top = 3
	caption.add_theme_stylebox_override("panel", style)
	frame.add_child(caption)
	for field in ["eyebrow", "title", "message"]:
		var label := Label.new()
		label.name = field.capitalize()
		label.text = str(data.get(field, ""))
		label.add_theme_font_override("font", _font)
		label.add_theme_color_override("font_color", Color("#e4bc78") if field == "eyebrow" else Color.WHITE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		caption.add_child(label)
	_layout_card(frame)
	return frame

func _layout_card(frame: Control) -> void:
	frame.size = size
	var compact := UIScale.is_compact()
	var panel := frame.get_node("Caption") as Panel
	var side := size.x * (0.04 if compact else 0.075)
	var height := size.y * (0.38 if compact else 0.28)
	panel.position = Vector2(side, size.y - height - size.y * 0.045)
	panel.size = Vector2(size.x - side * 2, height)
	var unit := UIScale.unit_for(get_viewport()) if compact else clampf(size.y / 720.0, 0.80, 1.5)
	var pad := 20.0 * unit if compact else 32.0
	for row: Array in [["Eyebrow", 0.08, 16], ["Title", 0.30, 36], ["Message", 0.66, 19]]:
		var label := panel.get_node(row[0]) as Label
		label.position = Vector2(pad, panel.size.y * float(row[1]))
		var controls_space := 155.0 * unit if manual_story and row[0] == "Message" else 0.0
		label.size = Vector2(panel.size.x - pad * 2 - controls_space, panel.size.y * (0.3 if row[0] == "Title" else 0.22))
		var font_size := 16 if compact and manual_story and row[0] == "Message" else int(row[2])
		label.add_theme_font_size_override("font_size", roundi(float(font_size) * unit))

func _layout() -> void:
	if _front != null: _layout_card(_front)
	if _skip == null: return
	var compact := UIScale.is_compact()
	var unit := UIScale.unit_for(get_viewport()) if compact else clampf(size.y / 720.0, 0.80, 1.5)
	_skip.visible = allow_skip and not show_close
	_skip.text = "Pular história" if manual_story else "Pular abertura"
	_close.visible = show_close
	_back.visible = show_close or (manual_story and index > 0)
	_forward.visible = show_close
	_story_next.visible = manual_story
	_story_next.text = "Começar fase" if manual_story and index == cards.size() - 1 else "Próximo"
	for button: Button in [_skip, _close, _back, _forward, _story_next]:
		var navigation := button == _back or button == _forward
		button.custom_minimum_size = Vector2(48 * unit, 48 * unit) if navigation else Vector2(124 * unit, 44 * unit)
		button.size = button.custom_minimum_size
		button.add_theme_font_size_override("font_size", roundi((27 if navigation else 17) * unit))
	_skip.position = Vector2(size.x - _skip.size.x - 25 * unit, 22 * unit)
	_story_next.position = Vector2(size.x - _story_next.size.x - 25 * unit, size.y - _story_next.size.y - 22 * unit)
	_close.position = Vector2(size.x - _close.size.x - 25 * unit, 22 * unit)
	_back.position = Vector2(24 * unit, size.y * 0.46)
	_forward.position = Vector2(size.x - _forward.size.x - 24 * unit, size.y * 0.46)
	_dots.text = "  ".join(PackedStringArray(Array(range(cards.size())).map(func(i: int) -> String: return "●" if i == index else "○")))
	_dots.position = Vector2(size.x * 0.43, 12 * unit)
	_dots.size = Vector2(size.x * 0.14, 40 * unit)
	_dots.add_theme_font_size_override("font_size", roundi(15 * unit))
	_dots.visible = not compact or show_close

func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", _font)
	button.add_theme_color_override("font_color", Color("#fff0d3"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.045, 0.075, 0.78)
		style.border_color = Color("#b99055")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		if state == "hover": style.bg_color = style.bg_color.lightened(0.10)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.10)
		if state == "focus": style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	add_child(button)
	return button
