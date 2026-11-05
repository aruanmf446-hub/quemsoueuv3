extends SceneTree
const Service = preload("res://scripts/decks/repository_service.gd")
const Review = preload("res://scripts/decks/repository_review.gd")
const Fixture = preload("res://tests/deck_repository/review_fixture.gd")
var checks := 0
var failures := 0
var output := ""
var dimensions := "1672x941"
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("REPO_DECK_FAIL "+message)
func settle(count := 6) -> void:
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
	var size := dimensions.split("x")
	root.size=Vector2i(int(size[0]),int(size[1]))
	UIScale.apply_device_profile(root)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	services.session.set_process(false)
	services.session.user={"id":"00000000-0000-4000-8000-0000000000a1"}
	services.client.access_token="fixture-not-a-session-token"
	var store := DeckDrafts.for_current()
	var draft := store.new_draft()
	draft.name="Ilustrações de teste"
	draft.description="Fixture local para revisão manual; não é um deck publicado."
	draft.category="Personagens"
	draft.visibility="public"
	draft.publication_backend="repository"
	store.save(draft)
	for i in 5:
		var image := Image.create(80,112,false,Image.FORMAT_RGB8)
		image.fill(Color.from_hsv(float(i)/5,0.5,0.8))
		var id := "card_"+str(i)
		var file := store.store_original(draft.id,id,image.save_png_to_buffer(),"png")
		var card := {"id":id,"name":"Carta de teste "+str(i+1),"description":"Arte de teste","image_file":file,"crops":{"library":{"x":0.5,"y":0.5,"zoom":1.0},"duel":{"x":0.5,"y":0.5,"zoom":1.0}}}
		store.store_previews(draft.id,card,image)
		draft.cards.append(card)
	store.save(draft)
	var built: Dictionary=await Service.bundle(store,draft)
	check(built.ok and built.data.cards.size()==5,"monta cinco imagens e nomes sem servidor")
	check(built.data.cover is Dictionary,"preserva a capa enquadrada")
	check(not JSON.stringify(built.data).contains("fixture-not-a-session-token"),"arquivo enviado não contém token")
	var decoded := Image.new()
	check(decoded.load_webp_from_buffer(Marshalls.base64_to_raw(built.data.cards[0].image))==OK,"otimização produz WebP decodificável")
	var original := store.original_image(draft.id,draft.cards[0])
	check(original.get_width()==80 and original.get_height()==112,"original permanece intacto para editar")
	var no_bridge: Dictionary=await Service.new().submit(store,draft)
	check(not no_bridge.ok and no_bridge.code=="bridge_not_configured" and not draft.has("repo_submission_id"),"sem configuração não finge envio")
	var cloud := CreatorSync.for_current(store)
	var no_storage: Dictionary=await cloud.push(draft)
	check(not no_storage.ok and no_storage.code=="repository_only","não usa o Storage antigo para este envio")
	var statuses := preload("res://tests/deck_repository/status_fixture.gd").new()
	draft.repo_submission_id="a".repeat(32)
	store.save(draft)
	statuses.rows=[{"id":draft.repo_submission_id,"status":"rejected","review_note":"Revisar os nomes."}]
	var synced: Dictionary=await statuses.sync_statuses(store)
	var saved := store.load_draft(str(draft.id))
	check(synced.ok and saved.repo_status=="rejected" and saved.review_note=="Revisar os nomes.","autor recebe reprovação e motivo no rascunho")
	statuses.rows[0].status="approved"
	await statuses.sync_statuses(store)
	check(store.load_draft(str(draft.id)).repo_status=="published","aprovação atualiza o status sem upload antigo")
	var foreign := DeckDrafts.new()
	foreign.owner="outro-dono"
	check(not (await statuses.sync_statuses(foreign)).ok,"atualização não escreve no rascunho de outra conta")
	var fixture := Fixture.new(built.data)
	var view := Review.new()
	view.setup(fixture)
	root.add_child(view)
	await settle()
	await view._open(fixture.record.id)
	await settle()
	var approve: Button=view.find_child("ApproveRepositoryDeck",true,false)
	var reject: Button=view.find_child("RejectRepositoryDeck",true,false)
	var reason: LineEdit=view.find_child("RepositoryReviewReason",true,false)
	check(approve!=null and reject!=null and not approve.disabled,"moderador vê arte e ações reais")
	await shot("moderacao")
	var scroll: ScrollContainer=view.find_children("*","ScrollContainer",true,false)[0]
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	await settle()
	var visible_rect := Rect2(Vector2.ZERO,view.size)
	check(visible_rect.encloses(approve.get_global_rect()) and visible_rect.encloses(reject.get_global_rect()),"ações de revisão cabem após rolar o conteúdo")
	await shot("moderacao_acoes")
	await view._decide(fixture.record.id,false,reason)
	check(fixture.reject_calls==0,"reprovação exige motivo")
	reason.text="Revisar os nomes antes de reenviar."
	await view._decide(fixture.record.id,false,reason)
	check(fixture.reject_calls==1 and fixture.record.review_note==reason.text,"reprovação registra motivo")
	fixture.record.status="pending_review"
	await view._open(fixture.record.id)
	await settle()
	reason=view.find_child("RepositoryReviewReason",true,false)
	view._decide(fixture.record.id,true,reason)
	view._decide(fixture.record.id,true,reason)
	await create_timer(0.2).timeout
	check(fixture.approve_calls==1,"clique duplicado não duplica aprovação")
	view.queue_free()
	await settle()
	fixture.admin=false
	fixture.record.status="rejected"
	view=Review.new()
	view.setup(fixture)
	root.add_child(view)
	await settle()
	await view._open(fixture.record.id)
	await settle()
	check(view.find_child("ApproveRepositoryDeck",true,false)==null,"autor não recebe ações de moderador")
	await shot("autor")
	view.queue_free()
	await settle()
	services.session.changed.emit()
	services.queue_free()
	await settle()
	print("REPOSITORY_DECKS checks=",checks," failures=",failures," ",dimensions)
	quit(1 if failures else 0)
