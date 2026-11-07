extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var node:=Node.new()
 node.name="ControlModesFixture"
 node.set_script(preload("res://tests/control_modes/fixture.gd"))
 var packed:=PackedScene.new()
 packed.pack(node)
 var result:=ResourceSaver.save(packed,"res://tests/control_modes/fixture.scn")
 node.free()
 if result!=OK:quit(1);return
 ProjectSettings.set_setting("application/run/main_scene","res://tests/control_modes/fixture.scn")
 ProjectSettings.save()
 quit(0)
