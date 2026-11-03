extends SceneTree
## Captura REAL no renderer Godot via xvfb-run. Fixtures locais sem API/autenticação real.
## Captura a cena de home verdadeira, por trás do modal, não um mockup.
const OUT_ENV := "T30_CAPTURE_DIR"

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int = 4) -> void:
	for i in count: await process_frame

func _fail(message: String) -> void:
	push_error("T30_CAPTURE_FAIL " + message)
	quit(1)

func _run() -> void:
	var destination := OS.get_environment(OUT_ENV)
	if destination.is_empty(): destination = "/tmp/rewards-t30-screens"
	DirAccess.make_dir_recursive_absolute(destination)
	var home := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(home)
	current_scene = home
	await _frames(25)
	var nav: NavigationManager = home.get_node("Navigation")
	if not nav.get("_history").is_empty(): nav.back()
	await _frames(25)
	var services: PlayerServices = home.get_node("Services")
	services.session.user = {"id": "00000000-0000-4000-8000-000000000001"}
	services.client.access_token = "screenshot-fixture-offline"
	services.session._expires_at = Time.get_unix_time_from_system() + 3600.0
	services.rewards.state = "success"
	services.rewards.seen = true
	services.rewards.revealed = false
	services.rewards.campaign = {"id":"screenshot_fixture","title":"PRESENTES DA EQUIPE",
		"subtitle":"4 decks oficiais e 7 skins", "description":"De graça para a comunidade."}
	services.rewards.offers = [
		{"id":"deck_lendas_urbanas","kind":"deck","item_id":"lendas_urbanas","title":"Lendas Urbanas","description":"Histórias e personagens que nasceram do imaginário popular.","claimed":true,"claim_enabled":true},
		{"id":"deck_nostalgia_web","kind":"deck","item_id":"nostalgia_web","title":"Nostalgia Web","description":"Memes e referências que marcaram a internet.","claimed":true,"claim_enabled":true},
		{"id":"deck_sol_nascente","kind":"deck","item_id":"sol_nascente","title":"Sol Nascente","description":"Mitos e símbolos da tradição japonesa.","claimed":true,"claim_enabled":true},
		{"id":"deck_pinturas","kind":"deck","item_id":"pinturas","title":"Pinturas","description":"Obras de arte transformadas em animação.","claimed":true,"claim_enabled":true},
		{"id":"skin_cowboy","kind":"skin","item_id":"cowboy","title":"Cowboy","description":"Um pistoleiro pronto para a próxima aventura.","claimed":true,"claim_enabled":true},
		{"id":"skin_michelly","kind":"skin","item_id":"michelly","title":"Michelly","description":"Skin inicial.","claimed":true,"claim_enabled":true},
		{"id":"skin_rodrigo","kind":"skin","item_id":"rodrigo","title":"Rodrigo","description":"Skin inicial.","claimed":true,"claim_enabled":true},
		{"id":"skin_lorena","kind":"skin","item_id":"lorena","title":"Lorena","description":"Skin inicial.","claimed":true,"claim_enabled":true},
		{"id":"skin_gus","kind":"skin","item_id":"gus","title":"Gus","description":"Skin inicial.","claimed":true,"claim_enabled":true},
		{"id":"skin_lana","kind":"skin","item_id":"lana","title":"Lana","description":"Skin inicial.","claimed":true,"claim_enabled":true},
		{"id":"skin_halloween","kind":"skin","item_id":"halloween","title":"Halloween","description":"Skin inicial.","claimed":true,"claim_enabled":true}
	]
	var overlay := NewsOverlay.new()
	overlay.name = "NewsOverlay"
	home.add_child(overlay)
	await _frames(8)
	var cases := [
		{"size":Vector2i(1920,1080),"tab":"deck","revealed":false,"state":"success","name":"home_1920x1080"},
		{"size":Vector2i(1672,941),"tab":"deck","revealed":false,"state":"success","name":"decks_1672x941"},
		{"size":Vector2i(1280,720),"tab":"skin","revealed":false,"state":"success","name":"skins_1280x720"},
		{"size":Vector2i(844,390),"tab":"deck","revealed":false,"state":"success","name":"android_844x390"},
		{"size":Vector2i(640,360),"tab":"skin","revealed":false,"state":"success","name":"android_640x360"},
		{"size":Vector2i(1920,1080),"tab":"deck","revealed":true,"state":"success","name":"received_1920x1080"},
		{"size":Vector2i(1920,1080),"tab":"deck","revealed":false,"state":"error","name":"error_1920x1080"},
		{"size":Vector2i(1280,720),"tab":"deck","revealed":false,"state":"loading","name":"loading_1280x720"}
	]
	for item: Dictionary in cases:
		var resolution: Vector2i = item.size
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.size = resolution
		home.size = Vector2(resolution)
		services.rewards.revealed = bool(item.revealed)
		services.rewards.state = str(item.state)
		overlay._tab = str(item.tab)
		overlay._layout()
		await _frames(8)
		var picture := root.get_texture().get_image()
		if picture == null or picture.is_empty():
			_fail("renderer " + str(resolution))
			return
		var filepath := destination.path_join(str(item.name) + ".png")
		var status := picture.save_png(filepath)
		if status != OK:
			_fail("write " + filepath)
			return
		print("T30_CAPTURE_OK ", filepath, " actual=", picture.get_size())
	overlay.queue_free()
	home.queue_free()
	await _frames()
	quit(0)
