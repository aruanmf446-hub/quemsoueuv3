extends SceneTree
## Percorre abertura, notícias e carga de fase por controles reais.

var checks := 0
var failures := 0
var output := "/tmp/qse-presentation"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func frames(count: int) -> void:
	for i in range(count): await process_frame

func snap(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "_" + label + ".png") == OK, "captura " + label)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output = args[0]
	var dimensions := (args[1] if args.size() > 1 else "1280x720").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var boot: Control = load("res://scenes/menu/menu_boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await frames(10)
	var loading := root.get_node_or_null("CampaignLoading") as CampaignLoading
	check(loading != null, "abertura aparece antes do lobby")
	if loading == null: quit(1); return
	check(loading._carousel.cards.size() == 3, "três cartões editoriais de abertura")
	await snap("abertura")
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene != boot: break
		await process_frame
	check(current_scene != boot and current_scene != null, "abertura entra no menu automaticamente")
	if current_scene == boot or current_scene == null: quit(1); return
	var menu := current_scene as Control
	var news := menu.get_node_or_null("NewsButton") as Button
	check(news != null and news.visible, "notícias acessíveis pelo lobby")
	if news == null: quit(1); return
	await snap("lobby")
	news.pressed.emit()
	await frames(4)
	var news_overlay := menu.get_node_or_null("NewsOverlay") as NewsOverlay
	check(news_overlay != null and news_overlay._carousel.cards.size() == 3, "notícias exibem três cartões")
	await snap("noticias")
	news_overlay._carousel.next()
	deadline = Time.get_ticks_msec() + 3000
	while news_overlay._carousel.index != 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(news_overlay._carousel.index == 1, "notícia seguinte desliza manualmente")
	news_overlay._carousel._timer.start(0.05)
	deadline = Time.get_ticks_msec() + 3000
	while news_overlay._carousel.index != 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(news_overlay._carousel.index == 2, "notícias avançam automaticamente")
	news_overlay._carousel.close_requested.emit()
	await frames(3)
	check(menu.get_node_or_null("NewsOverlay") == null, "fechar notícias retorna ao lobby")
	var story := menu.get_node("Navigation") as NavigationManager
	story.open("story")
	await frames(22)
	var screen := story._active
	var launch := screen.find_child("Launch01", true, false) as Button
	check(launch != null and not launch.disabled, "fase inicial disponível")
	if launch == null: quit(1); return
	launch.pressed.emit()
	await frames(8)
	loading = root.get_node_or_null("CampaignLoading") as CampaignLoading
	check(loading != null, "transição da fase mostra cartão de abertura")
	await snap("entrando_fase")
	deadline = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if root.get_node_or_null("PhaseStory") != null: break
		await process_frame
	var phase_story := root.get_node_or_null("PhaseStory") as PhaseStory
	check(phase_story != null, "história da fase aparece antes do gameplay")
	if phase_story == null: quit(1); return
	check(phase_story._carousel.manual_story and phase_story._carousel.cards.size() == 2, "fase 01 tem duas imagens sob controle do jogador")
	await snap("historia_fase01_01")
	phase_story._carousel.next()
	deadline = Time.get_ticks_msec() + 3000
	while phase_story._carousel.index != 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(phase_story._carousel.index == 1, "Próximo apresenta segunda imagem")
	await snap("historia_fase01_02")
	phase_story._carousel.skip_requested.emit()
	await frames(8)
	check(root.get_node_or_null("StoryPrototypeSession") != null, "cena da fase abre após carregar recursos")
	print("PRESENTATION_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
