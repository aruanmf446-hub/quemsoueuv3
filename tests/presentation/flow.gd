extends SceneTree
## Percorre login inicial e carga de fase; a história aparece durante o aquecimento.

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
	var deadline := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		if current_scene != null and current_scene != boot: break
		await process_frame
	check(current_scene != boot and current_scene != null,"boot abre a cena principal")
	if current_scene == boot or current_scene == null: quit(1); return
	check(root.get_node_or_null("CampaignLoading") == null,"história não interrompe o login inicial")
	var menu := current_scene as Control
	var navigation: NavigationManager = menu.get_node("Navigation")
	check(navigation._active != null and navigation._history.back().route == "account","primeira tela navegável é o login")
	if navigation._active != null and navigation._history.back().route == "account":
		navigation._active.get_node("Margin/Column/Header/Back").pressed.emit()
		await frames(15)
	var news: Button = menu._hero_carousel._news
	check(news != null and news.visible, "notícias acessíveis pelo lobby")
	if news == null: quit(1); return
	await snap("lobby")
	# Novidades hoje é a central de presentes; sua suíte própria usa ofertas locais.
	# Esta regressão não consulta ofertas nem o backend.
	var story := menu.get_node("Navigation") as NavigationManager
	story.open("story")
	await frames(22)
	var screen := story._active
	var launch := screen.find_child("Launch01", true, false) as Button
	check(launch != null and not launch.disabled, "fase inicial disponível")
	if launch == null: quit(1); return
	launch.pressed.emit()
	await frames(8)
	var loading := root.get_node_or_null("CampaignLoading") as CampaignLoading
	check(loading != null, "transição da fase mostra cartão de abertura")
	await snap("entrando_fase")
	check(loading != null and loading._story_mode and loading._carousel.manual_story,"história da fase já aparece enquanto carrega")
	check(loading._carousel.cards.size() == 8,"fase01 apresenta oito quadros de origem")
	await snap("historia_fase01_01")
	loading._carousel.next()
	deadline = Time.get_ticks_msec()+3000
	while loading._carousel.index != 1 and Time.get_ticks_msec()<deadline: await process_frame
	check(loading._carousel.index == 1,"Próximo apresenta segunda imagem")
	await snap("historia_fase01_02")
	loading._carousel.skip_requested.emit()
	deadline = Time.get_ticks_msec()+45000
	while root.get_node_or_null("StoryPrototypeSession") == null and Time.get_ticks_msec()<deadline: await process_frame
	check(root.get_node_or_null("StoryPrototypeSession") != null,"cena da fase abre após carregar recursos")
	print("PRESENTATION_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
