extends PlayerScreen

## Músicas do menu organizadas por categoria. Ocultar e desmarcar ficam em rascunho até "Salvar";
## "Descartar" volta ao último estado salvo. Sair da tela também descarta o rascunho.
## Faixas sem licença registrada no catálogo aparecem como pendentes e não tocam.
const CATEGORIES := {"Alternative": "Alternative", "Funk": "Funk", "k-pop": "K-pop", "pop": "Pop", "Trap": "Trap"}

var _category := "Alternative"
var _saved := {"hidden": {}, "deselected": {}}
var _draft := {"hidden": {}, "deselected": {}}
var _show_hidden := false


func show_screen(params: Dictionary = {}) -> void:
	var music := _music()
	var selection: Dictionary = music.selection() if music != null else {}
	_saved = {"hidden": _as_set(selection.get("hidden", [])), "deselected": _as_set(selection.get("deselected", []))}
	_draft = _copy(_saved)
	_show_hidden = false
	super.show_screen(params)


func render() -> void:
	PlayerUI.clear(body)
	heading.text = tr("Músicas do menu")
	banner.show_state("success")
	var music := _music()
	if music == null:
		body.add_child(PlayerUI.label("Player de música indisponível neste dispositivo."))
		return
	body.add_child(PlayerUI.label("Escolha quais faixas tocam no menu. Faixas sem licença registrada ficam pendentes e não tocam.", 17, Color("#a8b9d0")))
	var dirty := _dirty()
	body.add_child(PlayerUI.label("Alterações não salvas" if dirty else "Todas as alterações estão salvas.", 18, Color("#ffcf8a") if dirty else Color("#a8b9d0")))
	var row := PlayerUI.row(body)
	var categories := PlayerUI.card(row)
	categories.custom_minimum_size.x = 200
	categories.add_child(PlayerUI.label("Categorias", 26, PlayerUI.GOLD))
	for category: String in CATEGORIES:
		var count := _tracks_in(music, category).size()
		var prefix := "▸ " if category == _category else ""
		categories.add_child(PlayerUI.button("%s%s (%d)" % [prefix, CATEGORIES[category], count], _select_category.bind(category)))
	var list := PlayerUI.card(row)
	list.add_child(PlayerUI.label(CATEGORIES[_category], 26, PlayerUI.GOLD))
	var hidden_count := 0
	for track: Dictionary in _tracks_in(music, _category):
		var is_hidden: bool = _draft.hidden.has(str(track.id))
		if is_hidden:
			hidden_count += 1
			if not _show_hidden:
				continue
		list.add_child(_track_row(music, track))
	if hidden_count > 0 or _show_hidden:
		list.add_child(PlayerUI.button("Esconder lista de ocultas" if _show_hidden else "Ver ocultas (%d)" % hidden_count, _toggle_show_hidden))
	if _tracks_in(music, _category).is_empty():
		list.add_child(PlayerUI.label("Nenhuma faixa nesta categoria."))
	var actions := PlayerUI.row(body)
	var save := PlayerUI.button("Salvar", _save)
	save.disabled = not dirty
	actions.add_child(save)
	var discard := PlayerUI.button("Descartar", _discard)
	discard.disabled = not dirty
	actions.add_child(discard)


func _track_row(music: Node, track: Dictionary) -> VBoxContainer:
	var id := str(track.id)
	var is_hidden: bool = _draft.hidden.has(id)
	var line := VBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.add_child(PlayerUI.label(str(track.title), 22))
	line.add_child(PlayerUI.label("%s • %s" % [str(track.artist), _status(music, track)], 15, Color("#a8b9d0")))
	var controls := PlayerUI.row(line)
	var select := CheckButton.new()
	select.text = "Tocar no menu"
	select.button_pressed = not is_hidden and not _draft.deselected.has(id)
	select.disabled = is_hidden
	select.custom_minimum_size.y = 48
	select.toggled.connect(_set_selected.bind(id))
	controls.add_child(select)
	controls.add_child(PlayerUI.button("Reexibir" if is_hidden else "Ocultar", _set_hidden.bind(id, not is_hidden)))
	return line


func _status(music: Node, track: Dictionary) -> String:
	var id := str(track.id)
	if _draft.hidden.has(id):
		return "oculta"
	if _draft.deselected.has(id):
		return "fora do menu"
	if not music.licensed(track):
		return "pendente de licença, não toca"
	return "disponível no menu"


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
