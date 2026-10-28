extends PlayerScreen

## Evolução do painel existente: mantém catálogo, ThumbnailCache e LobbyStage originais.
signal character_selected(character_id: StringName)
signal progress_changed
var _thumbnails: ThumbnailCache
var _paths: Dictionary = {}
var _selected := ""
var _generating := false
var _grid: HFlowContainer
var _preview: VBoxContainer
var _images: Dictionary = {}


func _ready() -> void:
	super._ready()
	heading.text = tr("Skins")
	_thumbnails = ThumbnailCache.new(preload("res://scenes/lobby/lobby_stage.tscn"))
	services.inventory.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


func open(equipped_id: String = "") -> void:
	_selected = equipped_id
	show_screen()


func close() -> void:
	back_requested.emit()


func render() -> void:
	if _selected.is_empty():
		_selected = services.inventory.equipped_id()
	PlayerUI.clear(body)
	_images.clear()
	banner.show_state("success", "Demonstração local • equipamento não sincronizado" if not services.session.authenticated() else "")
	var row := PlayerUI.row(body)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_stretch_ratio = 1.7
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	row.add_child(_grid)
	_preview = PlayerUI.card(row)
	_preview.custom_minimum_size.x = 350
	for entry: Dictionary in services.inventory.entries:
		var card := PlayerUI.card(_grid)
		var panel := card.get_parent() as Control
		panel.custom_minimum_size = Vector2(240, 350)
		var path := str(_paths.get(entry.id, ThumbnailCache.path_for(entry.id)))
		var thumbnail := TextureRect.new()
		thumbnail.custom_minimum_size = Vector2(190, 190)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if FileAccess.file_exists(path):
			thumbnail.texture = ImageTexture.create_from_image(Image.load_from_file(path))
		card.add_child(thumbnail)
		_images[entry.id] = thumbnail
		card.add_child(PlayerUI.label(entry.name, 24, PlayerUI.GOLD))
		var unlocked := services.inventory.is_unlocked(entry.id)
		var equipped: bool = services.inventory.equipped_id() == entry.id
		card.add_child(PlayerUI.label("Equipado" if equipped else ("Desbloqueado" if unlocked else "Bloqueado"), 18))
		card.add_child(PlayerUI.button("Visualizar", _select.bind(entry.id)))
	_select(_selected)
	if not _generating:
		_generate_thumbnails()


func _select(character_id: String) -> void:
	_selected = character_id
	PlayerUI.clear(_preview)
	var entry := services.inventory.entry(character_id)
	if entry.is_empty():
		_preview.add_child(PlayerUI.label("Selecione uma skin."))
		return
	_preview.add_child(PlayerUI.label(entry.name, 30, PlayerUI.GOLD))
	preview(_preview, character_id)
	_preview.add_child(PlayerUI.label(str(entry.get("description", "Herói disponível no catálogo do lobby.")), 19))
	if not services.inventory.is_unlocked(character_id):
		_preview.add_child(PlayerUI.label(PlayerProgress.lock_label(entry), 19))
	var equip := PlayerUI.button("Equipado" if services.inventory.equipped_id() == character_id else "Equipar", _equip.bind(character_id))
	equip.disabled = not services.inventory.is_unlocked(character_id) or services.inventory.equipped_id() == character_id
	_preview.add_child(equip)
	_preview.add_child(PlayerUI.button("Voltar ao lobby", close))


func _equip(character_id: String) -> void:
	banner.show_state("loading")
	var result := await services.inventory.equip(character_id)
	if result.ok:
		character_selected.emit(StringName(character_id))
		progress_changed.emit()
		render()
	status(result)


func _generate_thumbnails() -> void:
	_generating = true
	_paths = await _thumbnails.ensure(self, services.inventory.entries)
	_generating = false
	# Captura sequencial; as listas de amigos só leem PNGs existentes.
	for character_id: String in _paths:
		if _images.has(character_id) and is_instance_valid(_images[character_id]):
			_images[character_id].texture = ImageTexture.create_from_image(Image.load_from_file(_paths[character_id]))
