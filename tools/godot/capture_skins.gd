extends SceneTree
## Captura real da tela Skins em janela. Uso:
## godot --path . -s res://tools/godot/capture_skins.gd -- <saida.png> <WxH> <inicio|rolado|equipado>

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "skins.png"
	var requested := (args[1] if args.size() > 1 else "1920x1080").split("x")
	var mode := args[2] if args.size() > 2 else "inicio"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(requested[0]), int(requested[1]))
	await process_frame
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for frame in range(30):
		await process_frame
	var nav: Node = menu.get_node("Navigation")
	nav.call("open", "skins", {})
	for frame in range(120):
		await process_frame
	await RenderingServer.frame_post_draw
	var skins: Control = menu.get_node("SkinsPanel")
	var inventory: Node = menu.get_node("Services").inventory
	if mode == "rolado":
		var scroll := _find_scroll(skins)
		if scroll != null:
			scroll.scroll_vertical = 100000
		for frame in range(60):
			await process_frame
	if mode == "fuego":
		skins.call("_select", "el_fuego")
		for frame in range(90):
			await process_frame
	if mode == "equipado":
		var target := ""
		for entry: Dictionary in inventory.entries:
			if entry.id != inventory.equipped_id() and inventory.is_unlocked(entry.id):
				target = entry.id
				break
		await skins.call("_equip", target)
		for frame in range(120):
			await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var error := picture.save_png(output)
	print("SKINS_CAPTURE ", mode, " ", DisplayServer.window_get_size(), " file=", output)
	quit(0 if error == OK else 1)


func _find_scroll(node: Node) -> ScrollContainer:
	for child in node.find_children("*", "ScrollContainer", true, false):
		if child.is_visible_in_tree():
			return child
	return null
