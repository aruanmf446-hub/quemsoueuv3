extends SceneTree
## Partida local do Duelo no Godot real (fluxo em flow_runner.gd). O fluxo roda num nó que é
## liberado antes de encerrar: nada das telas fica vivo na saída do motor.
##   godot --headless --path . --script res://tests/duel_local/flow_test.gd
## Com display, fotografa cada etapa:
##   godot --path . --script res://tests/duel_local/flow_test.gd -- <pasta> <largura>x<altura>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runner: Node = load("res://tests/duel_local/flow_runner.gd").new()
	root.add_child(runner)
	var code: int = await runner.finished
	runner.free()
	for _frame in range(6): await process_frame
	quit(code)
