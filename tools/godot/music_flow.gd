extends SceneTree
## Harness da seleção de músicas do menu e da tela Músicas. Uso:
## godot --headless --path . -s res://tools/godot/music_flow.gd
## As faixas de teste usam áudio real importado com licença fictícia só em memória:
## nada é gravado no catálogo e a seleção salva é removida ao final.

const SELECTION_FILE := "user://menu_music_selection.cfg"
const COVER := "res://assets/processed/logos/logo_quem_sou_eu_retangular.png"

var failures := 0
var music: Node


class Preferences:
	extends Node
	var values := {"music": 1.0}
	func set_preference(key: String, value: float) -> bool:
		values[key] = value
		return true


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	music = root.get_node_or_null("MenuMusic")
	check(music != null, "autoload MenuMusic presente")
	if music == null:
		return finish()
	music.set_process(false)
	_catalog_checks()
	var pref := Preferences.new()
	root.add_child(pref)
	music._preferences = pref
	music.save_selection([], [])
	music._inside = true
	music.tracks = _fixtures()
	_selection_checks()
	_transport_checks(pref)
	await _screen_checks()
	_cleanup()
	finish()


func finish() -> void:
	print("MUSIC_FLOW_FAILURES ", failures)
	quit(1 if failures > 0 else 0)


func _catalog_checks() -> void:
	var categories := {}
	var all_disabled := true
	for track: Dictionary in music.tracks:
		categories[track.category] = true
		all_disabled = all_disabled and track.enabled == false and track.license.status == "pending"
	check(music.tracks.size() == 14, "catálogo lista as 14 faixas")
	check(categories.size() == 5, "cinco categorias")
	check(all_disabled, "todas as entradas pendentes e desativadas")
	check(music.available_tracks().is_empty(), "catálogo pendente não toca nada")


func _selection_checks() -> void:
	check(music.available_tracks().size() == 3, "três faixas de teste disponíveis sem escolha")
	music.save_selection(["t-a"], ["t-b"])
	check(music.is_excluded("t-a") and music.is_excluded("t-b") and not music.is_excluded("t-c"), "ocultas e desmarcadas são excluídas")
	var ids: Array = music.available_tracks().map(func(t: Dictionary) -> String: return t.id)
	check(ids == ["t-c"], "playlist contém só a faixa selecionada")
	check(FileAccess.file_exists(SELECTION_FILE), "escolha gravada no disco")
	var fresh: Node = load("res://scripts/audio/menu_music.gd").new()
	fresh._load_selection()
	check(fresh.selection().hidden == ["t-a"] and fresh.selection().deselected == ["t-b"], "escolha recarregada do disco")
	fresh.free()
	music.save_selection([], [])
	check(music.available_tracks().size() == 3, "limpar escolha restaura as três faixas")
	music.save_selection(["t-a"], ["t-b"])


func _transport_checks(pref: Preferences) -> void:
	music._select(1)
	check(music.current_id == "t-c" and music._players[music._active].playing, "início toca a primeira faixa selecionada")
	music.next_track()
	check(music.current_id == "t-c", "próxima com uma faixa disponível permanece na mesma")
	music.save_selection([], ["t-b"])
	music.next_track()
	check(music.current_id == "t-a", "próxima avança para faixa reexibida")
	music.previous_track()
	check(music.current_id == "t-c", "anterior volta e pula faixa desmarcada")
	music.save_selection(["t-c"], ["t-b"])
	music.next_track()
	check(music.current_id == "t-a", "faixa oculta durante a reprodução é pulada")
	music.pause()
	check(music.paused and music._players[music._active].stream_paused, "pausa")
	music.resume()
	check(not music.paused and not music._players[music._active].stream_paused, "retomar")
	music.set_volume(0.35)
	check(is_equal_approx(pref.values.music, 0.35), "volume salvo")
	music.set_muted(true)
	check(pref.values.music == 0.0, "mudo zera o volume")
	music.set_muted(false)
	check(is_equal_approx(pref.values.music, 0.35), "desmutar restaura o volume")
	music._leave_menu()
	var any_playing := false
	for player in music._players:
		any_playing = any_playing or player.playing
	check(not any_playing, "saída do menu para a música (gameplay) para os dois canais")
	music._select(1)
	check(not music._players[music._active].playing, "nada toca fora do menu")
	music._inside = true


func _screen_checks() -> void:
	music.save_selection([], [])
	var menu: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for frame in range(30):
		await process_frame
	var nav: Node = menu.get_node("Navigation")
	nav.call("open", "music", {})
	for frame in range(40):
		await process_frame
	var screen: Control = nav.get("_screens").get("music")
	check(screen != null and screen.is_visible_in_tree(), "tela Músicas abre pela rota")
	screen.call("_select_category", "pop")
	await process_frame
	check(_dirty(screen) == false, "tela começa sem alterações")
	check(_button(screen, "Salvar").disabled and _button(screen, "Descartar").disabled, "salvar e descartar desabilitados sem alterações")
	screen.call("_set_hidden", "t-a", true)
	check(_dirty(screen), "ocultar marca alteração")
	check(not music.selection().hidden.has("t-a"), "rascunho não altera a seleção salva")
	check(not _button(screen, "Salvar").disabled, "salvar habilitado com alteração")
	screen.call("_discard")
	check(not _dirty(screen) and music.selection().hidden.is_empty(), "descartar volta ao estado salvo")
	screen.call("_set_hidden", "t-a", true)
	screen.call("_set_selected", false, "t-b")
	_button(screen, "Salvar").pressed.emit()
	await process_frame
	check(music.is_excluded("t-a") and music.is_excluded("t-b"), "salvar aplica ocultas e desmarcadas")
	check(not _dirty(screen), "após salvar não há alterações pendentes")
	screen.call("_set_hidden", "t-a", false)
	screen.call("_set_selected", true, "t-b")
	_button(screen, "Salvar").pressed.emit()
	await process_frame
	check(music.selection().hidden.is_empty() and music.selection().deselected.is_empty(), "reexibir e marcar restaura a playlist")
	nav.call("back")
	for frame in range(20):
		await process_frame
	check(not screen.is_visible_in_tree(), "voltar fecha a tela Músicas")
	menu.queue_free()
	await process_frame


func _dirty(screen: Control) -> bool:
	return screen.call("_dirty")


func _button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child.text == text or child.text.ends_with(" " + text):
			return child
	return Button.new()


func _fixtures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names := {"t-a": "Almost In Love", "t-b": "Bad at Being Good", "t-c": "Too Good to Miss"}
	var files := {"t-a": "res://assets/music/pop/Almost In Love.mp3", "t-b": "res://assets/music/pop/Bad at Being Good.mp3", "t-c": "res://assets/music/pop/Too Good to Miss.mp3"}
	for id: String in ["t-a", "t-b", "t-c"]:
		result.append({"id": id, "category": "pop", "title": names[id], "artist": "Teste", "audio": files[id], "cover": COVER, "enabled": true,
			"license": {"status": "approved", "scope": "main_menu", "reference": "TESTE-LOCAL", "starts_at": 0, "ends_at": 4102444800}})
	return result


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SELECTION_FILE))
	music.reload_catalog()
	check(music.tracks.size() == 14 and music.available_tracks().is_empty(), "catálogo real restaurado ao final")
