extends SceneTree
var failures := 0
var checks := 0
var output := ""
var dimensions := "1672x941"
const OWNER := "00000000-0000-4000-8000-0000000000a7"
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func settle(count:=20) -> void:
	for frame in count: await process_frame
func shot(name: String) -> void:
	if output.is_empty(): return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+dimensions+"_"+name+".png")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>1:
		output=args[0];dimensions=args[1]
		DirAccess.make_dir_recursive_absolute(output)
	var dims := dimensions.split("x")
	root.size=Vector2i(int(dims[0]),int(dims[1]))
	UIScale.apply_device_profile(root)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle(4)
	var fake := preload("res://tests/community_attribution/fake_game.gd").new()
	root.add_child(fake)
	fake.user=OWNER;fake.access_token="fixture-not-real"
	services.client=fake;services.session.client=fake
	services.session.user={"id":OWNER}
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	services.session.set_process(false)
	CommunityService.items=[];CommunityService.state="idle";CommunityService.loaded_at=-1000.0;CommunityService.next_cursor=""
	var transport := CommunityService.for_current()
	check((await transport.refresh()).ok and CommunityService.items.size()==48 and CommunityService.next_cursor=="next-page","vitrine inicial carrega uma página com cursor")
	var screen := load("res://scenes/player/deck_library.tscn").instantiate() as Control
	root.add_child(screen)
	await settle(4)
	screen._query="USUARIO X"
	screen._render_library()
	await settle(35)
	check(CommunityService.items.size()==59 and CommunityService.next_cursor=="","pesquisa completa as páginas sem ficar limitada aos primeiros 48")
	check(screen.find_child("Deck_"+fake.PUBLISHED,true,false)==null,"envio pendente não aparece na pesquisa pública")
	fake.rows.back().status="rejected"
	screen._retry_community()
	await settle(35)
	check(screen.find_child("Deck_"+fake.PUBLISHED,true,false)==null,"deck reprovado não aparece na Comunidade")
	fake.rows.back().status="published";fake.rows.back().visibility="public"
	screen._retry_community()
	await settle(50)
	var tile := screen.find_child("Deck_"+fake.PUBLISHED,true,false)
	check(tile!=null,"após aprovação, busca pelo nickname encontra deck além da primeira página")
	var credit: Label=tile.find_child("DeckCreator",true,false) if tile!=null else null
	check(credit!=null and credit.text=="Criado por Usuário X","cartão da pesquisa mostra o nickname do criador retornado pelo servidor")
	var scroll: ScrollContainer=screen.get_node("Margin/Column/Scroll")
	if credit!=null:
		scroll.ensure_control_visible(tile)
		await settle()
		check(tile.get_global_rect().encloses(credit.get_global_rect()),"identificação do criador cabe no cartão")
	await shot("pesquisa_criador")
	screen._query="rApPeRs"
	screen._render_library()
	await settle()
	check(screen.find_child("Deck_"+fake.PUBLISHED,true,false)!=null,"pesquisa também encontra o nome do deck sem distinguir maiúsculas")
	screen._query="Outro criador"
	screen._render_library()
	await settle()
	check(screen.find_child("Deck_"+fake.PUBLISHED,true,false)==null,"filtro pelo criador não mistura autoria diferente")
	screen._query="USUARIO X"
	screen._render_library()
	await settle()
	await screen._open_community(fake.PUBLISHED)
	await settle()
	check(screen.find_child("DeckCreator",true,false).text=="Criado por Usuário X","detalhe do deck mantém a atribuição ao mesmo criador")
	await shot("detalhe_criador")
	check(CommunityService.creator_name({"nickname":null,"email":"nao-exibir@example.invalid","name":"Nome do Gmail"})=="Criador não informado","nickname ausente não é substituído por e-mail ou nome do Google")
	var before := CommunityService.items.duplicate(true)
	fake.fail_page=true
	check(not (await transport.refresh(true,true)).ok and CommunityService.items==before,"falha de paginação conserva o catálogo anterior")
	fake.fail_page=false;fake.repeat_cursor=true
	check(not (await transport.refresh(true,true)).ok,"cursor repetido termina com erro em vez de repetir para sempre")
	fake.repeat_cursor=false
	screen._query="USUARIO X";screen._tab="Descobrir"
	screen._render_library()
	await settle()
	check(screen.find_child("RetryCommunity",true,false)!=null,"falha informa resultados possivelmente incompletos e permite tentar novamente")
	screen._retry_community()
	await settle(50)
	check(CommunityService.state=="ok" and screen.find_child("Deck_"+fake.PUBLISHED,true,false)!=null,"tentar novamente recupera pesquisa e autoria")
	check(fake.page_calls.all(func(p:Dictionary)->bool:return p.p_query==null and int(p.p_limit)==48),"usa apenas a RPC existente e paginação de metadados")
	screen.queue_free();services.queue_free();fake.queue_free()
	await settle(4)
	print("COMMUNITY_ATTRIBUTION checks=",checks," failures=",failures," ",dimensions)
	quit(1 if failures else 0)
