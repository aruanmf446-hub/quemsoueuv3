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
var _story_mode := false
var _story_done := false
var _phase_order := 0
var _status: Label
var _inflight := ""
var _cancelling := false
var _web_story_handoff := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carousel = PresentationCarousel.new()
	_carousel.name = "OpeningCards"
	_carousel.set_cards("opening" if opening else "transition")
	_carousel.dwell_seconds = 2.0 if opening else 1.4
	_carousel.advanced.connect(_on_advanced)
	_carousel.skip_requested.connect(_skip)
	_carousel.story_finished.connect(_story_completed)
	add_child(_carousel)
	_build_error()
	_error_panel.hide()
	_status = Label.new()
	_status.position = Vector2(32,24)
	_status.add_theme_font_size_override("font_size",22)
	PlayerUI.apply_theme(_status)
	add_child(_status)
	_status.hide()

func begin(path: String, callback: Callable, is_opening := false) -> void:
	opening = is_opening
	_path = path
	_ready_callback = callback
	_phase_order = int(path.get_file().get_basename().trim_prefix("phase_")) if path.begins_with("res://scenes/desert/phase_") else 0
	_web_story_handoff = false
	if _phase_order >= 1 and _phase_order <= 9 and OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.qseSetStoryPlaying) window.qseSetStoryPlaying(true);")
	_story_mode = not opening and _phase_order >= 1 and _phase_order <= 9 and not PhaseStory.was_read(_phase_order)
	_story_done = not _story_mode
	_min_advances = 2 if opening else (0 if _phase_order >= 1 and _phase_order <= 9 else 1)
	_ticket += 1
	_packed = null
	_can_skip = false
	_completion_scheduled = false
	if not is_inside_tree():
		return
	_carousel.dwell_seconds = 2.0 if opening else 1.4
	_carousel.allow_skip = opening
	_carousel.manual_story = _story_mode
	_carousel.allow_skip = opening or _story_mode
	if _story_mode:
		_carousel.set_cards_data(PhaseStory.cards_for(_phase_order))
	elif _phase_order >= 1 and _phase_order <= 9:
		var entries := PhaseStory.cards_for(_phase_order)
		var cover: Dictionary = entries[0].duplicate() if not entries.is_empty() else {}
		cover.title = "Preparando fase"
		cover.message = ""
		cover.eyebrow = "REINO DO DESERTO"
		_carousel.set_cards_data([cover])
	else:
		_carousel.set_cards("opening" if opening else "transition")
	_status.visible = _phase_order >= 1 and _phase_order <= 9
	_status.text = "Preparando fase…"
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
			var resource: Resource
			# Cenas com scripts continuam na thread principal; FBX importados e animações
			# sem scripts podem ser lidos no worker enquanto o jogador lê as legendas.
			if not OS.has_feature("web") and ResourceLoader.load_threaded_request(source,"",false) == OK:
				_inflight = source
				while ResourceLoader.load_threaded_get_status(source) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					await get_tree().process_frame
					if ticket != _ticket or not is_inside_tree(): return
				if ResourceLoader.load_threaded_get_status(source) == ResourceLoader.THREAD_LOAD_LOADED:
					resource = ResourceLoader.load_threaded_get(source)
				_inflight = ""
			else:
				# Export Web sem threads: uma leitura por quadro mantém o desenho entre recursos.
				resource = load(source)
			if resource == null:
				_fail(ticket)
				return
			held.append(resource)
		_packed.set_meta("campaign_warm_resources", held)
	_can_skip = true
	_status.text = "Fase pronta • leia no seu ritmo" if _story_mode and not _story_done else ""
	if _story_done and _carousel.advances >= _min_advances: _finish_after_card(ticket)

func _on_advanced(count: int) -> void:
	if _story_done and _packed != null and _can_skip and count >= _min_advances:
		_finish_after_card(_ticket)

func _finish_after_card(ticket: int) -> void:
	if _completion_scheduled: return
	_completion_scheduled = true
	if opening: await get_tree().create_timer(1.0, true).timeout
	_finish(ticket)

func _finish(ticket: int) -> void:
	if ticket != _ticket or _packed == null: return
	_ticket += 1
	if _ready_callback.is_valid():
		_web_story_handoff = _phase_order >= 1 and _phase_order <= 9
		_ready_callback.call(_packed)
	queue_free()

func _story_completed() -> void:
	if not _story_mode: return
	_story_done = true
	PhaseStory.mark_read(_phase_order)
	if _can_skip:
		_finish(_ticket)
	else:
		_status.text = "Preparando fase…"
		_carousel.manual_story = false
		_carousel.allow_skip = false
		_carousel._layout()

func _skip() -> void:
	if _story_mode:
		_story_completed()
		return
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
	if _cancelling: return
	_cancelling = true
	_ticket += 1
	_carousel.hide()
	_status.hide()
	var was_failed := _error_panel.visible
	_error_panel.hide()
	cancelled.emit()
	# A coroutine de leitura verifica o ticket no quadro seguinte. Mantém o dono
	# vivo até ela sair e recolhe um worker já solicitado sem bloquear o retorno.
	if not was_failed:
		if not _inflight.is_empty():
			while ResourceLoader.load_threaded_get_status(_inflight) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
			if ResourceLoader.load_threaded_get_status(_inflight) == ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(_inflight)
			_inflight = ""
		for frame in range(3): await get_tree().process_frame
	queue_free()

func _build_error() -> void:
	_error_panel = PanelContainer.new()
	_error_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_error_panel.offset_left = -290
	_error_panel.offset_right = 290
	_error_panel.offset_top = -125
	_error_panel.offset_bottom = -24
	PlayerUI.apply_theme(_error_panel)
	_error_panel.add_theme_stylebox_override("panel",PlayerUI.frame_panel(14))
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
	PlayerUI.style_button(_retry_button,true)
	_retry_button.pressed.connect(_retry)
	buttons.add_child(_retry_button)
	var cancel := Button.new()
	cancel.text = "Voltar"
	PlayerUI.style_button(cancel,false)
	cancel.pressed.connect(_cancel)
	buttons.add_child(cancel)

func _unhandled_input(event: InputEvent) -> void:
	if _phase_order >= 1 and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()

func _exit_tree() -> void:
	if not _web_story_handoff and _phase_order >= 1 and _phase_order <= 9 and OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.qseSetStoryPlaying) window.qseSetStoryPlaying(false);")
