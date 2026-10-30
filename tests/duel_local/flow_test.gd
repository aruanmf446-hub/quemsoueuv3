extends SceneTree
## Partida local do Duelo no Godot real: abre a tela sem conta, cria a sala local, adiciona
## bots, joga a seleção e os turnos pela interface até o fim, e confere as regras no
## LocalDuelServer (mesmas do servidor online). Sem rede e sem Supabase.
##   godot --headless --path . --script res://tests/duel_local/flow_test.gd
## Com display, fotografa cada etapa:
##   godot --path . --script res://tests/duel_local/flow_test.gd -- <pasta> <largura>x<altura>
var screen: PlayerScreen
var services: PlayerServices
var duel: DuelService
var server: LocalDuelServer
var checks := 0
var shots := ""
var label := ""


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("DUEL_LOCAL_FAIL " + message)
		quit(1)
		assert(value, message)


func settle(frames := 4) -> void:
	for frame in range(frames): await process_frame


func shot(name: String) -> void:
	if shots.is_empty(): return
	await settle(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [shots, label, name])
	print("CAPTURE ", name)


## Avança o relógio da partida local e deixa o servidor processar os prazos vencidos.
func skip(seconds: float) -> void:
	server.clock_offset += seconds
	await duel.refresh()
	await settle()


func button(text: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		var item := node as Button
		if item.is_visible_in_tree() and item.text == text: return item
	return null


func press(text: String) -> void:
	var item := button(text)
	check(item != null and not item.disabled, "botão '%s' disponível" % text)
	item.pressed.emit()
	await settle()


func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	control.gui_input.emit(event)
	await settle()


func match_view() -> Node:
	return screen.body.get_node_or_null("Match")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		shots = args[0]
		label = args[1]
		var size := args[1].split("x")
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(int(size[0]), int(size[1]))
		DirAccess.make_dir_recursive_absolute(shots)
	services = PlayerServices.new()
	root.add_child(services)
	await settle()
	duel = services.duel
	server = duel.local_server
	server.rng.seed = 7
	check(not services.session.authenticated(), "sem conta")
	_rules()
	screen = load("res://scenes/player/duel.tscn").instantiate()
	root.add_child(screen)
	screen.show_screen({})
	await settle(10)

	# Sem conta: a entrada é a partida local (antes a tela só pedia login).
	check(button("Criar partida local") != null, "partida local disponível sem conta")
	await shot("01_entrada")
	await press("Criar partida local")
	await settle(4)
	check(duel.is_local(), "modo local")
	check(screen.get("_view") == "form", "formulário da partida local")
	check(button("Sala pública") == null and button("Só por convite") == null, "partida local sem opção pública")
	(screen.get("_form").cards_per_player as SpinBox).value = 2
	(screen.get("_form").max_players as SpinBox).value = 4
	await shot("02_criar")
	await press("Criar sala")
	check(duel.in_room(), "sala local criada")
	var room: Dictionary = duel.room.room
	check(not bool(room.is_public) and bool(room.get("is_local", false)), "sala local nunca é pública")
	check(screen.find_child("LocalBadge", true, false) != null, "selo PARTIDA LOCAL")
	check(button("Código  %s" % str(room.code)) == null, "sem código de convite")
	check(duel.is_admin(), "jogador é o ADM")
	await press("Adicionar bot")
	await press("Adicionar bot")
	var members: Array = duel.room.members
	check(members.size() == 3 and members.filter(func(m: Dictionary) -> bool: return m.is_bot).size() == 2, "dois bots na sala")
	check(not members.any(func(m: Dictionary) -> bool: return m.is_bot and m.is_admin), "bot nunca é ADM")
	var listed := await duel.list_rooms("", false)
	check(listed.ok and (listed.data.rooms as Array).is_empty(), "sala local não aparece em lista")
	await shot("03_lobby")

	# Seleção secreta pela interface.
	await press("Iniciar partida")
	var data := duel.match()
	check(str(data.phase) == "selection", "seleção secreta")
	check((data.players as Array).filter(func(p: Dictionary) -> bool: return p.is_bot and p.confirmed).size() == 2, "bots prontos na hora")
	check(match_view() != null, "tela da partida")
	var pool: Array = data.pool
	var real_cards := pool.all(func(c: Dictionary) -> bool: return ResourceLoader.exists("res://assets/duel/decks/%s.png" % c.card_id))
	check(pool.size() >= 9 and real_cards, "cartas reais de assets/duel/decks")
	await shot("04_selecao")
	var grid: Control = match_view().find_child("Cards", true, false)
	await click(grid.get_child(0))
	await click(match_view().find_child("Cards", true, false).get_child(1))
	await shot("05_selecionadas")
	await press("Confirmar cartas")
	check(str(duel.match().phase) == "countdown", "todos prontos: contagem sem esperar")
	await shot("06_contagem")
	await skip(5.1)
	check(str(duel.match().phase) == "turns", "turnos começam")
	check((duel.match().turn_order as Array).size() == 3, "ordem sorteada com os 3")

	# Turnos até o fim: na sua vez, escolhe pela interface uma carta que não é sua.
	var picked_by_me := false
	for _step in range(80):
		data = duel.match()
		if str(duel.room.room.status) != "in_match" or str(data.get("phase", "")) == "finished": break
		var me: Dictionary = (data.players as Array).filter(func(p: Dictionary) -> bool: return p.is_you)[0]
		if str(data.phase) == "turns" and str(data.turn_member) == str(me.member_id):
			var mine: Array = (data.my_cards as Array).map(func(c: Dictionary) -> String: return str(c.card_id))
			var cards: Control = match_view().find_child("Cards", true, false)
			var target := -1
			for index in range(pool.size()):
				var item: Dictionary = (data.pool as Array)[index]
				if not item.removed and not mine.has(str(item.card_id)):
					target = index
					break
			if target < 0: target = (data.pool as Array).find_custom(func(c: Dictionary) -> bool: return not c.removed)
			if not picked_by_me: await shot("07_sua_vez")
			await click(cards.get_child(target))
			if not picked_by_me: await shot("08_confirmar")
			await press("Eliminar")
			check(str(duel.match().phase) == "reveal", "voto vira revelação")
			if not picked_by_me:
				await shot("09_revelando")
				await skip(2.6)
				await shot("10_atingidos")
			picked_by_me = true
		elif str(data.phase) == "reveal":
			await skip(6.6)
		else:
			await skip(2.6)
	check(picked_by_me, "jogador votou pela interface")
	data = duel.match()
	var status := str(duel.room.room.status)
	if status == "closed":
		# Sem jogador real vivo: a sala é encerrada e não há bot campeão.
		check(str(data.result.reason) == "only_bots" and (data.result.winners as Array).is_empty(), "nunca há bot campeão")
		await shot("11_fim")
		check(button("Voltar") != null, "aviso de sala encerrada")
	else:
		check(str(data.phase) == "finished", "partida termina")
		var result: Dictionary = data.result
		check(str(result.reason) in ["last_standing", "draw"], "fim com campeão ou empate")
		var alive := (data.players as Array).filter(func(p: Dictionary) -> bool: return not p.eliminated)
		check((result.winners as Array).size() == alive.size() and alive.size() <= 1, "vencedores = vivos")
		await shot("11_campeao")
		await skip(9.1)
		check(str(duel.room.room.status) == "lobby" and int(duel.room.room.settings.cards_per_player) == 2, "volta ao lobby com as configurações")
		await shot("12_lobby_de_novo")
	print("DUEL_LOCAL_RESULT ", status, " ", data.result)

	# Sair da partida local volta ao modo online (preparado para o Supabase).
	await duel.leave()
	await duel.use_online()
	check(not duel.is_local(), "volta ao modo online")
	var online := await duel.list_rooms("", true)
	# Sem sessão o cliente GAME recusa antes da rede (ou sem chave: not_configured).
	var expected := "not_authenticated" if services.client.configured() else "not_configured"
	check(not online.ok and str(online.code) == expected, "online continua indo ao Supabase GAME")
	screen.queue_free()
	await settle()
	services.queue_free()
	await settle()
	print("DUEL_LOCAL_PASS ", checks, " verificações")
	quit(0)


## Regras do servidor local conferidas diretamente (mesmos casos dos testes SQL).
func _rules() -> void:
	var local := LocalDuelServer.new()
	local.bot_skins = ["cowboy"]
	local.skin_provider = func() -> String: return "lana"
	local.rng.seed = 3
	root.add_child(local)
	var deck: Array = local.decks()
	check(not deck.is_empty() and deck[0].id == "lendas_urbanas" and (deck[0].cards as Array).size() >= 9, "deck lido das pastas")
	var bad := local.call_rpc("qse_duel_create", {"p_name": "Sala", "p_public": false, "p_settings": {"cards_per_player": 9}})
	check(not bad.ok and bad.code == "invalid_settings", "configuração validada")
	check(local.call_rpc("qse_duel_join", {"p_code": "ABCDEF"}).code == "room_not_found", "local não aceita convites")
	var made := local.call_rpc("qse_duel_create", {"p_name": "Regras", "p_public": true, "p_settings": {"cards_per_player": 2, "turn_seconds": 15}})
	var id := str(made.data.room.id)
	check(not bool(made.data.room.is_public), "pedido público vira local")
	check(local.call_rpc("qse_duel_start", {"p_room": id}).code == "not_enough_players", "precisa de 2 jogadores")
	local.call_rpc("qse_duel_add_bot", {"p_room": id})
	var started := local.call_rpc("qse_duel_start", {"p_room": id})
	var pool: Array = started.data.match.pool.map(func(c: Dictionary) -> String: return str(c.card_id))
	var bot_id := str((started.data.match.players as Array).filter(func(p: Dictionary) -> bool: return p.is_bot)[0].member_id)
	check(local.call_rpc("qse_duel_select", {"p_room": id, "p_cards": [pool[0], pool[0]]}).code == "invalid_selection", "cartas distintas")
	# Mesma carta que o bot: ao ser eliminada, atinge os dois (inclusive quem escolheu).
	var shared: String = local._cards[bot_id][0].card_id
	var other: String = pool.filter(func(c: String) -> bool: return c != shared and not local._cards[bot_id].any(func(k: Dictionary) -> bool: return k.card_id == c))[0]
	local.call_rpc("qse_duel_select", {"p_room": id, "p_cards": [shared, other]})
	local.clock_offset += 5.1
	var state := local.call_rpc("qse_duel_room", {"p_room": id})
	var me := str(state.data.you.member_id)
	# Força a vez do humano para conferir o voto.
	local._match.turn_order = [me, bot_id]
	local._match.turn_index = -1
	local._next_turn()
	check(local.call_rpc("qse_duel_pick", {"p_room": id, "p_card": "lendas_urbanas/nao_existe"}).code == "card_unavailable", "carta inexistente")
	var picked := local.call_rpc("qse_duel_pick", {"p_room": id, "p_card": shared})
	check(picked.ok and str(picked.data.match.phase) == "reveal", "voto aceito")
	check(local._player(me).lives == 1 and local._player(bot_id).lives == 1, "atinge todos que têm a carta, inclusive quem escolheu")
	var hidden: Dictionary = (picked.data.match.events as Array).back()
	check(not hidden.revealed and hidden.hits == null, "atingidos só depois do suspense")
	local.clock_offset += 6.6
	state = local.call_rpc("qse_duel_room", {"p_room": id})
	check(str(state.data.match.phase) == "turns" and str(state.data.match.turn_member) == bot_id, "vez passa ao próximo vivo")
	# Bot pensa 2,5 s e vota; sem voto do humano no prazo: falta (vida sem carta).
	local.clock_offset += 2.6
	local.call_rpc("qse_duel_room", {"p_room": id})
	check(str(local._match.phase) == "reveal" and str(local._events.back().kind) == "pick", "bot vota sozinho")
	local.clock_offset += 6.6
	state = local.call_rpc("qse_duel_room", {"p_room": id})
	if str(state.data.match.phase) == "turns" and str(state.data.match.turn_member) == me:
		var cards_before := (local._cards[me] as Array).filter(func(k: Dictionary) -> bool: return not k.lost).size()
		local.clock_offset += 15.1
		local.call_rpc("qse_duel_room", {"p_room": id})
		check(local._player(me).faults == 1, "falta registrada")
		check((local._cards[me] as Array).filter(func(k: Dictionary) -> bool: return not k.lost).size() == cards_before, "falta não tira carta")
	# Fim: sem jogador real vivo, a sala é encerrada (nunca há bot campeão).
	local._eliminate(me, "lives")
	local._match.phase = "reveal"
	local._match.phase_deadline = local.now()
	state = local.call_rpc("qse_duel_room", {"p_room": id})
	check(str(state.data.room.status) == "closed" and str(state.data.match.result.reason) == "only_bots", "só bots: sala encerrada")
	local.queue_free()
