extends SceneTree
## Persistência de leitura concluída e cancelamento real por teclado; perfil isolado.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+message)
func frames(count: int) -> void:
	for index in range(count): await process_frame
func run() -> void:
	if OS.get_environment("QSE_TEST_STORY") != "1":
		quit(2)
		return
	var result := {"finished":false,"cancelled":false}
	var story := PhaseStory.new()
	root.add_child(story)
	story.finished.connect(func() -> void: result.finished = true)
	story.begin(3)
	check(story._carousel.cards.size() == 1,"briefing da fase3 corresponde à nova rota")
	story._carousel._story_next.pressed.emit()
	await frames(3)
	check(result.finished and PhaseStory.was_read(3),"Começar fase registra leitura concluída")
	var loader := CampaignLoading.new()
	root.add_child(loader)
	loader.cancelled.connect(func() -> void: result.cancelled = true)
	loader.begin("res://scenes/desert/phase_02.tscn",func(_scene: PackedScene) -> void: failures += 1)
	await frames(4)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key,true)
	for frame in range(120):
		if not is_instance_valid(loader): break
		await process_frame
	check(result.cancelled and not is_instance_valid(loader),"Esc cancela carregamento e fecha história")
	check(not PhaseStory.was_read(2),"Esc não marca como lida a cena cancelada")
	await frames(20)
	print("STORY_LIFECYCLE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
