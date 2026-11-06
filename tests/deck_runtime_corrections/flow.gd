extends SceneTree
var checks := 0
var failures := 0
var output := ""
var dimensions := "1672x941"
var screen: Control
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func settle(count:=10) -> void:
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
	var fake := preload("res://tests/deck_runtime_corrections/fake_game.gd").new()
	root.add_child(fake)
	fake.user="00000000-0000-4000-8000-0000000000a7"
	fake.access_token="fixture-not-real"
	services.client=fake;services.session.client=fake
	services.session.user={"id":fake.user}
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	services.session.set_process(false)
	screen=load("res://scenes/player/deck_library.tscn").instantiate()
	root.add_child(screen)
	await settle()
	screen._report_deck(fake.PUBLISHED)
	await settle()
	var dialog: Control=screen.find_child("ReportDialog",true,false)
	var reason: LineEdit=dialog.find_child("ReportReason",true,false)
	var send: Button=dialog.find_child("SubmitReport",true,false)
	check(dialog.is_in_group("qse_web_input_modal") and root.get_embedded_subwindows().is_empty(),"denúncia usa modal no viewport do jogo, compatível com teclado Web")
	check(Rect2(Vector2.ZERO,screen.size).encloses(send.get_global_rect()),"ações da denúncia cabem na tela")
	send.pressed.emit();await settle()
	check(fake.report_requests==0 and dialog.find_child("ReportFeedback",true,false).text.contains("Escreva"),"motivo vazio não envia nem fecha o formulário")
	reason.text="Conteúdo não corresponde à descrição."
	fake.report_code="cannot_report_own"
	send.pressed.emit();await settle()
	check(dialog.find_child("ReportFeedback",true,false).text.contains("próprio deck"),"impedimento por autoria mostra o motivo correto")
	check(is_instance_valid(dialog) and reason.text=="Conteúdo não corresponde à descrição.","erro preserva o texto para correção")
	await shot("denuncia_impedimento")
	fake.report_code="already_reported"
	send.pressed.emit();await settle()
	check(dialog.find_child("ReportFeedback",true,false).text.contains("já denunciou"),"denúncia repetida tem mensagem específica")
	fake.report_code="PGRST202"
	send.pressed.emit();await settle()
	check(dialog.find_child("ReportFeedback",true,false).text.contains("indisponível"),"função ausente aparece como serviço de denúncia indisponível")
	fake.report_code="";fake.empty_confirmation=true
	send.pressed.emit();await settle()
	check(dialog.find_child("ReportFeedback",true,false).text.contains("confirmar"),"resposta vazia não é tratada como registro confirmado")
	fake.empty_confirmation=false;fake.hold_report=true
	var before := fake.report_requests
	send.pressed.emit();send.pressed.emit();await settle()
	check(fake.report_requests==before+1 and send.disabled,"cliques repetidos enviam apenas uma denúncia")
	fake.hold_report=false
	await settle()
	check(screen.find_child("ReportDialog",true,false)==null and fake.reports.size()==1,"formulário só confirma depois da resposta de sucesso")
	screen._report_deck(fake.PUBLISHED);await settle()
	check(screen.handle_back() and screen.find_child("ReportReason",true,false)!=null,"voltar fecha o modal antes de mudar de tela")
	await settle()
	check(screen.find_child("ReportDialog",true,false)==null,"modal removido após voltar")
	var store: DeckDrafts=screen._store()
	for old in store.list(): store.delete(str(old.id))
	var draft := store.new_draft()
	draft.name="[TESTE] Trappers"
	draft.category="Personagens"
	draft.server_id=fake.PUBLISHED
	draft.server_status="pending_review"
	draft.sync_state="synced"
	store.save(draft)
	fake.db.qse_creator_decks=[{"id":fake.PUBLISHED,"owner_id":fake.user,"status":"pending_review","review_note":null}]
	screen._pulled_decks=true
	for i in 10:
		screen._open_entry({"draft":store.load_draft(str(draft.id))})
		await settle()
		check(screen._view=="submissions" and screen.find_child("EditorLocked",true,false)==null,"abertura "+str(i+1)+" mantém status completo, não edição bloqueada")
		screen.find_child("SubmissionAction",true,false).pressed.emit()
		await settle()
		screen.handle_back();await settle()
		check(screen._view=="submissions","voltar de Ver envio retorna ao status, ciclo "+str(i+1))
		screen.handle_back();await settle()
	await shot("meus_decks")
	screen._menu_action(0,{"draft":store.load_draft(str(draft.id))})
	await settle()
	check(screen._view=="editor" and screen.find_child("EditorLocked",true,false)!=null and screen.find_child("DeckName",true,false)==null,"Editar explícito continua bloqueado durante a revisão")
	screen._open_submissions();await settle()
	await shot("status_pendente")
	store.delete(str(draft.id))
	screen.queue_free();services.queue_free();fake.queue_free()
	await settle(4)
	print("DECK_RUNTIME_FIXES checks=",checks," failures=",failures," ",dimensions)
	quit(1 if failures else 0)
