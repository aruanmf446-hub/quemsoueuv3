extends Node
## CHAT pela interface do painel Amigos, com o transporte simulado (fixture_transport.gd).
## Sem rede e sem credenciais. Executado por flow_test.gd.
signal finished(code: int)
const ME := "00000000-0000-4000-8000-0000000000aa"
const LUA := "00000000-0000-4000-8000-0000000000b1"
const ROOK := "00000000-0000-4000-8000-0000000000b2"
var services: Node
var screen: Control
var chat: Node
var fake: Node
var checks := 0
var failed := false
var shots := ""
var label := ""


func _ready() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("CHAT_FAIL " + message)


func settle(frames := 4) -> void:
	for _frame in range(frames): await get_tree().process_frame


func shot(name: String) -> void:
	if shots.is_empty(): return
	await settle(8)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("%s/%s_%s.png" % [shots, label, name])


func find_button(text: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree() and (node as Button).text == text: return node
	return null


func bubbles(kind: String) -> int:
	return screen.find_children(kind, "PanelContainer", true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


## Aviso da conversa atual (procurado de novo: reabrir a conversa recria a interface).
func status() -> Label:
	for node: Node in screen.find_children("ChatStatus", "Label", true, false):
		if not node.is_queued_for_deletion(): return node
	return Label.new()


func total_calls() -> int:
	return fake.calls.open + fake.calls.messages + fake.calls.send


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		shots = args[0]
		label = args[1]
		var size := args[1].split("x")
		get_tree().root.mode = Window.MODE_WINDOWED
		get_tree().root.size = Vector2i(int(size[0]), int(size[1]))
	services = load("res://scripts/services/player_services.gd").new()
	get_tree().root.add_child(services)
	await settle()
	# Sessão e amigos simulados (FIXTURE): nada vai à rede.
	for service in [services.friends, services.wallet, services.progression, services.profile]:
		service.fetched_at = Time.get_ticks_msec() / 1000.0
	services.session.user = {"id": ME}
	services.session._expires_at = Time.get_unix_time_from_system() + 3600.0
	services.client.access_token = "token.de.teste"
	services.friends.data = {"friends": [{"user_id": LUA, "public_id": "LUA1", "nickname": "Lua", "equipped_character_id": "lana"},
		{"user_id": ROOK, "public_id": "ROOK1", "nickname": "Rook", "equipped_character_id": "cowboy"}], "incoming": [], "outgoing": []}
	services.friends.state = "success"
	chat = services.chat
	chat.me_id = ME
	check(chat.transport == null, "gateway real desligado por padrão")
	fake = load("res://tests/chat/fixture_transport.gd").new()
	fake.friends = [LUA, ROOK]
	chat.add_child(fake)
	chat.transport = fake
	screen = load("res://scenes/player/friends.tscn").instantiate()
	get_tree().root.add_child(screen)
	screen.show_screen({})
	await settle(10)
	await shot("01_amigos")

	# 11. Chat fechado: nenhuma consulta.
	await settle(30)
	check(total_calls() == 0 and chat.state == "closed", "fechado não consulta")

	# 2/1. Selecionar amigo e abrir.
	var talk: Button = screen.find_child("Talk", true, false)
	check(talk != null, "botão Conversar")
	talk.pressed.emit()
	await settle(8)
	check(chat.is_open() and fake.calls.open == 1 and fake.calls.messages == 1, "abre a conversa com uma leitura")
	check(screen.find_child("ChatPanel", true, false) != null, "painel da conversa")
	check(status().visible and status().text.contains("Nenhuma mensagem"), "estado vazio")
	await shot("02_vazio")

	# 6. Vazia não envia.
	var input: LineEdit = screen.find_child("ChatInput", true, false)
	input.text = "   "
	(screen.find_child("ChatSend", true, false) as Button).pressed.emit()
	await settle()
	check(fake.calls.send == 0, "mensagem vazia bloqueada")

	# 4. Enviar.
	input.text = "Oi! Bora jogar um Duelo?"
	(screen.find_child("ChatSend", true, false) as Button).pressed.emit()
	await settle(6)
	check(fake.calls.send == 1 and bubbles("Mine") == 1 and input.text.is_empty(), "mensagem enviada aparece")

	# 7. Duplo envio simultâneo: só um vai.
	chat.send("Tô no lobby")
	var second: Dictionary = await chat.send("Tô no lobby")
	await settle(4)
	check(fake.calls.send == 2 and str(second.code) == "duplicate_send", "envio duplicado bloqueado")

	# 5. Receber.
	fake.deliver("conv-" + LUA, LUA, "Bora! Cria a sala que eu entro.")
	fake.deliver("conv-" + LUA, LUA, "Leva o deck Lendas Urbanas 👻")
	await chat.poll()
	await settle(6)
	check(bubbles("Theirs") == 2 and bubbles("Mine") == 2, "mensagens recebidas")
	await shot("03_mensagens")

	# 8. Expiradas: a do passado não aparece; a que venceu some.
	fake.deliver("conv-" + LUA, LUA, "mensagem antiga", 25 * 3600.0)
	(fake.store["conv-" + LUA] as Array)[0].expires_at = Time.get_unix_time_from_system() - 1.0
	await chat.poll()
	await settle(6)
	check(bubbles("Mine") == 1 and bubbles("Theirs") == 2, "mensagens vencidas somem")

	# 9/12. Sem conexão e reconexão.
	fake.fail_next = "network"
	await chat.poll()
	await settle()
	check(status().visible and status().text.contains("Sem conexão") and bubbles("Theirs") == 2, "aviso de conexão sem perder mensagens")
	await shot("04_sem_conexao")
	await chat.poll()
	await settle()
	check(chat.error_code.is_empty() and not status().text.contains("Sem conexão"), "retoma após reconectar")

	# Segundo plano: nada consultado.
	var before := total_calls()
	chat._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var skipped: Dictionary = await chat.poll()
	check(str(skipped.code) == "skipped" and total_calls() == before, "pausa em segundo plano")
	chat._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

	# Reabrir conversa existente: não cria outra.
	(screen.find_child("CloseChat", true, false) as Button).pressed.emit()
	await settle(4)
	check(chat.state == "closed" and screen.find_child("ChatPanel", true, false) == null, "fecha o chat")
	before = total_calls()
	await settle(30)
	check(total_calls() == before, "fechado não consulta")
	(screen.find_child("Talk", true, false) as Button).pressed.emit()
	await settle(8)
	check(fake.calls.open == 1 and chat.conversation_id == "conv-" + LUA, "conversa existente reaproveitada")

	# Amizade removida / jogador não autorizado.
	var stranger: Dictionary = await chat.open({"user_id": "00000000-0000-4000-8000-0000000000ff", "nickname": "X"})
	check(not stranger.ok and str(stranger.code) == "not_friend", "não autorizado não conversa")
	await chat.open(services.friends.data.friends[0])
	await settle(6)

	# 10. Sessão expirada.
	fake.fail_next = "not_authenticated"
	await chat.poll()
	await settle()
	check(chat.state == "error" and status().text.contains("sessão"), "sessão expirada")
	await shot("05_sessao_expirada")

	# Troca de conta: nada fica em memória.
	chat.clear()
	check(chat.messages("conv-" + LUA).is_empty(), "limpa ao trocar de conta")

	# Lido antes de liberar: o transporte simulado é filho do ChatService.
	var calls: Dictionary = fake.calls.duplicate()
	services.session.user = {}
	services.client.access_token = ""
	screen.queue_free()
	services.queue_free()
	await settle(10)
	print("CHAT_FLOW ", "FAIL" if failed else "PASS", " ", checks, " verificações; requisições do fixture: ", calls)
	finished.emit(1 if failed else 0)
