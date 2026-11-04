extends SceneTree
## Controles nativos por mouse/teclado, sobre gameplay real em janela do motor.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+message)
func mouse(button: Button, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event,true)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1672,941)
	var phase: Node3D = load("res://scenes/desert/phase_06.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(20)
	var player: Node3D = phase._player
	player._invulnerable = 999
	for index in range(3): player.restore_charge("amber")
	var amber: Button = phase._hud._action_buttons.amber
	check(amber.is_visible_in_tree(),"ação circular nativa fica visível no desktop")
	mouse(amber,true)
	await frames(3)
	mouse(amber,false)
	await frames(3)
	check(player.charges("amber") == 2,"clique real ativa Âmbar uma vez")
	check(not amber.has_focus(),"clique não prende o teclado de movimento na ação")
	var fire_before: int = player.attack_charges
	key(KEY_SPACE,true)
	await frames(3)
	key(KEY_SPACE,false)
	check(player.jumps_used == 1 and player.attack_charges == fire_before,"Espaço continua pulando após clique no HUD")
	amber.grab_focus()
	key(KEY_ENTER,true)
	await frames(3)
	key(KEY_ENTER,false)
	await frames(3)
	check(player.charges("amber") == 1,"Enter ativa o botão focado uma única vez")
	get_root().gui_release_focus()
	for action in ["jump","amber"]: Input.action_release(action)
	root.remove_child(phase)
	phase.queue_free()
	await frames(2)
	print("STORY_ACTION_CONTROLS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
