extends SceneTree
## Executar apenas via with_published_fixture.py: assets temporários e sem rede.
const ID := "repo_ffffffffffffffffffffffff"
const Art = preload("res://scripts/decks/repository_art.gd")
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("REPO_PUBLISHED_FAIL "+message)
func _run() -> void:
	var deck := Catalog.find_deck(ID)
	check(not deck.is_empty() and deck.cards.size()==5,"catálogo reconhece cinco imagens aprovadas")
	if deck.is_empty():
		quit(1)
		return
	check(not deck.official and deck.creator=="Fixture local","deck da comunidade não recebe selo oficial")
	check(Catalog.decks().any(func(row: Dictionary)->bool:return row.id==ID),"biblioteca inclui o deck aprovado")
	check(not Catalog.find_deck("lendas_urbanas").is_empty(),"catálogo oficial preservado")
	var id := ID+"/card_01"
	var portrait := DeckCover.load_texture(Art.ROOT+"/"+id+".webp")
	var duel := DuelService.card_texture(id)
	check(portrait!=null and absf(portrait.get_width()/float(portrait.get_height())-CardFramer.LIBRARY_ASPECT)<0.01,"biblioteca aplica recorte retrato")
	check(duel!=null and absf(duel.get_width()/float(duel.get_height())-CardFramer.DUEL_ASPECT)<0.01,"duelo aplica recorte horizontal")
	check(DuelService.card_name(id)=="Carta 1","nome da carta vem do metadata aprovado")
	check(DeckCover.load_texture(deck.cover_path)!=null,"capa publicada carrega")
	check(Art.texture(ID+"/../card_01")==null and Art.texture("repo_"+"a".repeat(24)+"/card_01")==null,"recusa caminhos inválidos e não aprovados")
	var server := LocalDuelServer.new()
	root.add_child(server)
	var available: Array=server.decks().filter(func(row: Dictionary)->bool:return row.id==ID)
	check(available.size()==1 and available[0].cards.size()==5,"duelo local lista o deck aprovado")
	var created := server.call_rpc("qse_duel_create",{"p_name":"Teste do repositório","p_settings":{"deck_ids":[ID]}})
	check(created.ok,"cria sala usando somente o deck novo")
	if created.ok:
		var room_id := str(server._room.id)
		check(server.call_rpc("qse_duel_add_bot",{"p_room":room_id}).ok,"bot entra na sala")
		check(server.call_rpc("qse_duel_start",{"p_room":room_id}).ok,"partida começa com o deck novo")
		check(server.call_rpc("qse_duel_select",{"p_room":room_id,"p_cards":[ID+"/card_01",ID+"/card_02",ID+"/card_03"]}).ok,"seleção aceita as três cartas publicadas")
	server.queue_free()
	await process_frame
	print("REPOSITORY_PUBLISHED checks=",checks," failures=",failures)
	quit(1 if failures else 0)
