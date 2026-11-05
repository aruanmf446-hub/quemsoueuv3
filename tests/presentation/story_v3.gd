extends SceneTree
## QA local de leitura, carregamento concorrente, replay e legendas nativas.
var checks := 0
var failures := 0
var output := "/tmp/story-v3"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+message)
func frames(count: int) -> void:
	for index in range(count): await process_frame
func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"_"+name+".png") == OK,"captura "+name)
func ready_wait(loader: CampaignLoading) -> void:
	var deadline := Time.get_ticks_msec()+45000
	while is_instance_valid(loader) and not loader._can_skip and Time.get_ticks_msec() < deadline: await process_frame
func run() -> void:
	if OS.get_environment("QSE_TEST_STORY") != "1":
		push_error("Execute com user:// isolado e QSE_TEST_STORY=1")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output = args[0]
	var dimensions := (args[1] if args.size()>1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	check(not PhaseStory.was_read(1),"origem ainda não lida no perfil de teste isolado")
	var entries := PhaseStory.cards_for(1)
	check(entries.size() == 8,"roteiro tem oito quadros")
	check(entries[0].message.begins_with("Cresci no subsolo, nas minas do tirano Pimento."),"roteiro começa nas minas de Pimento")
	check(entries[7].message.ends_with("acabar com a tirania de Pimento."),"roteiro preserva a missão final")
	var story := PhaseStory.new()
	root.add_child(story)
	story.begin(1)
	await frames(3)
	check(story._carousel.manual_story and story._carousel._timer.is_stopped(),"leitura não avança sozinha")
	for index in range(8):
		var carousel := story._carousel
		if index > 0:
			carousel._story_next.pressed.emit()
			var deadline := Time.get_ticks_msec()+2500
			while carousel._moving and Time.get_ticks_msec()<deadline: await process_frame
		check(carousel.index == index,"navegação manual quadro %d" % (index+1))
		var label: Label = carousel._front.get_node("Caption/Message")
		var caption: Panel = carousel._front.get_node("Caption")
		var needed := label.get_line_count()*label.get_line_height()
		check(float(needed) <= label.size.y+1.0,"legenda completa quadro %d (%dpx <= %.0fpx)" % [index+1,needed,label.size.y])
		check(label.global_position.y+needed <= carousel._story_next.global_position.y+2,"legenda não cobre Próximo quadro %d" % (index+1))
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(carousel._story_next.get_global_rect()),"ação dentro da tela quadro %d" % (index+1))
		check(carousel._front.get_node("Image").texture is AtlasTexture,"arte por região de atlas quadro %d" % (index+1))
		await snap("quadro_%02d" % (index+1))
	story._cancel()
	await frames(2)
	check(not PhaseStory.was_read(1),"cancelar leitura incompleta não marca como lida")
	var result := {"opened":false,"packed":null}
	var loading := CampaignLoading.new()
	root.add_child(loading)
	loading.begin("res://scenes/desert/phase_01.tscn",func(packed: PackedScene) -> void: result.opened=true; result.packed=packed)
	await frames(3)
	check(loading._story_mode and loading._carousel.cards.size() == 8,"história aparece durante o carregamento da fase")
	check(not result.opened,"não abre gameplay antes da leitura")
	check(loading._carousel._timer.is_stopped(),"temporizador da abertura anterior é cancelado ao entrar na história")
	await create_timer(2.3).timeout
	check(loading._carousel.index == 0,"quadro1 permanece durante leitura longa e carregamento")
	await ready_wait(loading)
	check(loading._can_skip and loading._packed != null,"cena e recursos ficam prontos enquanto leitor permanece no quadro1")
	await frames(3)
	check(not result.opened,"fim do carregamento respeita o ritmo de leitura")
	await snap("leitura_com_fase_pronta")
	loading._carousel.skip_requested.emit()
	await frames(3)
	check(result.opened and result.packed is PackedScene,"pular abre somente uma cena já preparada")
	check(PhaseStory.was_read(1),"pular explicitamente persiste a preferência de não repetir")
	var repeated := {"finished":false}
	var same := PhaseStory.new()
	root.add_child(same)
	same.finished.connect(func() -> void: repeated.finished = true)
	same.begin(1)
	await frames(3)
	check(repeated.finished and not is_instance_valid(same),"segunda visita pula história automaticamente")
	var replay := PhaseStory.new()
	replay.force_replay = true
	root.add_child(replay)
	replay.begin(1)
	await frames(3)
	check(replay._carousel.cards.size() == 8 and not replay._closed,"Rever história reabre mesmo após leitura")
	replay._cancel()
	await frames(2)
	var fast := {"opened":false}
	var seen := CampaignLoading.new()
	root.add_child(seen)
	seen.begin("res://scenes/desert/phase_01.tscn",func(_packed: PackedScene) -> void: fast.opened = true)
	check(not seen._story_mode and not seen._carousel.manual_story,"repetição mostra só capa de carga")
	await ready_wait(seen)
	await frames(3)
	check(fast.opened,"fase relida entra assim que recursos ficam prontos, sem espera artificial")
	print("STORY_V3_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
