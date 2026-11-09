extends SceneTree
func _initialize() -> void:
	var node:=Node.new()
	node.name="BossFixture"
	node.set_script(load("res://tests/malagueta/web_fixture.gd"))
	var packed:=PackedScene.new()
	assert(packed.pack(node)==OK)
	assert(ResourceSaver.save(packed,"res://tests/malagueta/web_fixture.tscn")==OK)
	node.free()
	quit()
