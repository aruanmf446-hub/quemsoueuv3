extends SceneTree
## Executar em user:// isolado. Fixtures PCM zeradas, sem músicas ou licença comercial.
var failures := 0
var checks := 0
var menu: Control
var nav: Node
var music: Node
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1
func settle(count := 6) -> void:
	for frame in range(count): await process_frame
	await create_timer(0.22).timeout
func button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child.text == text: return child
	return null
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1672, 941)
	await process_frame
	music = root.get_node("MenuMusic")
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle(12)
	nav = menu.get_node("Navigation")
	# As 14 faixas foram liberadas pelo proprietário (docs/audio/MENU_MUSIC.md): todas
	# precisam passar pela validação completa de licença, áudio e capa.
	check(music.tracks.size() == 14 and music.available_tracks().size() == 14, "14 faixas liberadas reproduzem")
	for track: Dictionary in music.tracks:
		check(track.license.status == "approved" and track.enabled and music.licensed(track), "licença válida: " + track.id)
	# Caminho real, iniciado pelo botão de Configurações no menu.
	menu.get_node("TopBar/SettingsButton").pressed.emit()
	await settle()
	var settings = nav._active
	check(settings.heading.text == "Configurações" and settings._tabs.size() == 4, "Configurações T14B preservadas")
	settings._tabs[0].pressed.emit()
	await settle()
	var manage := button(settings, "Gerenciar músicas")
	check(manage != null, "Áudio contém Gerenciar músicas")
	settings._scroll.ensure_control_visible(manage)
	await settle()
	if "--capture" in OS.get_cmdline_user_args():
		await capture("settings-audio")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = manage.get_global_rect().get_center()
		press.global_position = press.position
		root.push_input(press)
		press = press.duplicate()
		press.pressed = false
		root.push_input(press)
	else:
		manage.pressed.emit()
	await settle(12)
	var screen = nav._active
	check(nav._history.back().route == "music" and screen.is_visible_in_tree(), "Configurações → Áudio → Gerenciar músicas abre a tela")
	if nav._history.back().route != "music":
		quit(1)
		return
	check(screen.CATEGORIES.values() == ["Alternative", "Funk", "K-pop", "Pop", "Trap"], "cinco categorias preservadas")
	if "--capture" in OS.get_cmdline_user_args(): await capture("music-from-settings")
	var first: String = music.tracks[0].id
	# Seleção simples: tocar na linha da música desmarca e já salva.
	var row: Button = screen.find_child("Track_" + first, true, false)
	check(row != null and row.button_pressed, "cada música tem uma caixa marcada")
	row.button_pressed = false
	await settle()
	check(music.is_excluded(first), "desmarcar tira a música da playlist na hora")
	var saved := ConfigFile.new()
	check(saved.load(music.SELECTION_PATH) == OK and saved.get_value("menu_music", "deselected").has(first), "seleção persistida em disco")
	row = screen.find_child("Track_" + first, true, false)
	row.button_pressed = true
	await settle()
	check(not music.is_excluded(first), "marcar de novo devolve a música")
	button(screen, "Desmarcar todas").pressed.emit()
	await settle()
	check(music.available_tracks().is_empty(), "Desmarcar todas esvazia a playlist")
	button(screen, "Marcar todas").pressed.emit()
	await settle()
	check(music.available_tracks().size() == 14, "Marcar todas devolve as 14")
	nav.back()
	await settle()
	check(nav._active == settings and settings._category == 0, "Voltar retorna ao Áudio recente")
	music.save_selection([], [])
	check(not music.set_local_test_authorized(true) if not music.local_test_mode() else music.set_local_test_authorized(true), "autorização local exige modo explícito do editor")
	if music.local_test_mode(): await playback()
	check(music.reload_catalog() and music.tracks.size() == 14 and music.available_tracks().size() == 14, "catálogo real restaurado com as 14 faixas")
	menu.queue_free()
	await settle()
	print("T15B_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/qse-t15b-captures")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/qse-t15b-captures/" + label + ".png") == OK, "captura real " + label)
func playing() -> int:
	var count := 0
	for player in music._players:
		if player.playing: count += 1
	return count
func playback() -> void:
	music.pause()
	var fixtures: Array[Dictionary] = []
	for id in ["test-a", "test-b", "test-c"]:
		fixtures.append({"id": id, "title": "Silêncio técnico " + id, "artist": "Fixture PCM zerada", "category": "pop", "audio": "res://assets/music/_local_test/silence.wav", "cover": "res://assets/music/_local_test/cover.svg", "enabled": false, "license": {"status": "pending", "scope": "main_menu", "reference": "", "starts_at": 0, "ends_at": 0}})
	music.tracks = fixtures
	check(not music.licensed(fixtures[0]) and music.local_test_available(fixtures[0]), "teste local não transforma pendente em licença comercial")
	music.resume()
	await create_timer(1.2).timeout
	check(playing() == 1 and music.current_id == "test-a", "player real toca fixture local autorizada no menu")
	music.next_track()
	await create_timer(1.0).timeout
	check(music.current_id == "test-b" and playing() == 1, "próxima e crossfade")
	music.previous_track()
	await create_timer(1.0).timeout
	check(music.current_id == "test-a", "anterior")
	music.pause()
	var player: AudioStreamPlayer = music._players[music._active]
	var position := player.get_playback_position()
	await create_timer(0.35).timeout
	check(absf(player.get_playback_position() - position) < 0.05, "pausa conserva posição")
	music.resume()
	await create_timer(0.4).timeout
	check(player.get_playback_position() > position + 0.15, "retoma e avança áudio real")
	check(music.set_volume(0.32) and is_equal_approx(menu.get_node("Services").preferences.values.music, 0.32), "volume persistido pelo serviço T14B")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.32)), "volume aplicado no barramento")
	music.save_selection(["test-a"], ["test-c"])
	await create_timer(0.7).timeout
	check(music.current_id == "test-b", "playlist pula oculta e desmarcada")
	music.set_local_test_authorized(false)
	await create_timer(0.7).timeout
	check(playing() == 0 and music.available_tracks().is_empty(), "revogar teste local interrompe reprodução")
	check(fixtures.all(func(track): return track.license.status == "pending" and not track.enabled), "nenhuma licença ou enabled foi alterado")
	music.set_local_test_authorized(true)
	music.save_selection([], [])
	await create_timer(0.7).timeout
	var outside := Node3D.new()
	root.add_child(outside)
	current_scene = outside
	await create_timer(0.2).timeout
	check(not music._inside and playing() == 0, "fora do menu para ambos os canais")
	music.next_track()
	check(playing() == 0, "próxima fora do menu não reproduz")
	current_scene = menu
	await create_timer(1.0).timeout
	check(music._inside and playing() == 1, "retornar ao menu restaura player")
	outside.queue_free()
	music.set_local_test_authorized(false)
	music.save_selection([], [])
