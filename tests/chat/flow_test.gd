extends SceneTree
## CHAT no painel Amigos (fluxo em flow_runner.gd, transporte simulado).
##   godot --headless --path . --script res://tests/chat/flow_test.gd
##   godot --path . --script res://tests/chat/flow_test.gd -- <pasta> <largura>x<altura>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runner: Node = load("res://tests/chat/flow_runner.gd").new()
	root.add_child(runner)
	var code: int = await runner.finished
	runner.queue_free()
	for _frame in range(6): await process_frame
	quit(code)
