extends PlayerScreen

## Músicas do menu: uma caixa por faixa. Marcada toca no menu; desmarcada fica fora.
## Cada toque salva na hora (sem rascunho, Salvar ou Descartar).
const CATEGORIES := {"Alternative": "Alternative", "Funk": "Funk", "k-pop": "K-pop", "pop": "Pop", "Trap": "Trap"}


func _ready() -> void:
	manages_own_scale = false
	super._ready()
	get_viewport().size_changed.connect(func() -> void:
		if is_visible_in_tree():
			render())


func show_screen(params: Dictionary = {}) -> void:
	super.show_screen(params)


func animate_in() -> void:
	var list := body.get_node_or_null("TrackList")
	if list == null:
		PlayerUI.cascade(body)
		return
	PlayerUI.reveal(body.get_child(0))
	PlayerUI.cascade(list, 0, 0.022)


## Lista única: uma caixa por música. Tocar na linha marca/desmarca e já salva.
func render() -> void:
	PlayerUI.clear(body)
	var compact := UIScale.is_compact()
	var k := 1.0
	heading.text = tr("Músicas do menu")
	heading.add_theme_font_size_override("font_size", int(34 * k))
	heading.add_theme_color_override("font_color", Color.WHITE)
	var back := $Margin/Column/Header/Back as Button
	back.custom_minimum_size = Vector2(150, 50) * k
	back.add_theme_font_size_override("font_size", int(21 * k))
	banner.hide()
	var music := _music()
	if music == null:
		body.add_child(PlayerUI.label("Player de música indisponível neste dispositivo.", int(20 * k)))
		return
	var on := 0
	for track: Dictionary in music.tracks:
		if not music.is_excluded(str(track.id)): on += 1
	var top := PlayerUI.split(body)
	var count := PlayerUI.label("%d de %d músicas tocando no menu" % [on, music.tracks.size()], int(19 * k), Color("#c9d6e6"))
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(count)
	for spec: Array in [["Marcar todas", true], ["Desmarcar todas", false]]:
		var bulk := PlayerUI.button(spec[0], _set_all.bind(spec[1]))
		bulk.custom_minimum_size = Vector2(170, 46) * k
		bulk.add_theme_font_size_override("font_size", int(17 * k))
		bulk.size_flags_horizontal = Control.SIZE_SHRINK_END
		top.add_child(bulk)
	var list := VBoxContainer.new()
	list.name = "TrackList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(6 * k))
	body.add_child(list)
	# Agrupa por gênero, na ordem em que o gênero aparece na lista.
	var groups := {}
	for track: Dictionary in music.tracks:
		var key := str(track.category)
		if not groups.has(key): groups[key] = []
		groups[key].append(track)
	for key: String in groups:
		list.add_child(_genre_header(music, key, groups[key], k))
		for track: Dictionary in groups[key]:
			list.add_child(_row(music, track, k))


## Cabeçalho do gênero: nome, quantas tocam e um botão para marcar/desmarcar o gênero inteiro.
func _genre_header(music: Node, key: String, tracks: Array, k: float) -> HBoxContainer:
	var on := 0
	for track: Dictionary in tracks:
		if not music.is_excluded(str(track.id)): on += 1
	var header := HBoxContainer.new()
	header.name = "Genre_" + key
	header.add_theme_constant_override("separation", int(12 * k))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10 * k
	header.add_child(spacer)
	var name_label := PlayerUI.label(CATEGORIES.get(key, key).to_upper(), int(18 * k), PlayerUI.GOLD)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(name_label)
	var count := PlayerUI.label("%d de %d" % [on, tracks.size()], int(15 * k), Color("#c9d6e6"))
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(count)
	var all_on := on == tracks.size()
	var toggle := PlayerUI.button("Desmarcar gênero" if all_on else "Marcar gênero", _set_genre.bind(tracks, not all_on))
	toggle.custom_minimum_size = Vector2(170, 38) * k
	toggle.add_theme_font_size_override("font_size", int(15 * k))
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(toggle)
	return header


func _row(music: Node, track: Dictionary, k: float) -> Button:
	var id := str(track.id)
	var checked: bool = not music.is_excluded(id)
	var row := Button.new()
	row.name = "Track_" + id
	row.toggle_mode = true
	row.button_pressed = checked
	row.custom_minimum_size.y = 64 * k
	row.focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.07 if state in ["hover", "hover_pressed"] else 0.035)
		style.set_corner_radius_all(int(8 * k))
		style.border_color = PlayerUI.GOLD if state == "focus" else Color(1, 1, 1, 0.06)
		style.set_border_width_all(2 if state == "focus" else 1)
		if state == "focus": style.draw_center = false
		row.add_theme_stylebox_override(state, style)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 14 * k
	line.offset_right = -14 * k
	line.add_theme_constant_override("separation", int(14 * k))
	row.add_child(line)
	var box := Control.new()
	box.custom_minimum_size = Vector2(30, 30) * k
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, box.size)
		if row.button_pressed:
			box.draw_rect(r, PlayerUI.GOLD)
			box.draw_polyline(PackedVector2Array([r.size * Vector2(0.22, 0.52), r.size * Vector2(0.42, 0.72), r.size * Vector2(0.80, 0.28)]), Color("#141006"), 3.0 * k, true)
		else:
			box.draw_rect(r, Color(1, 1, 1, 0.55), false, 2.0 * k))
	line.add_child(box)
	var cover := TextureRect.new()
	cover.custom_minimum_size = Vector2(44, 44) * k
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(str(track.cover), "Texture2D"): cover.texture = load(str(track.cover))
	line.add_child(cover)
	var title := PlayerUI.label(str(track.title), int(20 * k), Color.WHITE if checked else Color(1, 1, 1, 0.55))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(title)
	var category := PlayerUI.label(CATEGORIES.get(str(track.category), str(track.category)).to_upper(), int(14 * k), PlayerUI.GOLD if checked else Color(1, 1, 1, 0.35))
	category.autowrap_mode = TextServer.AUTOWRAP_OFF
	category.size_flags_horizontal = Control.SIZE_SHRINK_END
	category.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(category)
	row.toggled.connect(func(value: bool) -> void: _set_selected(value, id))
	PlayerUI.fluid(row)
	return row


func _set_selected(pressed: bool, id: String) -> void:
	var music := _music()
	if music == null: return
	var selection: Dictionary = music.selection()
	var hidden := _as_set(selection.get("hidden", []))
	var deselected := _as_set(selection.get("deselected", []))
	hidden.erase(id)
	if pressed: deselected.erase(id)
	else: deselected[id] = true
	_store(hidden, deselected)


func _set_genre(tracks: Array, pressed: bool) -> void:
	var music := _music()
	if music == null: return
	var selection: Dictionary = music.selection()
	var hidden := _as_set(selection.get("hidden", []))
	var deselected := _as_set(selection.get("deselected", []))
	for track: Dictionary in tracks:
		var id := str(track.id)
		hidden.erase(id)
		if pressed: deselected.erase(id)
		else: deselected[id] = true
	_store(hidden, deselected)


func _set_all(pressed: bool) -> void:
	var music := _music()
	if music == null: return
	var deselected := {}
	if not pressed:
		for track: Dictionary in music.tracks: deselected[str(track.id)] = true
	_store({}, deselected)


func _store(hidden: Dictionary, deselected: Dictionary) -> void:
	if not _music().save_selection(hidden.keys(), deselected.keys()):
		banner.show_state("error", "Não foi possível salvar a seleção neste dispositivo.")
	render.call_deferred()


func _music() -> Node:
	return get_node_or_null("/root/MenuMusic")


func _as_set(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		result[str(value)] = true
	return result
