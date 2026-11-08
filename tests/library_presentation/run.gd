extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var fixture=load("res://tests/library_presentation/fixture.gd").new()
 root.add_child(fixture)
 for i in 90:await process_frame
 quit()
