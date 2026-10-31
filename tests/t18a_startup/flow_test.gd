extends SceneTree
## T18A: valida a ordem real de abertura sem rede ou contas externas.
## godot --headless --path . --script res://tests/t18a_startup/flow_test.gd
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func verify(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("T18A_STARTUP_FAIL " + title)

func _run() -> void:
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var nav := menu.get_node("Navigation") as NavigationManager
	var history: Array = nav.get("_history")
	verify(history.size() == 1, "uma unica rota inicial")
	if history.size() == 1:
		verify(history[0].get("route", "") == "account", "primeira tela e account")
		verify(bool(history[0].get("params", {}).get("startup", false)), "rota sinaliza startup")
	else:
		verify(false, "primeira tela e account")
		verify(false, "rota sinaliza startup")
	var screen: PlayerScreen = nav.get("_active") as PlayerScreen
	verify(screen != null and screen.visible, "account visivel no primeiro frame")
	if screen != null:
		verify(screen.get_node_or_null("CinematicAuthOverlay") != null, "composicao cinematografica real")
		var back := screen.get_node_or_null("CinematicAuthOverlay/AuthBack") as Button
		verify(back != null and back.text == "Jogar sem conta", "guest e escolha explicita")
	else:
		verify(false, "composicao cinematografica real")
		verify(false, "guest e escolha explicita")
	verify(not bool(nav.get("_busy")), "sem LoadingVeil ou animacao inicial")
	# O convite sem sessao permanece na mesma conta, sem duplicacao de rotas.
	var invite := WebInviteIntent.new()
	invite.capture(true)
	verify(invite.next_route(false) == "account", "convite aguarda login")
	verify(invite.next_route(true) == "duel", "convite avanca apos login")
	# Acesso a demonstracao local so apos acao explicita do jogador.
	nav.back()
	await create_timer(0.23).timeout
	verify(nav.get("_history").is_empty(), "voltar voluntariamente ao lobby")
	print("T18A_STARTUP_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
