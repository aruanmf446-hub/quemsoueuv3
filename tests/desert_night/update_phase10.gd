extends SceneTree
func _initialize() -> void:
	var scene := Node3D.new()
	scene.name = "DesertPhase10"
	scene.set_script(load("res://scripts/desert/t15d/phase.gd"))
	scene.phase_path = "res://data/desert/phase_10.json"
	var packed := PackedScene.new()
	packed.pack(scene)
	var error := ResourceSaver.save(packed,"res://scenes/desert/phase_10.tscn")
	scene.free()
	print("PHASE10_SAVE ",error)
	quit.call_deferred(error)
