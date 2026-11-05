extends SceneTree
## Executar apenas na cópia de staging, nunca no projeto de produção.
func _initialize() -> void:
	if not FileAccess.file_exists("res://.iphone_web_fixture_stage"):
		push_error("Use uma cópia de staging com .iphone_web_fixture_stage")
		quit(1)
		return
	var node := Node.new()
	node.set_script(load("res://tests/desert_night/web_desert_fixture.gd"))
	var packed := PackedScene.new()
	var result := packed.pack(node)
	if result == OK: result = ResourceSaver.save(packed,"res://tests/desert_night/web_fixture.tscn")
	node.free()
	if result != OK: quit(1); return
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK: quit(1); return
	presets.set_value("preset.0","custom_features","iphone_layout_fixture")
	presets.set_value("preset.0","exclude_filter",str(presets.get_value("preset.0","exclude_filter","")).replace("tests/*,",""))
	if presets.save("res://export_presets.cfg") != OK: quit(1); return
	ProjectSettings.set_setting("application/run/main_scene","res://tests/desert_night/web_fixture.tscn")
	quit(0 if ProjectSettings.save() == OK else 1)
