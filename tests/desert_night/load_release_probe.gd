extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var stage = load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(stage)
	for frame in range(12): await process_frame
	stage.queue_free()
	for frame in range(12): await process_frame
	quit()
