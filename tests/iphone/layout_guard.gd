extends SceneTree
## GUARDA DE LAYOUT DO iPHONE: abre o lobby, Novidades e todas as rotas em CADA tamanho de
## tests/iphone/models.txt (perfil --iphone) e reprova se um controle tocável visível ficar
## fora da tela (sem estar dentro de uma área que rola) ou com toque pequeno demais.
## Uso: --script res://tests/iphone/layout_guard.gd -- --iphone
const ROUTES := ["account", "profile", "skins", "duel", "deck_library", "friends", "settings", "wallet", "story", "music"]
const MIN_TOUCH := 30.0          # px de design (~16 pt no mini): abaixo disso o dedo erra
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _models() -> Array:
	var list := []
	for line in FileAccess.get_file_as_string("res://tests/iphone/models.txt").split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.is_empty() or parts[0].begins_with("#"): continue
		var dims := parts[parts.size() - 1].split("x")
		list.append([parts[0], Vector2i(int(dims[0]), int(dims[1]))])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--models="):
			var requested := arg.trim_prefix("--models=").split(",")
			return list.filter(func(model: Array) -> bool: return model[0] in requested)
	return list


func _inside_scroll(node: Node) -> bool:
	var up := node.get_parent()
	while up != null:
		if up is ScrollContainer: return true
		up = up.get_parent()
	return false


func _audit(where: String) -> void:
	var view := root.get_visible_rect()
	for node in root.find_children("*", "BaseControl" if false else "Control", true, false):
		var control := node as Control
		if not (control is BaseButton or control is LineEdit): continue
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE: continue
		if _inside_scroll(control): continue
		var rect := control.get_global_rect()
		if rect.size.x <= 1 or rect.size.y <= 1: continue
		checks += 1
		var grown := view.grow(2.0)
		if not grown.encloses(rect):
			failures += 1
			print("IPHONE_FAIL %s fora da tela: %s %s" % [where, control.get_path(), rect])
		elif minf(rect.size.x, rect.size.y) < MIN_TOUCH and not control is CheckBox:
			failures += 1
			print("IPHONE_FAIL %s toque pequeno (%dx%d): %s" % [where, rect.size.x, rect.size.y, control.get_path()])

func _settle(navigation: Node, expected: String) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var history: Array = navigation.get("_history")
		var route := "" if history.is_empty() else str(history.back().route)
		if route == expected and not bool(navigation.get("_busy")): return
		await process_frame


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	UIScale.apply_device_profile(root)
	for model: Array in _models():
		root.size = model[1]
		await process_frame
		var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
		root.add_child(menu)
		for i in 4: await process_frame
		var nav: Node = menu.get_node("Navigation")
		if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
			var startup_back := (nav.get("_active") as Control).get_node_or_null("Margin/Column/Header/Back") as Button
			if startup_back != null: startup_back.pressed.emit()
			else: nav.back()
			await _settle(nav, "")
			for i in 3: await process_frame
		_audit("%s lobby" % model[0])
		for route: String in ROUTES:
			nav.open(route, {})
			await _settle(nav, route)
			for i in 3: await process_frame
			# Tela que não carrega (erro de script) não pode passar em branco.
			var active: Variant = nav.get("_active")
			if active == null or not (active as Control).is_visible_in_tree() or nav.get("_history").is_empty() or nav.get("_history").back().route != route:
				failures += 1
				print("IPHONE_FAIL %s %s: tela não abriu" % [model[0], route])
				print("IPHONE_NAV_STATE ",JSON.stringify({"expected":route,"history":nav.get("_history").map(func(entry: Dictionary) -> String: return str(entry.route)),"busy":nav.get("_busy"),"pending":str(nav.get("_pending").get("kind","")),"paused":paused,"active":str(active.name) if is_instance_valid(active) else "null","visible":(active as Control).is_visible_in_tree() if is_instance_valid(active) else false}))
			_audit("%s %s" % [model[0], route])
			nav.back()
			await _settle(nav, "")
			for i in 3: await process_frame
		menu.queue_free()
		print("IPHONE_MODEL_DONE ", model[0])
		for i in 2: await process_frame
	print("IPHONE_LAYOUT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
