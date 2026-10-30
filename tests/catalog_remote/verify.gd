extends SceneTree
## Leitura do CATALOG: fallback local, mesclagem e compatibilidade com os decks do Duelo.
## As linhas abaixo são FIXTURE DE TESTE (não são dados reais do CATALOG).
##   godot --headless --path . --script res://tests/catalog_remote/verify.gd
## QSE_CATALOG_LIVE=1 também lê o CATALOG real (fora do smoke).
var checks := 0
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CATALOG_REMOTE_FAIL " + message)


func _run() -> void:
	var services: Node = load("res://scripts/services/player_services.gd").new()
	root.add_child(services)
	for _frame in range(5): await process_frame
	# Scripts carregados por load() em variáveis locais: nada fica vivo na saída do motor.
	var library: Script = load("res://scripts/decks/deck_library_catalog.gd")
	var catalog: Node = services.catalog
	check(catalog.client == services.catalog_client and catalog.client.connection == "catalog", "catálogo usa a conexão catalog")
	check(catalog.state == "local", "sem leitura remota: catálogo local")
	var local: Dictionary = library.find_deck("lendas_urbanas")
	check(local.get("count", 0) == 9 and local.name == "Lendas Urbanas", "biblioteca local intacta")
	services.client.set_session("token.de.teste")
	check(catalog.client.access_token.is_empty(), "JWT do GAME não vai ao CATALOG")
	services.client.set_session("")

	var cards: Array = catalog.local_cards("lendas_urbanas")
	check(cards.size() == 9, "9 cartas locais")
	var card_rows: Array = cards.map(func(c: String) -> Dictionary: return {"deck_id": "lendas_urbanas", "id": c.get_slice("/", 1)})
	catalog.apply([{"id": "cowboy", "name": "Cowboy"}, {"sem_id": true}], [{"id": "lendas_urbanas", "name": "Lendas (fixture)", "description": "Descrição remota"}], card_rows)
	check(catalog.state == "remote" and catalog.characters.size() == 1, "linhas inválidas descartadas")
	var merged: Dictionary = library.find_deck("lendas_urbanas")
	check(merged.name == "Lendas (fixture)" and merged.description == "Descrição remota" and merged.count == 9, "nome remoto, cartas locais")
	check(catalog.compatibility().lendas_urbanas.compatible, "deck remoto compatível com o Duelo local")
	catalog.apply([], [{"id": "lendas_urbanas"}], card_rows.slice(1))
	var report: Dictionary = catalog.compatibility().lendas_urbanas
	check(not report.compatible and report.missing_remotely.size() == 1, "carta faltando no remoto é detectada")
	check(library.find_deck("lendas_urbanas").name == "Lendas Urbanas", "deck remoto sem nome mantém o local")

	var offline: Node = load("res://scripts/services/catalog_service.gd").new()
	offline.client = load("res://scripts/services/supabase_client.gd").new()
	offline.client.connection = "catalog"
	root.add_child(offline.client)
	offline.client.endpoint = ""
	var result: Dictionary = await offline.refresh()
	check(not result.ok and offline.state == "local", "sem conexão: fallback local")
	offline.client.free()
	offline.free()

	if OS.get_environment("QSE_CATALOG_LIVE") == "1":
		var live: Dictionary = await catalog.refresh()
		print("CATALOG_LIVE ", live.ok, " ", live.code, " ", catalog.characters.size(), "/", catalog.decks.size(), " ", catalog.compatibility())
	services.free()
	for _frame in range(5): await process_frame
	print("CATALOG_REMOTE ", "FAIL" if failed else "PASS", " ", checks, " verificações")
	quit(1 if failed else 0)
