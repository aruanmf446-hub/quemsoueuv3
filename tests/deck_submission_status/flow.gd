extends SceneTree
## Fluxo do autor com fixtures: decisão, correção, reenvio e consulta sem rede.
const OWNER := "00000000-0000-4000-8000-0000000000a7"
const OTHER := "00000000-0000-4000-8000-0000000000b8"
var checks := 0
var failures := 0
var output := ""
var dimensions := "1672x941"
var screen: Control
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",message)
	if not value: failures+=1
func settle(count:=12) -> void:
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
	var fake := preload("res://tests/deck_submission_status/fake_game.gd").new()
	root.add_child(fake)
	fake.user=OWNER
	fake.access_token="fixture-not-real"
	services.client=fake
	services.session.client=fake
	services.session.user={"id":OWNER}
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	services.session.set_process(false)
	var store := DeckDrafts.for_current()
	for old in store.list(): store.delete(str(old.id))
	var draft := store.new_draft()
	draft.name="[TESTE] Rappers"
	draft.description="Deck sobre artistas do rap."
	draft.category="Personagens"
	var image := (load("res://assets/duel/decks/oficial/lendas_urbanas/momo.png") as Texture2D).get_image()
	store.save(draft)
	for i in 5:
		var card := {"id":"card_"+str(i),"name":"Artista "+str(i+1),"crops":{}}
		card.image_file=store.store_original(str(draft.id),str(card.id),image.save_png_to_buffer(),"png")
		store.store_previews(str(draft.id),card,image)
		draft.cards.append(card)
	store.save(draft)
	screen=load("res://scenes/player/deck_library.tscn").instantiate()
	root.add_child(screen)
	await settle()
	screen._draft=draft
	screen._render_review()
	await screen._publish_draft(draft)
	var server_id: String=draft.server_id
	check(draft.server_status=="pending_review","envio inicial aguarda revisão")
	screen._pulled_decks=true
	screen._select_tab("Meus Decks")
	await settle()
	check(screen.find_child("OpenDeckSubmissions",true,false)!=null,"Meus Decks oferece acompanhamento visível")
	screen._open_submissions()
	await settle()
	check(screen._view=="submissions" and screen.find_child("SubmissionState",true,false).text=="Em revisão","autor acompanha envio pendente")
	check(screen.find_child("RejectionReason",true,false)==null,"envio pendente não mostra motivo antigo")
	await shot("pendente")
	var reason := "As imagens não correspondem aos artistas de rap descritos. Substitua as cartas por imagens dos personagens indicados, mantenha os nomes corretos e envie novamente para revisão."
	fake.db.qse_creator_decks[0].status="rejected"
	fake.db.qse_creator_decks[0].review_note=reason
	var reads := fake.status_reads
	screen._refresh_moderation()
	screen._refresh_moderation()
	await settle()
	check(fake.status_reads==reads+1,"atualizar repetidamente não duplica a consulta")
	check(screen.find_child("SubmissionState",true,false).text.begins_with("Reprovado"),"reprovação vem da resposta do servidor")
	var note: Label=screen.find_child("RejectionReason",true,false)
	check(note.text==reason and note.autowrap_mode!=TextServer.AUTOWRAP_OFF,"motivo completo legível, inclusive no celular")
	var action: Button=screen.find_child("SubmissionAction",true,false)
	var scroll: ScrollContainer=screen.get_node("Margin/Column/Scroll")
	scroll.ensure_control_visible(action)
	await settle()
	check(Rect2(Vector2.ZERO,screen.size).encloses(action.get_global_rect()),"ação corrigir e reenviar cabe após rolagem")
	await shot("reprovado")
	action.pressed.emit()
	await settle()
	check(screen._view=="editor" and screen.find_child("RejectionReason",true,false).text==reason,"abrir correção mantém o motivo acima do formulário")
	var field: LineEdit=screen.find_child("DeckName",true,false)
	field.text="[TESTE] Rappers corrigido"
	field.text_changed.emit(field.text)
	var corrected := image.duplicate() as Image
	corrected.flip_x()
	var corrected_bytes := corrected.save_png_to_buffer()
	var corrected_card: Dictionary=screen._draft.cards[0]
	corrected_card.image_file=store.store_original(str(draft.id),str(corrected_card.id),corrected_bytes,"png")
	store.store_previews(str(draft.id),corrected_card,corrected)
	await screen._save_draft()
	check(fake.files[str(corrected_card.uploaded_original)]==corrected_bytes,"imagem corrigida é reenviada sem reutilizar o original antigo")
	check(fake.db.qse_creator_decks[0].status=="draft","correção usa a retirada existente antes de editar o deck travado")
	check(screen._draft.review_note==reason and screen._draft.server_status=="draft","motivo preservado durante a correção")
	check(store.load_draft(str(draft.id)).name==field.text,"alterações salvas sem perder o deck")
	screen._render_submissions()
	check(screen.find_child("SubmissionState",true,false).text.begins_with("Em correção"),"rascunho corrigido aguarda reenvio explícito")
	screen.find_child("SubmissionAction",true,false).pressed.emit()
	screen._render_review()
	await settle()
	var resend: Button=screen.find_child("PublishDeck",true,false)
	check(resend.text.begins_with("Reenviar") and not resend.disabled,"reenvio fica disponível após revisar as correções")
	fake.fail_publish=true
	await screen._publish_draft(screen._draft)
	check(screen._draft.server_status=="draft" and screen._draft.review_note==reason,"falha de rede preserva correções e motivo para tentar novamente")
	fake.fail_publish=false
	screen._publish_draft(screen._draft)
	screen._publish_draft(screen._draft)
	await settle(50)
	check(fake.db.qse_creator_decks.size()==1 and screen._draft.server_id==server_id,"reenviar mantém o mesmo deck sem duplicar")
	check(screen._draft.server_status=="pending_review" and screen._draft.review_note=="","novo envio aguarda decisão e limpa o motivo anterior")
	check(fake.rpc_calls.filter(func(c:Array)->bool:return c[0]=="qse_deck_publish_request").size()==2,"um único reenvio apesar de dois cliques")
	fake.db.qse_creator_decks[0].status="rejected"
	fake.db.qse_creator_decks[0].review_note="Ainda é necessário corrigir a carta Artista 3."
	screen._open_submissions()
	await settle()
	check(screen.find_child("RejectionReason",true,false).text==fake.db.qse_creator_decks[0].review_note,"segunda reprovação apresenta o novo motivo")
	fake.db.qse_creator_decks[0].status="published"
	fake.db.qse_creator_decks[0].review_note=null
	await screen._refresh_moderation()
	check(screen.find_child("SubmissionState",true,false).text=="Aprovado · publicado" and screen.find_child("RejectionReason",true,false)==null,"aprovação aparece sem o motivo antigo")
	await shot("aprovado")
	var stale: Dictionary=screen._draft.duplicate(true)
	stale.server_status="rejected"
	var withdrawals := fake.rpc_calls.filter(func(c:Array)->bool:return c[0]=="qse_deck_unpublish").size()
	var guarded: Dictionary=await screen._sync().push(stale)
	check(not guarded.ok and fake.db.qse_creator_decks[0].status=="published" and fake.rpc_calls.filter(func(c:Array)->bool:return c[0]=="qse_deck_unpublish").size()==withdrawals,"cópia desatualizada não retira um deck já aprovado")
	fake.fail_status=true
	await screen._refresh_moderation()
	check(screen.find_child("DeckStatusNotice",true,false).text.contains("último status salvo"),"falha informa que os dados exibidos são os últimos salvos")
	check(screen.find_child("SubmissionState",true,false).text=="Aprovado · publicado","falha não inventa uma decisão nova")
	fake.fail_status=false
	fake.db.qse_creator_decks[0].status="rejected"
	fake.db.qse_creator_decks[0].review_note="Decisão privada da conta anterior."
	fake.hold_status=true
	fake.status_started=false
	screen._refresh_moderation()
	await settle(2)
	check(fake.status_started,"consulta iniciada antes da troca de conta")
	fake.user=OTHER
	services.session.user={"id":OTHER}
	services.session.changed.emit()
	fake.hold_status=false
	await settle(30)
	check(screen._store().owner==OwnerStorage.safe(OTHER) and store.load_draft(str(draft.id)).server_status=="published","resposta atrasada não atualiza outra conta")
	check(screen.find_child("RejectionReason",true,false)==null,"troca de conta não mostra motivo privado anterior")
	screen._pulled_decks=true
	screen._open_submissions()
	await settle()
	check(screen.find_child("NoSubmissions",true,false)!=null,"conta sem decks tem estado vazio")
	check(screen.handle_back() and screen._view=="library","voltar retorna a Meus Decks")
	for old in store.list(): store.delete(str(old.id))
	screen.queue_free()
	services.queue_free()
	fake.queue_free()
	await settle()
	print("DECK_SUBMISSION_STATUS checks=",checks," failures=",failures," ",dimensions)
	quit(1 if failures else 0)
