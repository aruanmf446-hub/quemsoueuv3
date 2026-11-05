extends Control
## Um único palco existente por apresentação; nunca um renderer por participante.
signal finished
const STAGE = preload("res://scenes/lobby/lobby_stage.tscn")
var _stage: LobbyStage
var _title: Label
var _panel: Control
var _sound: AudioStreamPlayer
var _duck: AudioEffectAmplify
var _music := -1
func present(entries: Array,clip: String,duration: float,numbered := false) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=30
	var center := CenterContainer.new()
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel=PanelContainer.new()
	_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel",PlayerUI.plate())
	center.add_child(_panel)
	var col := PlayerUI.column(_panel)
	_title=PlayerUI.label("",26,PlayerUI.GOLD)
	_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_stage=STAGE.instantiate()
	_stage.custom_minimum_size=Vector2(240,220)
	col.add_child(_stage)
	_sound=AudioStreamPlayer.new()
	_sound.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
	_sound.stream=preload("res://assets/audio/sfx/battle_pick.wav")
	add_child(_sound)
	_music=AudioServer.get_bus_index("Music")
	if _music>=0:
		_duck=AudioEffectAmplify.new()
		AudioServer.add_bus_effect(_music,_duck)
		create_tween().tween_property(_duck,"volume_db",-10.0,0.2)
	var step := clampf(duration/maxi(entries.size(),1),0.35,2.5)
	for index in range(entries.size()):
		if not is_inside_tree(): return
		var row: Dictionary=entries[index]
		_title.text=("%d · " % (index+1) if numbered else "")+str(row.get("nickname",row.get("name","Jogador")))
		var skin := str(row.get("skin_id",row.get("skin","")))
		var candidates := CharacterCatalog.load_entries().filter(func(e: Dictionary)->bool:return str(e.id)==skin)
		_panel.modulate.a=0
		await get_tree().process_frame
		if not is_inside_tree(): return
		_stage.character.unload()
		if not candidates.is_empty():
			var entry: Dictionary=candidates[0].duplicate(true)
			var actions: Dictionary=entry.get("animations",{})
			entry.animations={}
			for alias: String in ["base",clip]:
				if actions.has(alias): entry.animations[alias]=actions[alias]
			while CharacterSlot.entry_pending(entry):
				await get_tree().process_frame
				if not is_inside_tree(): return
			entry.idle=clip
			_stage.show_character(entry)
			_stage.character.play_animation(StringName(clip),clip=="anim_2")
		_sound.play()
		var fade := create_tween()
		fade.tween_property(_panel,"modulate:a",1.0,0.16)
		fade.tween_interval(maxf(0.05,step-0.32))
		fade.tween_property(_panel,"modulate:a",0.0,0.16)
		await fade.finished
	if _duck!=null:
		var release := create_tween()
		release.tween_property(_duck,"volume_db",0.0,0.18)
		await release.finished
	finished.emit()
	queue_free()
func _exit_tree() -> void:
	if _music>=0 and _duck!=null:
		for index in range(AudioServer.get_bus_effect_count(_music)-1,-1,-1):
			if AudioServer.get_bus_effect(_music,index)==_duck: AudioServer.remove_bus_effect(_music,index)
