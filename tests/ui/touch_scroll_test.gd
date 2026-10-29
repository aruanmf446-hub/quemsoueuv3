extends SceneTree
## Arraste rola listas, toque parado clica, arraste lateral em slider ajusta o valor.
var checks := 0
var failures := 0
func check(ok: bool, t: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ")+t); if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = pos; e.global_position = pos
	if pressed: e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)
func move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new(); e.position = pos; e.global_position = pos; e.relative = rel; e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)
func run() -> void:
	root.size = Vector2i(1280,560)
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	for i in 60: await process_frame
	var nav = current_scene.get_node("Navigation")
	nav.open("settings",{})
	for i in 40: await process_frame
	var screen = nav._active
	var scroll: ScrollContainer = screen._scroll
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "lista de áudio tem o que rolar")
	# Arrasta por cima do botão "Gerenciar músicas"/linhas: deve rolar e não clicar.
	var rect := scroll.get_global_rect()
	var p := rect.get_center() + Vector2(-rect.size.x*0.3, 60)
	var before := scroll.scroll_vertical
	mouse(p, true)
	var ts = root.get_node("TouchScroll")
	for k in range(10):
		move(p - Vector2(0, 12*(k+1)), Vector2(0,-12)); await process_frame
	mouse(p - Vector2(0,120), false)
	for i in 5: await process_frame
	var room := int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	check(scroll.scroll_vertical >= mini(before + 40, room), "arrastar sobre os itens rola a lista (%d→%d de %d)" % [before, scroll.scroll_vertical, room])
	check(nav._history.back().route == "settings", "arraste não aciona botão")
	# Toque parado: o clique ainda funciona (aba Gráficos).
	var tab: Button = screen._tabs[1]
	var c := tab.get_global_rect().get_center()
	mouse(c, true); await process_frame; mouse(c, false)
	for i in 5: await process_frame
	check(screen._category == 1, "toque parado continua clicando (aba Gráficos)")
	# Arraste lateral num slider ajusta o volume em vez de rolar.
	screen._tabs[0].pressed.emit()
	for i in 10: await process_frame
	scroll.scroll_vertical = 0
	for i in 3: await process_frame
	var slider: HSlider = screen._content.find_children("*","HSlider",true,false)[0]
	var sr := slider.get_global_rect()
	var sp := Vector2(sr.position.x + sr.size.x*0.9, sr.get_center().y)
	mouse(sp, true)
	for k in range(8):
		move(sp - Vector2(30*(k+1), 0), Vector2(-30,0)); await process_frame
	mouse(sp - Vector2(240,0), false)
	for i in 5: await process_frame
	check(slider.value < 0.95, "arraste lateral no slider muda o volume (%.2f)" % slider.value)
	print("SCROLL_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
