extends SceneTree
## T22: Configurações redesenhadas. Cada controle altera uma preferência real; nada sem efeito.
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 4) -> void:
	for i in count: await process_frame


func _run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	await _frames()
	var prefs := services.preferences
	var before := prefs.values.duplicate()
	var screen := load("res://scenes/player/settings.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await _frames()
	check(screen.find_child("CategoryNav", true, false).get_child_count() == 5, "navegação horizontal com 5 categorias")
	check(screen.find_child("Brand", true, false) != null and screen.find_child("SettingsBackdrop", true, false) != null, "cabeçalho com marca e fundo do sistema visual")
	check(screen.find_child("MainPanel", true, false) != null and screen.find_child("SidePanel", true, false) != null, "painel principal e lateral")
	# Meu Perfil (visitante): retrato real e entrada na conta.
	var portrait := screen.find_child("Portrait", true, false) as TextureRect
	check(portrait != null and portrait.texture != null, "retrato do personagem equipado")
	check(screen.find_child("EnterAccount", true, false) != null, "visitante vê Entrar na conta")
	# Áudio.
	screen._select(1)
	await _frames()
	var menu_toggle := screen.find_child("MenuMusicToggle", true, false) as CheckButton
	menu_toggle.button_pressed = false
	check(prefs.values.menu_music == false, "Música nos menus grava a preferência")
	menu_toggle.button_pressed = true
	check(screen.find_child("ManageMusic", true, false) != null, "Gerenciar músicas")
	check(screen.find_child("PreviewEffect", true, false) != null and screen.find_child("PreviewMusic", true, false) != null, "prévia só de sons reais")
	check(screen.find_child("Slider_master", true, false) != null and screen.find_child("Slider_dialogue", true, false) == null, "sem canal de diálogos inexistente")
	# Gráficos: pendente até Aplicar; Restaurar volta ao padrão.
	screen._select(2)
	await _frames()
	(screen.find_child("Quality_alto", true, false) as Button).pressed.emit()
	await _frames()
	(screen.find_child("ShadowsToggle", true, false) as CheckButton).button_pressed = false
	check(prefs.values.quality == before.quality or before.quality == "alto", "qualidade só muda ao aplicar")
	(screen.find_child("ApplyGraphics", true, false) as Button).pressed.emit()
	await _frames()
	check(prefs.values.quality == "alto" and prefs.values.shadows == false, "Aplicar alterações grava qualidade e sombras")
	var stage := load("res://scenes/lobby/lobby_stage.tscn").instantiate() as LobbyStage
	root.add_child(stage)
	await _frames()
	stage.apply_profile("alto")
	check(not stage.get_node("Viewport/World/KeyLight").shadow_enabled, "sombras desligadas no palco real")
	stage.queue_free()
	(screen.find_child("RestoreGraphics", true, false) as Button).pressed.emit()
	(screen.find_child("ApplyGraphics", true, false) as Button).pressed.emit()
	await _frames()
	check(prefs.values.shadows == true and prefs.values.quality == GraphicsProfile.default_for_platform(), "Restaurar padrão + Aplicar")
	check(screen.find_child("Meter_fps", true, false) != null and screen.find_child("Meter_memory", true, false) != null, "desempenho com medições do motor")
	# Controles: remapear de verdade.
	screen._select(3)
	await _frames()
	var remap := screen.find_child("Remap_accept_key", true, false) as Button
	remap.pressed.emit()
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_H
	screen._input(key)
	check(prefs.values.accept_key == KEY_H, "remapear Confirmar")
	prefs.set_preference("accept_key", before.accept_key)
	# Idioma: só aplica ao confirmar.
	screen._select(4)
	await _frames()
	(screen.find_child("Locale_en", true, false) as Button).pressed.emit()
	await _frames()
	check(prefs.values.locale == before.locale, "escolher idioma não aplica antes de confirmar")
	(screen.find_child("ConfirmLanguage", true, false) as Button).pressed.emit()
	await _frames()
	check(prefs.values.locale == "en", "Confirmar aplica o idioma")
	for k: String in ["locale", "quality", "shadows", "menu_music", "window"]: prefs.set_preference(k, before.get(k, prefs.values[k]))
	print("T22_SETTINGS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
