extends PlayerScreen

## Músicas do menu organizadas por categoria. Ocultar e desmarcar ficam em rascunho até "Salvar";
## "Descartar" volta ao último estado salvo. Sair da tela também descarta o rascunho.
## Faixas sem licença registrada aparecem como pendentes e não tocam. Metadados ausentes são
## mostrados como estado pendente, nunca como nome de artista.
## Janelas estreitas (abaixo de SMALL_WINDOW px físicos) usam fontes maiores: o palco do
## projeto escala a tela inteira, então a fonte lógica precisa compensar a escala real.
const CATEGORIES := {"Alternative": "Alternative", "Funk": "Funk", "k-pop": "K-pop", "pop": "Pop", "Trap": "Trap"}
const SMALL_WINDOW := 1100
const COMPACT_SCALE := 2.2

var _category := "Alternative"
var _saved := {"hidden": {}, "deselected": {}}
var _draft := {"hidden": {}, "deselected": {}}
var _show_hidden := false


func _ready() -> void:
	super._ready()
	# A moldura decorativa cobria o texto desta tela; o fundo do lobby permanece.
	$CrestFrame.hide()
	get_viewport().size_changed.connect(func() -> void:
		if is_visible_in_tree():
			render())


func show_screen(params: Dictionary = {}) -> void:
	var music := _music()
	var selection: Dictionary = music.selection() if music != null else {}
	_saved = {"hidden": _as_set(selection.get("hidden", [])), "deselected": _as_set(selection.get("deselected", []))}
	_draft = _copy(_saved)
	_show_hidden = false
	super.show_screen(params)


func render() -> void:
	PlayerUI.clear(body)
	var compact := get_window().size.x < SMALL_WINDOW
	var k := COMPACT_SCALE if compact else 1.0
	heading.text = tr("Músicas do menu")
	heading.add_theme_font_size_override("font_size", int(38 * k))
	var back := $Margin/Column/Header/Back as Button
	back.custom_minimum_size = Vector2(300, 100) if compact else Vector2(170, 56)
	back.add_theme_font_size_override("font_size", int(23 * k))
	banner.show_state("success")
	var music := _music()
	if music == null:
		body.add_child(PlayerUI.label("Player de música indisponível neste dispositivo.", int(20 * k)))
		return
	body.add_child(PlayerUI.label("Escolha quais faixas tocam no menu. Faixas sem licença registrada ficam pendentes.", int(17 * k), Color("#a8b9d0")))
	if music.local_test_mode():
		var local_test := CheckButton.new()
		local_test.text = "Tenho autorização para teste local nesta sessão"
		local_test.button_pressed = music._local_test_authorized
		local_test.custom_minimum_size.y = 52 * k
		local_test.add_theme_font_size_override("font_size", int(18 * k))
		local_test.toggled.connect(func(value: bool) -> void:
			music.set_local_test_authorized(value)
			render())
		body.add_child(local_test)
		body.add_child(PlayerUI.label("Teste local do editor. As licenças continuam pendentes; não autoriza distribuição.", int(15 * k), Color("#ffcf8a")))
	var dirty := _dirty()
	body.add_child(PlayerUI.label("Alterações não salvas" if dirty else "Todas as alterações estão salvas.", int(18 * k), Color("#ffcf8a") if dirty else Color("#a8b9d0")))
	var categories: VBoxContainer
	var list: VBoxContainer
	if compact:
		categories = PlayerUI.card(body)
		list = PlayerUI.card(body)
	else:
		var row := PlayerUI.row(body)
		categories = PlayerUI.card(row)
		categories.get_parent().custom_minimum_size.x = 240
		list = PlayerUI.card(row)
	categories.add_child(PlayerUI.label("Categorias", int(26 * k), PlayerUI.GOLD))
	categories.add_child(_category_chips(music, k, compact))
	list.add_child(PlayerUI.label(CATEGORIES[_category], int(26 * k), PlayerUI.GOLD))
	var hidden_count := 0
	for track: Dictionary in _tracks_in(music, _category):
		var is_hidden: bool = _draft.hidden.has(str(track.id))
		if is_hidden:
			hidden_count += 1
			if not _show_hidden:
				continue
		list.add_child(_track_row(music, track, k))
	if _tracks_in(music, _category).is_empty():
		list.add_child(PlayerUI.label("Nenhuma faixa nesta categoria.", int(20 * k)))
	if hidden_count > 0 or _show_hidden:
		var toggle := PlayerUI.button("Esconder lista de ocultas" if _show_hidden else "Ver ocultas (%d)" % hidden_count, _toggle_show_hidden)
		_size_button(toggle, k)
		list.add_child(toggle)
	var actions := PlayerUI.row(body)
	var save := PlayerUI.button("Salvar", _save)
	save.disabled = not dirty
	_size_button(save, k)
	actions.add_child(save)
	var discard := PlayerUI.button("Descartar", _discard)
	discard.disabled = not dirty
	_size_button(discard, k)
	actions.add_child(discard)


func _category_chips(music: Node, k: float, compact: bool) -> Container:
	var chips: Container
	if compact:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		chips = flow
	else:
		chips = VBoxContainer.new()
		chips.add_theme_constant_override("separation", 10)
	for category: String in CATEGORIES:
		var count := _tracks_in(music, category).size()
		var prefix := "▸ " if category == _category else ""
		var chip := PlayerUI.button("%s%s (%d)" % [prefix, CATEGORIES[category], count], _select_category.bind(category))
		_size_button(chip, k)
		chips.add_child(chip)
	return chips


func _track_row(music: Node, track: Dictionary, k: float) -> VBoxContainer:
	var id := str(track.id)
	var is_hidden: bool = _draft.hidden.has(id)
	var line := VBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.add_child(PlayerUI.label(str(track.title), int(22 * k)))
	line.add_child(PlayerUI.label(_subtitle(music, track), int(15 * k), Color("#a8b9d0")))
	var controls := PlayerUI.row(line)
	var select := CheckButton.new()
	select.text = "Tocar no menu"
	select.add_theme_font_size_override("font_size", int(20 * k))
	select.button_pressed = not is_hidden and not _draft.deselected.has(id)
	select.disabled = is_hidden
	select.custom_minimum_size.y = 52 * k
	select.toggled.connect(_set_selected.bind(id))
	controls.add_child(select)
	var hide := PlayerUI.button("Reexibir" if is_hidden else "Ocultar", _set_hidden.bind(id, not is_hidden))
	_size_button(hide, k)
	controls.add_child(hide)
	return line


## Artista quando existe; senão um estado discreto. Nunca um nome inventado.
func _subtitle(music: Node, track: Dictionary) -> String:
	var artist := str(track.get("artist", "")).strip_edges()
	var metadata := artist if not artist.is_empty() else "metadados pendentes"
	return "%s • %s" % [metadata, _status(music, track)]


func _status(music: Node, track: Dictionary) -> String:
	var id := str(track.id)
	if _draft.hidden.has(id):
		return "oculta"
	if _draft.deselected.has(id):
		return "fora do menu"
	if not music.licensed(track):
		if music.local_test_available(track):
			return "teste local autorizado • licença de distribuição pendente"
		return "pendente de licença, não toca"
	return "disponível no menu"


func _size_button(button: Button, k: float) -> void:
	button.custom_minimum_size.y = 52 * k
	button.add_theme_font_size_override("font_size", int(21 * k))


func _select_category(category: String) -> void:
	_category = category
	_show_hidden = false
	render()


func _toggle_show_hidden() -> void:
	_show_hidden = not _show_hidden
	render()


func _set_selected(pressed: bool, id: String) -> void:
	if pressed:
		_draft.deselected.erase(id)
	else:
		_draft.deselected[id] = true
	render()


func _set_hidden(id: String, hide: bool) -> void:
	if hide:
		_draft.hidden[id] = true
	else:
		_draft.hidden.erase(id)
	render()


func _save() -> void:
	var music := _music()
	if music == null or not music.save_selection(_draft.hidden.keys(), _draft.deselected.keys()):
		render()
		banner.show_state("error", "Não foi possível salvar a seleção neste dispositivo.")
		return
	_saved = _copy(_draft)
	render()
	banner.show_state("success", "Seleção de músicas salva.")


func _discard() -> void:
	_draft = _copy(_saved)
	render()
	banner.show_state("success", "Alterações descartadas.")


func _dirty() -> bool:
	return _sorted(_draft.hidden) != _sorted(_saved.hidden) or _sorted(_draft.deselected) != _sorted(_saved.deselected)


func _tracks_in(music: Node, category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for track: Dictionary in music.tracks:
		if str(track.get("category", "")) == category:
			result.append(track)
	return result


func _music() -> Node:
	return get_node_or_null("/root/MenuMusic")


func _as_set(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		result[str(value)] = true
	return result


func _copy(state: Dictionary) -> Dictionary:
	return {"hidden": state.hidden.duplicate(), "deselected": state.deselected.duplicate()}


func _sorted(set: Dictionary) -> Array:
	var keys := set.keys()
	keys.sort()
	return keys
