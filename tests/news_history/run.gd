extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 root.add_child(load("res://tests/news_history/fixture.gd").new())
 for i in 75:await process_frame
 quit(0 if bool(get_meta("news_history_passed",false)) else 1)
