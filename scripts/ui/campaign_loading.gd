class_name CampaignLoading
extends CanvasLayer
## Sequência editorial que cobre a leitura real da próxima cena, sem percentual falso.

signal cancelled
signal load_failed

var opening := false
var _carousel: PresentationCarousel
var _path := ""
var _ready_callback: Callable
var _ticket := 0
var _packed: PackedScene
var _can_skip := false
var _min_advances := 1
var _completion_scheduled := false
var _error_panel: PanelContainer
var _error_label: Label
var _retry_button: Button

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carousel = PresentationCarousel.new()
	_carousel.name = "OpeningCards"
	_carousel.set_cards("opening" if opening else "transition")
	_carousel.dwell_seconds = 2.0 if opening else 1.4
	_carousel.advanced.connect(_on_advanced)
	_carousel.skip_requested.connect(_skip)
	add_child(_carousel)
	_build_error()
	_error_panel.hide()

func begin(path: String, callback: Callable, is_opening := false) -> void:
	opening = is_opening
	_path = path
	_ready_callback = callback
	_min_advances = 2 if opening else 1
	_ticket += 1
	_packed = null
	_can_skip = false
	_completion_scheduled = false
	if not is_inside_tree():
		return
	_carousel.dwell_seconds = 2.0 if opening else 1.4
	_carousel.allow_skip = opening
	_carousel.set_cards("opening" if opening else "transition")
	_error_panel.hide()
	_begin_read.call_deferred(_ticket)

func _begin_read(ticket: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if ticket != _ticket or not is_inside_tree(): return
	# PackedScene deste projeto referencia scripts com preload de cenas. Godot 4.7.2
	# rejeita esses preloads em worker threads; a capa já está desenhada aqui.
	_packed = load(_path) as PackedScene
	if ticket != _ticket: return
	if _packed == null:
		_fail(ticket)
		return
	# A fase usa modelos dinâmicos do catálogo, fora das dependências do .tscn.
	# Lê um recurso por quadro sob a capa, em vez de acumular todos no primeiro
	# quadro após Pular história. As referências sobrevivem até a instanciação.
	var order := int(_path.get_file().get_basename().trim_prefix("phase_"))
	if _path.begins_with("res://scenes/desert/phase_") and order >= 1 and order <= 9:
		var groups := CharacterCatalog.load_all()
		var entries: Array = []
		for entry: Dictionary in groups.unlockable + groups.playable:
			if entry.id == "el_fuego": entries.append(entry)
		var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/desert_enemies.json"))
		entries.append(enemies.enemies.cactus)
		var paths := {}
		for entry: Dictionary in entries:
			paths[str(entry.model)] = true
			for source in entry.animations.values(): paths[str(source)] = true
		var held: Array[Resource] = []
		for source: String in paths:
			await get_tree().process_frame
			if ticket != _ticket or not is_inside_tree(): return
			var resource := load(source)
			if resource == null:
				_fail(ticket)
				return
			held.append(resource)
		_packed.set_meta("campaign_warm_resources", held)
	_can_skip = true
	if _carousel.advances >= _min_advances: _finish_after_card(ticket)

func _on_advanced(count: int) -> void:
	if _packed != null and _can_skip and count >= _min_advances:
		_finish_after_card(_ticket)

func _finish_after_card(ticket: int) -> void:
	if _completion_scheduled: return
	_completion_scheduled = true
	if opening: await get_tree().create_timer(1.0, true).timeout
	_finish(ticket)

func _finish(ticket: int) -> void:
	if ticket != _ticket or _packed == null: return
	_ticket += 1
	if _ready_callback.is_valid(): _ready_callback.call(_packed)
	queue_free()

func _skip() -> void:
	if _can_skip:
		_finish(_ticket)
	else:
		# A leitura continua; o clique já deu resposta visual com o próximo cartão.
		_carousel.next()

func _fail(ticket: int) -> void:
	if ticket != _ticket: return
	load_failed.emit()
	_error_panel.show()
	_retry_button.grab_focus()

func _retry() -> void:
	_ticket += 1
	_error_panel.hide()
	_begin_read.call_deferred(_ticket)

func _cancel() -> void:
	_ticket += 1
	cancelled.emit()
	queue_free()

func _build_error() -> void:
	_error_panel = PanelContainer.new()
	_error_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_error_panel.offset_left = -290
	_error_panel.offset_right = 290
	_error_panel.offset_top = -125
	_error_panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.055, 0.09, 0.97)
	style.border_color = Color("#c7995f")
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	_error_panel.add_theme_stylebox_override("panel", style)
	add_child(_error_panel)
	var row := VBoxContainer.new()
	_error_panel.add_child(row)
	_error_label = Label.new()
	_error_label.text = "Não foi possível abrir esta parte da jornada."
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_error_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	_retry_button = Button.new()
	_retry_button.text = "Tentar novamente"
	_retry_button.pressed.connect(_retry)
	buttons.add_child(_retry_button)
	var cancel := Button.new()
	cancel.text = "Voltar"
	cancel.pressed.connect(_cancel)
	buttons.add_child(cancel)
