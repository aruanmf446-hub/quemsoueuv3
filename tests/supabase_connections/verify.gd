extends SceneTree
## Três conexões Supabase (game, chat, catalog) no Godot real, sem credenciais.
##   godot --headless --path . --script res://tests/supabase_connections/verify.gd
const ENV := ["QSE_SUPABASE_CHAT_URL", "QSE_SUPABASE_CHAT_PUBLISHABLE_KEY", "QSE_SUPABASE_CATALOG_URL",
	"QSE_SUPABASE_GAME_PUBLISHABLE_KEY"]
var checks := 0
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("SUPABASE_CONNECTIONS_FAIL " + message)


func client(connection: String) -> Node:
	var node: Node = load("res://scripts/services/supabase_client.gd").new()
	node.connection = connection
	root.add_child(node)
	return node


func _run() -> void:
	for name in ENV: OS.unset_environment(name)
	# Inicialização: a conexão atual (game) igual a antes; chat e catalog preparadas e vazias.
	var services: Node = load("res://scripts/services/player_services.gd").new()
	root.add_child(services)
	for _frame in range(5): await process_frame
	check(services.client.connection == "game", "client continua sendo a conexão game")
	check(services.client.endpoint == "https://shuzporktifgiotvnpbz.supabase.co", "URL da game inalterada")
	check(services.client.configured(), "GAME com chave publicavel configurada")
	for extra in [services.chat_client, services.catalog_client]:
		check(extra.configured() and not extra.endpoint.is_empty(), "%s configurado" % extra.connection)
	check(services.session.client == services.client, "login segue vinculado a GAME sem chamada real")
	check(not services.session.authenticated(), "sem sessão")
	check(services.inventory.entries.size() > 0, "catálogo local de personagens (skins)")
	var chat_call: Dictionary = await services.chat_client.call_rpc("qualquer")
	check(str(chat_call.code) == "not_authenticated", "chat nao compartilha sessao GAME")

	# Sessão (JWT) só na game: nunca vai para outro projeto.
	services.chat_client.set_session("token.de.teste")
	services.catalog_client.set_session("token.de.teste")
	check(services.chat_client.access_token.is_empty() and services.catalog_client.access_token.is_empty(), "JWT recusado fora da game")
	services.client.set_session("token.de.teste")
	check(services.client.access_token == "token.de.teste", "JWT aceito na game")
	services.client.set_session("")

	# Configuração independente por conexão (ambiente), com validação.
	OS.set_environment("QSE_SUPABASE_CHAT_URL", "https://abcdefghijklmnopqrst.supabase.co/")
	OS.set_environment("QSE_SUPABASE_CHAT_PUBLISHABLE_KEY", "sb_publishable_teste")
	OS.set_environment("QSE_SUPABASE_CATALOG_URL", "https://exemplo.com")
	var chat := client("chat")
	var catalog := client("catalog")
	var game := client("game")
	check(chat.configured() and chat.endpoint == "https://abcdefghijklmnopqrst.supabase.co", "chat configurável por ambiente")
	check(catalog.endpoint.is_empty() and not catalog.configured(), "URL que não é Supabase é recusada")
	check(game.configured(), "variáveis do chat não afetam a game")
	OS.set_environment("QSE_SUPABASE_GAME_PUBLISHABLE_KEY", "sb_secret_nao_pode")
	var refused := client("game")
	check(refused.publishable_key.is_empty(), "chave secreta recusada")
	for name in ENV: OS.unset_environment(name)

	for node in [chat, catalog, game, refused, services]: node.free()
	for _frame in range(5): await process_frame
	print("SUPABASE_CONNECTIONS ", "FAIL" if failed else "PASS", " ", checks, " verificações")
	quit(1 if failed else 0)
