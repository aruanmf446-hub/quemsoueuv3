extends SceneTree
## Verificacoes deterministas locais: sem conta real, sem alterar Supabase.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("UI_SESSION_MUSIC_FAIL " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu_src := (load("res://scripts/menu/main_menu.gd") as GDScript).source_code
	var session_src := (load("res://scripts/services/session_service.gd") as GDScript).source_code
	var profile_src := (load("res://scripts/ui/screens/profile_screen.gd") as GDScript).source_code
	var account_src := (load("res://scripts/ui/screens/account_screen.gd") as GDScript).source_code
	var music_src := (load("res://scripts/ui/screens/music_screen.gd") as GDScript).source_code
	check(menu_src.contains("initial_restore_finished.connect"), "startup waits for GAME refresh")
	check(menu_src.contains("if not _services.session.authenticated() or _services.session.needs_password_reset:"), "guest opens account only after restoration")
	check(menu_src.contains("func _show_startup_cover"), "block premature lobby input")
	check(session_src.contains("initial_restore_finished.emit()"), "login restore completion signaled")
	check(profile_src.contains("DisconnectAccount") and profile_src.contains("services.session.sign_out()"), "profile has real signout")
	check(not account_src.contains('"Sair da conta"'), "no signout on login screen")
	check(music_src.contains('preview.name = "Preview_" + id'), "play button per track")
	check(music_src.contains('preview.pressed.connect(_preview.bind(id))'), "preview has real event handler")
	var player := root.get_node_or_null("MenuMusic") as MenuMusicPlayer
	check(player != null, "using real autoload music transport")
	if player != null:
		var track: Dictionary = {}
		for item: Dictionary in player.tracks:
			if player.can_preview(str(item.id)):
				track = item
				break
		check(not track.is_empty(), "licensed preview available")
		if not track.is_empty():
			var id := str(track.id)
			var before := player.selection()
			player._inside = true
			check(player.toggle_preview(id), "preview button starts real transport")
			check(player.current_id == id, "preview picks requested track")
			check(player.toggle_preview(id) and player.paused, "repeated play pauses")
			check(player.toggle_preview(id) and not player.paused, "repeat resumes")
			check(player.selection() == before, "preview never modifies checkbox state")
			player.pause()
			player._inside = false
			player._stop()
	print("UI_SESSION_MUSIC_RESULT checks=",checks," failures=",failures)
	quit(1 if failures > 0 else 0)
