extends SceneTree
## T22 Amizades: quatro categorias, seleção, contadores e ações reais do FriendsService
## (qse_friend_action) contra um cliente FALSO com a fixture. Sem rede, sem Supabase.
const Fixture = preload("res://tests/friends_t22/fixture.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 6) -> void:
	for i in count: await process_frame


func _count(screen: Node, tab: String) -> String:
	var badge := screen.find_child("Tab_" + tab, true, false).find_child("Count", true, false) as Label
	return badge.text if badge != null else ""


func _run() -> void:
	root.size = Vector2i(1672, 941)
	var services := PlayerServices.new()
	root.add_child(services)
	await _frames(2)
	Fixture.apply(services)
	var fake: SupabaseClient = load("res://tests/friends_t22/fake_client.gd").new()
	fake.data = Fixture.data()
	root.add_child(fake)
	services.friends.client = fake
	var screen := load("res://scenes/player/friends.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await _frames()
	check(screen.find_child("Sidebar", true, false) != null and screen.find_child("MainPanel", true, false) != null, "barra lateral e painel principal")
	check(_count(screen, "friends") == "5" and _count(screen, "incoming") == "3" and _count(screen, "outgoing") == "2", "contadores reais")
	check((screen.find_child("PlayerName", true, false) as Label).text == "LunaPlayer", "primeiro amigo selecionado")
	check(screen.find_child("Invite", true, false) != null and screen.find_child("Talk", true, false) != null and screen.find_child("Remove", true, false) != null, "ações de amigo")
	(screen.find_child("Player_" + Fixture.player("", "", 2).public_id, true, false) as Button).pressed.emit()
	await _frames()
	check((screen.find_child("PlayerName", true, false) as Label).text == "CaioQuest", "seleção pela lista")
	# Recebidas: aceitar outra solicitação mantém a selecionada.
	screen._change_tab("incoming")
	await _frames()
	check((screen.find_child("PlayerName", true, false) as Label).text == "Misteriosa03", "Recebidas mostra o pedido")
	var other := screen.find_child("Request_" + Fixture.player("", "", 12).public_id, true, false)
	(other.find_child("AcceptOther", true, false) as Button).pressed.emit()
	await _frames(12)
	check(fake.calls.any(func(c: Array) -> bool: return c[0] == "qse_friend_action" and c[1].p_action == "accept"), "aceitar chama qse_friend_action")
	check(_count(screen, "incoming") == "2" and _count(screen, "friends") == "6", "contadores atualizam após aceitar")
	check((screen.find_child("PlayerName", true, false) as Label).text == "Misteriosa03", "seleção preservada após responder outra")
	(screen.find_child("Decline", true, false) as Button).pressed.emit()
	await _frames(12)
	check(_count(screen, "incoming") == "1", "recusar atualiza a lista")
	# Enviadas: cancelar.
	screen._change_tab("outgoing")
	await _frames()
	check(screen.find_child("CancelRequest", true, false) != null and (screen.find_child("Talk", true, false) as Button).disabled, "Enviadas: cancelar e chat bloqueado para não amigos")
	(screen.find_child("CancelRequest", true, false) as Button).pressed.emit()
	await _frames(12)
	check(_count(screen, "outgoing") == "1", "cancelar atualiza contador e seleção")
	# Remover amizade pede confirmação.
	screen._change_tab("friends")
	await _frames()
	(screen.find_child("Remove", true, false) as Button).pressed.emit()
	await _frames()
	var dialog := screen.find_child("ConfirmRemove", true, false) as ConfirmationDialog
	check(dialog != null, "remover pede confirmação")
	var before := int(_count(screen, "friends"))
	dialog.confirmed.emit()
	await _frames(12)
	check(int(_count(screen, "friends")) == before - 1, "remover amizade aplica")
	# Buscar: botões conforme a relação.
	screen._change_tab("search")
	screen._results = Fixture.search_results()
	screen._searched = true
	screen.render()
	await _frames()
	check(screen.find_child("AddFriend", true, false) != null, "Buscar: Adicionar amigo para desconhecido")
	screen._select(Fixture.search_results()[1])
	await _frames()
	check(screen.find_child("Invite", true, false) != null, "Buscar: amigo já existente mostra ações de amigo")
	# Estado vazio.
	fake.data = {"friends": [], "incoming": [], "outgoing": []}
	await services.friends.refresh()
	screen._change_tab("friends")
	await _frames()
	check(screen.find_child("EmptyState", true, false) != null and screen.find_child("GoSearch", true, false) != null, "conta sem amizades mostra estado vazio")
	print("T22_FRIENDS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
