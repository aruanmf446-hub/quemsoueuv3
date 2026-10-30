extends SceneTree
## Requisições por cenário, com cliente de contagem (fixture local, sem rede).
##   godot --headless --path . --script res://tests/consumption/verify.gd
var checks := 0
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CONSUMPTION_FAIL " + message)


func _run() -> void:
	var services: Node = load("res://scripts/services/player_services.gd").new()
	root.add_child(services)
	for _frame in range(5): await process_frame
	var counter: Node = load("res://tests/consumption/counting_client.gd").new()
	root.add_child(counter)
	counter.access_token = "token.de.teste"
	for service in [services.wallet, services.friends, services.progression, services.profile]: service.client = counter
	services.session.client = counter
	services.session.user = {"id": "00000000-0000-4000-8000-000000000001"}
	services.session._expires_at = Time.get_unix_time_from_system() + 3600.0

	# 1) Uma hora de poller (120 ciclos de 30 s). Antes: 3 consultas por ciclo = 360.
	for _tick in range(120):
		for service in [services.wallet, services.friends, services.progression]:
			if service.fetched_at != service.NEVER: service.fetched_at -= 30.0
		var before: Dictionary = counter.by_path.duplicate()
		services._poll_connected()
		for _frame in range(2): await process_frame
		# A fixture não devolve contratos válidos: o que foi buscado neste ciclo conta como resposta válida.
		for pair in [[services.wallet, "qse_wallet"], [services.friends, "qse_friends"], [services.progression, "qse_progression_snapshot"]]:
			var path: String = "/rest/v1/rpc/" + pair[1]
			if int(counter.by_path.get(path, 0)) > int(before.get(path, 0)): pair[0].fetched_at = Time.get_ticks_msec() / 1000.0
	var polled: int = counter.count
	print("CONSUMO poller_1h antes=360 depois=", polled)
	check(polled <= 100, "poller reduzido")

	# 2) Mesma leitura pedida 3 vezes ao mesmo tempo (telas + poller): 1 requisição.
	counter.count = 0
	services.wallet.refresh()
	services.wallet.refresh()
	await services.wallet.refresh()
	print("CONSUMO leituras_simultaneas antes=3 depois=", counter.count)
	check(counter.count == 1, "leituras simultâneas compartilhadas")

	# 3) Sem foco: nenhuma consulta.
	counter.count = 0
	services._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for service in [services.wallet, services.friends, services.progression]: service.fetched_at = service.NEVER
	services._poll_connected()
	await process_frame
	check(counter.count == 0, "sem consultas em segundo plano")
	services._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame

	# 4) CATALOG: 1ª abertura lê 3 tabelas e grava cache; aberturas seguintes, 0.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://catalog_cache.json"))
	counter.count = 0
	services.catalog.client = counter
	await services.catalog.refresh()
	var first: int = counter.count
	await services.catalog.refresh()
	await services.catalog.refresh()
	print("CONSUMO catalogo_3_aberturas antes=9 depois=", counter.count)
	check(first == 3 and counter.count == 3, "cache do catálogo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://catalog_cache.json"))

	# 5) Duelo: intervalos por hora (lobby e lista de salas).
	var lobby: float = 3600.0 / services.duel.HEARTBEAT_SECONDS
	print("CONSUMO duelo_lobby_1h antes=1800 depois=", int(lobby))
	check(lobby <= 720.0, "heartbeat do lobby")
	check(services.chat.send("x", "oi").code == "chat_unavailable", "chat desativado")

	services.session.user = {}
	counter.access_token = ""
	services.free()
	counter.free()
	for _frame in range(5): await process_frame
	print("CONSUMPTION ", "FAIL" if failed else "PASS", " ", checks, " verificações")
	quit(1 if failed else 0)
