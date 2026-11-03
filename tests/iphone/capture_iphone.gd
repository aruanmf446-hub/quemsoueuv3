extends SceneTree
## Capturas do PERFIL iPHONE (área segura já descontada): lobby, Novidades (e Resgatar) e
## todas as rotas. Simula o iPhone com --iphone (base 1280x720), sem navegador.
## Uso: --script res://tests/iphone/capture_iphone.gd -- <pasta> <LxA> [rotas,separadas]
## Tamanhos úteis (pt) com o aparelho deitado: 16e 750x353, 15/16 Pro Max 814x393, SE 667x359.
const ROUTES := ["account", "profile", "skins", "duel", "deck_library", "friends", "settings", "wallet", "story", "music"]


func _initialize() -> void:
	call_deferred("_run")


func _shot(folder: String, name: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + name + ".png")
	print("CAPTURED ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dims := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	UIScale.apply_device_profile(root)
	await process_frame
	var only: Array = args[2].split(",") if args.size() > 2 and not args[2].begins_with("--") else []
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for i in 40: await process_frame
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		for i in 30: await process_frame
	var tag := args[1]
	if only.is_empty() or only.has("lobby"): await _shot(args[0], "lobby_" + tag)
	if only.is_empty() or only.has("news"):
		menu.call("_open_news")
		await _shot(args[0], "news_" + tag)
		var overlay: Node = menu.get_node_or_null("NewsOverlay")
		if overlay != null:
			for button: Button in overlay.find_children("*", "Button", true, false):
				if button.text.to_lower().contains("resgat") or button.text.to_lower().contains("presente"):
					button.pressed.emit()
					await _shot(args[0], "news_redeem_" + tag)
					break
			overlay.queue_free()
			for i in 10: await process_frame
	if only.has("account_login"):
		# Tela de e-mail/senha (onde o teclado é usado).
		nav.open("account", {})
		for i in 30: await process_frame
		var account: Node = nav.get("_active")
		if account != null and account.has_method("_switch"): account.call("_switch", "login")
		await _shot(args[0], "account_login_" + tag)
		nav.back()
		for i in 20: await process_frame
	for route: String in ROUTES:
		if not only.is_empty() and not only.has(route): continue
		nav.open(route, {})
		await _shot(args[0], route + "_" + tag)
		nav.back()
		for i in 20: await process_frame
	quit(0)
