extends SceneTree
const Arena = preload("res://scripts/desert/malagueta/arena.gd")
func _initialize() -> void:
	var scene := Node3D.new()
	scene.name="DesertPhase10"
	scene.set_script(Arena)
	scene.set("phase_path","res://data/desert/phase_10.json")
	print("SCENE_SCRIPT ",scene.get_script())
	var out := PackedScene.new()
	assert(out.pack(scene)==OK)
	assert(ResourceSaver.save(out,"res://scenes/desert/phase_10.tscn")==OK)
	scene.free()
	quit()
