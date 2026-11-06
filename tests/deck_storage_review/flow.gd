extends SceneTree
const Service = preload("res://scripts/decks/deck_review_service.gd")
const Review = preload("res://scripts/decks/deck_review_screen.gd")
const Fake = preload("res://tests/deck_storage_review/fake_game.gd")
const OWNER := "00000000-0000-4000-8000-0000000000a7"
var checks := 0
var failures := 0
var output := ""
var dimensions := "1672x941"
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("STORAGE_REVIEW_FAIL "+message)
func settle(count:=8) -> void:
	for frame in count: await process_frame
func shot(label: String) -> void:
	if output.is_empty(): return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+dimensions+"_"+label+".png")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>1:
		output=args[0]
		dimensions=args[1]
		DirAccess.make_dir_recursive_absolute(output)
	var dims := dimensions.split("x")
	root.size=Vector2i(int(dims[0]),int(dims[1]))
	UIScale.apply_device_profile(root)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	services.session.set_process(false)
	var fake := Fake.new()
	root.add_child(fake)
	fake.user=OWNER
	fake.access_token="fixture-token-nao-real"
	services.client=fake
	services.session.client=fake
	services.session.user={"id":OWNER}
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	var transport := Service.new()
	fake.review_enabled=false
	check((await transport.access()).code=="backend_pending","RPC ausente informa pendência sem simular revisão")
	fake.review_enabled=true
	fake.reviewer=false
	check(not (await transport.access()).data.is_moderator,"jogador não recebe papel de revisor")
	check((await transport.pending()).code=="forbidden","servidor bloqueia fila para jogador")
	check((await transport.decide(fake.PUBLISHED,true,"")).code=="forbidden","chamada direta sem permissão não aprova")
	fake.reviewer=true
	check((await transport.pending()).data.items.size()==1,"fila carrega para conta autorizada")
	var detail: Dictionary=await transport.open_deck(fake.PUBLISHED)
	check(detail.ok,"detalhe usa o UUID do deck existente")
	var path := str(detail.data.cards[0].preview_library_path)
	var reads := fake.asset_reads
	var local := await transport.image(path)
	await transport.image(path)
	check(not local.is_empty() and fake.asset_reads==reads+1,"reaproveita uma prévia somente dentro da mesma abertura")
	var old_url: String=fake.asset_urls.back()
	var changed := Image.create(100,140,false,Image.FORMAT_RGB8)
	changed.fill(Color.ORANGE_RED)
	fake.files[path]=changed.save_png_to_buffer()
	await transport.open_deck(fake.PUBLISHED)
	local=await transport.image(path)
	check(not local.is_empty() and Image.load_from_file(local).get_pixel(0,0).is_equal_approx(Color.ORANGE_RED),"reabrir busca a imagem corrigida no mesmo caminho")
	check(fake.asset_urls.back()!=old_url and str(fake.asset_urls.back()).contains("?qse_review="),"nova abertura também muda a URL para invalidar cache HTTP do navegador")
	fake.break_preview=true
	await transport.open_deck(fake.PUBLISHED)
	check((await transport.image(path)).is_empty(),"falha de leitura não reutiliza prévia antiga como se fosse atual")
	fake.break_preview=false
	var original := "%s/%s/00000000-0000-4000-8000-000000000001_original.png" % [fake.OTHER,fake.PUBLISHED]
	check((await transport.image(original)).is_empty(),"tela de revisão não solicita o original")
	check((await transport.image("../segredo.png")).is_empty(),"caminhos fora do detalhe são recusados")
	var view := Review.new()
	fake.null_nickname=true
	fake.cover_from_card=true
	view.setup(transport)
	root.add_child(view)
	await settle(20)
	await view._open(fake.PUBLISHED)
	await settle()
	var approve: Button=view.find_child("ApproveDeck",true,false)
	var reject: Button=view.find_child("RejectDeck",true,false)
	var reason: LineEdit=view.find_child("DeckReviewReason",true,false)
	check(approve!=null and not approve.disabled and reject!=null,"revisor vê dois recortes e ações nativas")
	check(view.find_child("DeckReviewAuthor",true,false).text=="Enviado por criador sem nickname","nickname nulo tem rótulo legível sem criar ou alterar o perfil")
	check(not approve.disabled,"capa automática ou escolhida usa a prévia retornada pelo backend")
	await shot("revisao")
	var scroll: ScrollContainer=view.find_children("*","ScrollContainer",true,false)[0]
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	await settle()
	check(Rect2(Vector2.ZERO,view.size).encloses(approve.get_global_rect()) and Rect2(Vector2.ZERO,view.size).encloses(reject.get_global_rect()),"ações cabem na tela após rolar")
	await shot("acoes")
	await view._decide(fake.PUBLISHED,false,reason)
	check(fake.decisions==0,"reprovar exige motivo")
	reason.text="Revise os nomes das cartas."
	await view._decide(fake.PUBLISHED,false,reason)
	check(fake.decisions==1 and fake.review_status=="rejected" and fake.review_note==reason.text,"reprovação só aparece após resposta do servidor")
	fake.review_status="pending_review"
	await view._open(fake.PUBLISHED)
	await settle()
	reason=view.find_child("DeckReviewReason",true,false)
	view._decide(fake.PUBLISHED,true,reason)
	view._decide(fake.PUBLISHED,true,reason)
	await settle(20)
	check(fake.decisions==2 and fake.review_status=="published","cliques duplicados aprovam uma única vez")
	fake.review_status="pending_review"
	fake.fail_decision=true
	await view._open(fake.PUBLISHED)
	reason=view.find_child("DeckReviewReason",true,false)
	await view._decide(fake.PUBLISHED,true,reason)
	check(fake.decisions==2 and fake.review_status=="pending_review" and not view._notice.text.contains("aprovado"),"falha na decisão mantém pendência e não mostra sucesso")
	fake.fail_decision=false
	fake.missing_preview=true
	await view._open(fake.PUBLISHED)
	check(view.find_child("ApproveDeck",true,false).disabled and not view.find_child("RejectDeck",true,false).disabled,"prévia incompleta bloqueia aprovação e permite reprovar")
	fake.missing_preview=false
	await view._open(fake.PUBLISHED)
	reason=view.find_child("DeckReviewReason",true,false)
	fake.review_status="draft"
	await view._decide(fake.PUBLISHED,true,reason)
	await settle()
	check(fake.decisions==2 and view.find_child("ApproveDeck",true,false)==null and view._notice.text.contains("mudou"),"retirada pelo autor antes da decisão atualiza a fila sem aprovar")
	await view._open(fake.PUBLISHED)
	check(view._notice.text.contains("não está mais na fila"),"detalhe retirado mostra retorno deck_not_found do backend")
	view.queue_free()
	await settle()
	fake.reviewer=false
	view=Review.new()
	view.setup(Service.new())
	root.add_child(view)
	await settle(20)
	check(view.find_child("ApproveDeck",true,false)==null,"autor não vê controles de aprovação")
	await shot("sem_permissao")
	view.queue_free()
	await settle()
	services.session.user={"id":"00000000-0000-4000-8000-0000000000b2"}
	check(not transport.available() and (await transport.image(original)).is_empty(),"troca de conta invalida serviço e acesso a prévias")
	services.queue_free()
	fake.queue_free()
	await settle()
	print("DECK_STORAGE_REVIEW checks=",checks," failures=",failures," ",dimensions)
	quit(1 if failures else 0)
