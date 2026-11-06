extends SceneTree
class FixtureDecks:
	extends CommunityDecksService
	var downloads := 0
	func _download(_url: String,path: String) -> bool:
		downloads+=1
		var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
		image.fill(Color("7e5c42"))
		return image.save_png(path)==OK
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func settle(frames:=5) -> void:
	for i in frames: await process_frame
func run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	var fake := preload("res://tests/community_claims/fake_game.gd").new()
	root.add_child(fake)
	fake.access_token="fixture-not-real"
	services.client=fake;services.session.client=fake
	services.session.user={"id":fake.OWNER}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	services.session.set_process(false)
	services.community_decks.queue_free()
	var community := FixtureDecks.new()
	services.community_decks=community
	services.add_child(community)
	await settle()
	check(CommunityDecksService.valid_manifest(fake.manifest()),"contrato de versão usa IDs estáveis de cartas")
	var invalid := fake.manifest();invalid.cards[0].id="../private"
	check(not CommunityDecksService.valid_manifest(invalid),"referência arbitrária não entra no catálogo")
	var result := await community.refresh()
	check(result.ok and community.playable().is_empty(),"conta sem resgate não recebe deck jogável")
	result=await community.claim(fake.DECK)
	check(result.ok and community.is_claimed(fake.DECK),"resgate só fica confirmado após resposta do servidor")
	check(community.playable().size()==1 and fake.claim_calls==1,"deck resgatado aparece no inventário da conta")
	result=await community.claim(fake.DECK)
	check(result.ok and result.data.already_owned and community.owned.size()==1,"resgate repetido não duplica coleção")
	var downloaded_cover := community.downloads
	check(downloaded_cover==1,"resgate prepara apenas a capa da coleção antes de jogar")
	result=await community.ensure_ready([fake.REF])
	check(result.ok and community.downloads==downloaded_cover+5,"cinco prévias do duelo são baixadas sem originais")
	await community.ensure_ready([fake.REF])
	check(community.downloads==downloaded_cover+5,"imagens em cache não são baixadas novamente")
	check(DuelService.card_name(str(fake.manifest().cards[0].id))=="Carta 0" and DuelService.card_texture(str(fake.manifest().cards[0].id))!=null,"batalha resolve nome e textura da carta comunitária")
	services.duel.local_server.community_decks=community.local_entries()
	var local := services.duel.local_server
	check(FileAccess.file_exists(community.cover_image(fake.REF)),"seletor do duelo reutiliza a capa da versão resgatada")
	var settings := local.default_settings();settings.deck_ids=[fake.REF]
	result=local.call_rpc("qse_duel_create",{"p_name":"[TESTE] Comunidade","p_settings":settings})
	check(result.ok,"sala com bots aceita o deck resgatado")
	if result.ok:
		var room_id: String=result.data.room.id
		result=local.call_rpc("qse_duel_add_bot",{"p_room":room_id})
		check(result.ok,"bot entra na sala com deck comunitário")
		result=local.call_rpc("qse_duel_start",{"p_room":room_id})
		check(result.ok,"partida local inicia usando o catálogo existente")
		check(local._match.pool.size()==5 and str(local._match.pool[0]).begins_with(fake.REF+"/"),"pool da partida contém as cartas comunitárias, sem substituição")
		local.clock_offset+=6
		local.call_rpc("qse_duel_room",{"p_room":room_id})
		result=local.call_rpc("qse_duel_select",{"p_room":room_id,"p_cards":local._match.pool.slice(0,3)})
		check(result.ok,"seleção de cartas funciona com o mesmo motor de partida")
	result=await community.open_owned(fake.REF)
	check(result.ok and result.data.cards.size()==5,"biblioteca abre o deck salvo na conta")
	check(community.library_entries()[0].owned and community.library_entries()[0].creator=="Criador de teste","coleção identifica posse e criador real do contrato")
	# Real native library controls: claim action -> confirmed account state.
	fake.claimed=false
	await community.refresh()
	community.clear()
	var screen: Control=load("res://scenes/player/deck_library.tscn").instantiate()
	root.add_child(screen)
	await settle()
	var item := {"id":fake.DECK,"name":"[TESTE] Comunidade","creator":"Criador de teste","category":"Personagens","description":"","official":false,"community":true,"tags":[],"age_rating":"","content_warnings":[],"cards":[],"count":5}
	for card: Dictionary in fake.manifest().cards: item.cards.append({"id":str(card.id),"name":str(card.name),"description":"","image":"res://assets/duel/decks/oficial/lendas_urbanas/momo.png"})
	screen._render_deck(item)
	await settle()
	var claim_button: Button=screen.find_child("RedeemCommunityDeck",true,false)
	check(claim_button!=null and not claim_button.disabled,"galeria mostra Resgatar grátis para conta elegível")
	if claim_button!=null: claim_button.pressed.emit()
	await settle(30)
	check(screen.find_child("RedeemCommunityDeck",true,false)==null and community.is_claimed(fake.DECK),"ação nativa confirma o resgate e troca o botão pelo estado da conta")
	screen._types={"mine":true}
	var entries: Array=screen._entries().filter(func(e:Dictionary)->bool:return e.get("owned",false) and str(e.get("id",""))==fake.DECK)
	check(entries.size()==1 and screen._matches(entries[0]),"Meus Decks inclui o resgate uma única vez, com o criador")
	screen.queue_free();await settle()
	var restored := FixtureDecks.new();services.add_child(restored)
	services.community_decks=restored
	restored._adopt_owner()
	check(restored.owned.size()==1,"coleção é recuperável após reabrir a sessão no aparelho")
	fake.claimed=false
	await restored.refresh()
	fake.hold_inventory=true
	restored.refresh();await settle()
	restored.claim(fake.DECK);await settle()
	fake.hold_inventory=false;await settle(40)
	check(restored.owned.size()==1,"resposta antiga do inventário não apaga um resgate confirmado")
	restored.clear();services.session.user={}
	check(restored.playable().is_empty() and CommunityDecksService.cards.is_empty(),"logout remove posse e cartas da memória ativa")
	services.session.user={"id":"00000000-0000-4000-8000-00000000c099"}
	check(restored.playable().is_empty(),"outra conta não herda a coleção local")
	services.session.user={"id":fake.OWNER};restored.clear();fake.hold_claim=true
	restored.claim(fake.DECK)
	await settle()
	services.session.user={};restored.clear();fake.hold_claim=false
	await settle()
	check(restored.owned.is_empty() and not restored.is_claimed(fake.DECK),"resposta atrasada de resgate não afeta outra sessão")
	services.queue_free();fake.queue_free()
	await settle()
	print("COMMUNITY_CLAIMS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
