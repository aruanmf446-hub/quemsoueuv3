extends Control
## Apresentação dedicada: um único palco, sem cartas ou controles da partida atrás.
signal finished
const STAGE = preload("res://scenes/lobby/lobby_stage.tscn")
## Tempo padrão quando o personagem não tem o clipe pedido.
const SECONDS_PER_PLAYER := 6.0
## Cada jogador fica em cena pelo tempo real do seu clipe, dentro destes limites.
const MIN_SLOT := 3.5
const MAX_SLOT := 10.0
const FADE := 0.4
## Online: segundos disponíveis para a sequência inteira (0 = sem limite). O tempo é
## repartido entre todos em vez de mostrar só os primeiros e cortar o resto.
var time_budget := 0.0
var _stage: LobbyStage
var _title: Label
var _context: Label
var _counter: Label
var _panel: Control
var _sound: AudioStreamPlayer
var _duck: AudioEffectAmplify
var _music := -1
var _ending := false
var _skip: Button

# duration is retained for existing callers; each player now has a full six seconds
# after its model and clip are ready. A row can override presentation_clip for results.
func present(entries: Array, clip: String, _duration: float, numbered := false) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	z_index = 30
	PlayerUI.apply_theme(self)
	var background := ColorRect.new()
	background.color = PlayerUI.INTERIOR_BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = STAGE.instantiate()
	_stage.name = "PresentationStage"
	_stage.fill_ratio = 0.72
	_stage.pedestal_lift = 0.0
	_panel.add_child(_stage)
	_context = PlayerUI.label("", 22, PlayerUI.GOLD)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_context)
	_title = PlayerUI.label("", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_panel.add_child(_title)
	_counter = PlayerUI.label("", 18, PlayerUI.MUTED)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_counter)
	_skip = PlayerUI.button("Continuar", cancel)
	_skip.name = "SkipPresentation"
	_skip.custom_minimum_size = Vector2(150, 44)
	add_child(_skip)
	_skip.grab_focus()
	resized.connect(_layout)
	_layout()
	_sound = AudioStreamPlayer.new()
	_sound.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_sound.stream = preload("res://assets/audio/sfx/battle_pick.wav")
	add_child(_sound)
	_music = AudioServer.get_bus_index("Music")
	if _music >= 0:
		_duck = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(_music, _duck)
		create_tween().tween_property(_duck, "volume_db", -10.0, 0.2)
	CharacterSlot.prepare_participants(entries)
	var catalog := CharacterCatalog.load_entries()
	var started := Time.get_ticks_msec()
	for index in range(entries.size()):
		if not is_inside_tree() or _ending: return
		var row: Dictionary = entries[index]
		var current_clip := str(row.get("presentation_clip", clip))
		_title.text = str(row.get("nickname", row.get("name", "Jogador")))
		_context.text = "ORDEM DA PARTIDA" if numbered else ("VITÓRIA" if current_clip == "anim_4" else "DERROTA" if current_clip == "anim_3" else "APRESENTAÇÃO")
		_counter.text = "%d / %d" % [index + 1, entries.size()]
		if numbered: _counter.text = "%dº · %d jogadores" % [index + 1, entries.size()]
		var skin := str(row.get("skin_id", row.get("skin", "")))
		var candidates := catalog.filter(func(e: Dictionary) -> bool: return str(e.id) == skin)
		_panel.modulate.a = 0.0
		await get_tree().process_frame
		if not is_inside_tree() or _ending: return
		_stage.character.unload()
		if not candidates.is_empty():
			var entry: Dictionary = candidates[0].duplicate(true)
			var actions: Dictionary = entry.get("animations", {})
			entry.animations = {}
			for alias: String in ["base", current_clip]:
				if actions.has(alias): entry.animations[alias] = actions[alias]
			while CharacterSlot.entry_pending(entry):
				await get_tree().process_frame
				if not is_inside_tree() or _ending: return
			entry.idle = current_clip
			_stage.show_character(entry)
			_stage.character.play_animation(StringName(current_clip), current_clip == "anim_2")
			# Render a complete pose before fading in. Loading time never consumes the slot.
			await get_tree().process_frame
			if not is_inside_tree() or _ending: return
			_stage.reset_view()
		_sound.play()
		var hold := _slot_seconds(current_clip)
		if time_budget > 0.0:
			var left := time_budget - (Time.get_ticks_msec() - started) / 1000.0
			hold = minf(hold, maxf(left / float(entries.size() - index), 1.4))
		var edge := minf(FADE, hold * 0.25)
		var fade := create_tween()
		fade.tween_property(_panel, "modulate:a", 1.0, edge).set_trans(Tween.TRANS_SINE)
		fade.tween_interval(maxf(hold - edge * 2.0, 0.1))
		fade.tween_property(_panel, "modulate:a", 0.0, edge).set_trans(Tween.TRANS_SINE)
		await fade.finished
	if _duck != null:
		var release := create_tween()
		release.tween_property(_duck, "volume_db", 0.0, 0.18)
		await release.finished
	_ending = true
	finished.emit()
	queue_free()

## Tempo em cena pelo clipe carregado: reações (vitória/derrota) tocam uma vez até o fim;
## o clipe de lobby fecha em voltas completas. Nada é cortado no meio nem fica congelado.
func _slot_seconds(clip: String) -> float:
	var length := _stage.character.animation_length(StringName(clip))
	if length < 0.3: return SECONDS_PER_PLAYER
	if clip == "anim_2": return clampf(ceilf(5.0 / length) * length, MIN_SLOT, MAX_SLOT)
	return clampf(length + FADE, MIN_SLOT, MAX_SLOT)


func cancel() -> void:
	if _ending: return
	_ending = true
	finished.emit()
	queue_free()

func _layout() -> void:
	if not is_instance_valid(_stage): return
	# The match canvas already owns its scale; this overlay stays within that canvas.
	if is_instance_valid(_skip):
		_skip.position = Vector2(maxf(12, size.x - 174), maxf(12, size.y - 62))
	var top := 18.0
	_context.position = Vector2(24, top)
	_context.size = Vector2(maxf(1, size.x - 48), 30)
	_title.position = Vector2(24, top + 32)
	_title.size = Vector2(maxf(1, size.x - 48), 56)
	_counter.position = Vector2(24, size.y - 38)
	_counter.size = Vector2(maxf(1, size.x - 48), 30)
	_stage.position = Vector2(size.x * 0.16, top + 90)
	_stage.size = Vector2(size.x * 0.68, maxf(1, size.y - top - 130))

func _exit_tree() -> void:
	_ending = true
	if _music >= 0 and _duck != null:
		for index in range(AudioServer.get_bus_effect_count(_music) - 1, -1, -1):
			if AudioServer.get_bus_effect(_music, index) == _duck: AudioServer.remove_bus_effect(_music, index)
