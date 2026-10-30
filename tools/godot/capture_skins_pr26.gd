extends SceneTree
## Temporário (branch claude/capturas-pr26): fotografa a tela Personagens no framebuffer real.
## godot --path . --audio-driver Dummy --script res://tools/godot/capture_skins_pr26.gd -- /saida/prefixo 1920x1080
func _initialize() -> void:
	call_deferred('_capture')
func _wait(frames: int) -> void:
	for frame in range(frames): await process_frame
func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print('CAPTURE ', path)
func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var resolution := args[1].split('x')
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(resolution[0]), int(resolution[1]))
	await process_frame
	var services := PlayerServices.new()
	root.add_child(services)
	var panel := load('res://scenes/skins/skins_panel.tscn').instantiate()
	root.add_child(panel)
	panel.call('open', services.inventory.equipped_id())
	# Miniaturas são renderizadas em segundo plano pelo ThumbnailCache.
	await _wait(240)
	await _shot(output + '_inicio.png')
	var cards: Dictionary = panel.get('_cards')
	var ids := cards.keys()
	if ids.size() > 1:
		panel.call('_select', ids[1])
		await _wait(60)
		await _shot(output + '_selecionado.png')
	quit()
