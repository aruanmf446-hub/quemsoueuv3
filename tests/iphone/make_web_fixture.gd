extends SceneTree
## Generate the test scene through Godot, only in an explicitly marked staging copy.
func _initialize() -> void:
	if not FileAccess.file_exists("res://.iphone_web_fixture_stage"):
		push_error("Use an isolated staging project; see tests/iphone/WEB_VALIDATION.md")
		quit(1)
		return
	var script := load("res://tests/iphone/web_fixture.gd")
	if script == null:
		quit(1)
		return
	var node := Node.new()
	node.name = "IphoneLayoutFixture"
	node.set_script(script)
	var scene := PackedScene.new()
	var result := scene.pack(node)
	if result == OK: result = ResourceSaver.save(scene, "res://tests/iphone/web_fixture.tscn")
	node.free()
	quit(0 if result == OK else 1)
