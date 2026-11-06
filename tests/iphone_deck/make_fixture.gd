extends SceneTree
func _initialize() -> void:
	if not FileAccess.file_exists("res://.iphone_web_fixture_stage"):
		quit(1)
		return
	var node := Node.new()
	node.name="DeckInputFixture"
	node.set_script(load("res://tests/iphone_deck/web_fixture.gd"))
	var scene := PackedScene.new()
	var result := scene.pack(node)
	if result==OK: result=ResourceSaver.save(scene,"res://tests/iphone_deck/web_fixture.tscn")
	node.free()
	quit(0 if result==OK else 1)
