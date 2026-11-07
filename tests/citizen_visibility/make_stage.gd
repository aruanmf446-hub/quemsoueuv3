extends SceneTree
func _initialize() -> void:
 var node:=Node.new()
 node.name="CitizenVisibilityFixture"
 node.set_script(load("res://tests/citizen_visibility/fixture.gd"))
 var scene:=PackedScene.new()
 scene.pack(node)
 var error:=ResourceSaver.save(scene,"res://tests/citizen_visibility/fixture.scn")
 node.free()
 if error!=OK:quit(1);return
 ProjectSettings.set_setting("application/run/main_scene","res://tests/citizen_visibility/fixture.scn")
 ProjectSettings.save()
 quit()
