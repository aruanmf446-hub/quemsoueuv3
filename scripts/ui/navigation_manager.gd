class_name NavigationManager
extends Control

signal route_changed(route: String)
## Transições: a tela que entra sobe e aparece por cima; ao voltar, a que sai desce e some,
## revelando a anterior já pronta. O estado da navegação muda na hora; só o visual anima.
const FADE_IN := 0.18
const FADE_OUT := 0.15
const SLIDE := 22.0
var _routes: Dictionary = {}
var _screens: Dictionary = {}
var _history: Array[Dictionary] = []
var _active: PlayerScreen
var _previous_focus: WeakRef
var _busy := false
var _load_generation := 0
var _locked_at := 0
var _pending: Dictionary = {}
var _veil: LoadingVeil
const LOCK_TIMEOUT_MS := 2000
var _error_dialog: AcceptDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_routes = PlayerContracts.read_json("res://data/ui/routes.json").get("routes", {})
	_error_dialog = AcceptDialog.new()
	_error_dialog.dialog_text = "Esta tela não pôde ser carregada. Tente novamente."
	add_child(_error_dialog)


func register_screen(route: String, screen: PlayerScreen) -> void:
	if _screens.has(route):
		return
	_screens[route] = screen
	screen.hide()
	screen.back_requested.connect(back)
	screen.navigate_requested.connect(open)


## Entrada instantanea: renderiza a autenticacao antes do primeiro frame do lobby.
## Evita o LoadingVeil e a animacao que mostrariam o lobby por tras do login.
func open_initial(route: String, params: Dictionary = {}) -> void:
	if _busy or not _history.is_empty() or not _routes.has(route):
		return
	if not _screens.has(route):
		var scene := load(_routes[route]) as PackedScene
		if scene == null:
			push_error("Tela inicial indisponível: " + route)
			return
		var instance := scene.instantiate()
		var screen := instance as PlayerScreen
		if screen == null:
			instance.free()
			push_error("Tela inicial incompatível: " + route)
			return
		add_child(screen)
		register_screen(route, screen)
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_history.append({"route": route, "params": params.duplicate(true)})
	_display(route, params, false)


func open(route: String, params: Dictionary = {}) -> void:
	var perf_started := Time.get_ticks_usec()
	if not _routes.has(route): return
	if _busy:
		_pending = {"kind":"open","route":route,"params":params.duplicate(true)}
		return
	if not _history.is_empty() and _history.back() == {"route": route, "params": params}:
		return
	if _history.is_empty():
		_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	var veil: LoadingVeil
	_load_generation += 1
	var load_generation := _load_generation
	_lock()
	if not _screens.has(route):
		# Primeira abertura carrega a cena: mostra o véu antes, para o toque ter resposta.
		_lock()
		veil = await LoadingVeil.begin(get_tree(),"Carregando…",self)
		if load_generation != _load_generation:
			veil.finish()
			return
		_veil = veil
		var scene := load(_routes[route]) as PackedScene
		if scene == null:
			push_warning("Tela indisponível: %s" % route)
			veil.finish()
			_veil = null
			_unlock()
			_error_dialog.popup_centered()
			return
		var instance := scene.instantiate()
		var screen := instance as PlayerScreen
		if screen == null:
			instance.free()
			veil.finish()
			_veil = null
			_unlock()
			_error_dialog.popup_centered()
			return
		add_child(screen)
		register_screen(route, screen)
	_history.append({"route": route, "params": params.duplicate(true)})
	_display(route, params)
	if veil != null: veil.finish()
	_veil = null
	WebPerf.measure("open",perf_started)


func back() -> void:
	if _busy:
		_pending = {"kind":"back"}
		return
	if _history.is_empty(): return
	if _active != null and _active.handle_back(): return
	_history.pop_back()
	var leaving := _active
	if _history.is_empty():
		_active = null
		if _previous_focus != null and is_instance_valid(_previous_focus.get_ref()):
			_previous_focus.get_ref().grab_focus()
		route_changed.emit("")
	else:
		_display(_history.back().route, _history.back().params, false)
	if leaving != null and leaving != _active:
		_leave(leaving)
	else:
		_unlock()


func _display(route: String, params: Dictionary, animate := true) -> void:
	var perf_started := Time.get_ticks_usec()
	var outgoing := _active
	_active = _screens[route]
	_stop_motion(_active)
	_active.show_screen(params)
	route_changed.emit(route)
	if not animate:
		return
	_lock()
	var shown := _active
	shown.z_index = 1
	var tween := _motion(shown, Tween.EASE_OUT)
	var margin := shown.get_node_or_null("Margin") as Control
	if outgoing == null:
		# Internal screens cover the lobby immediately; only their content fades in.
		shown.modulate.a = 1.0
		if margin != null:
			margin.modulate.a = 0.0
			tween.tween_property(margin, "modulate:a", 1.0, FADE_IN)
	else:
		# Entre telas o fundo é o mesmo: só o conteúdo troca. Fundo e véu translúcidos ao
		# mesmo tempo deixavam a imagem clarear no meio da transição.
		_set_frame_alpha(shown, 0.0)
		var old_margin := outgoing.get_node_or_null("Margin") as CanvasItem
		if old_margin != null: tween.tween_property(old_margin, "modulate:a", 0.0, FADE_OUT * 0.7)
		if margin != null:
			margin.modulate.a = 0.0
			tween.tween_property(margin, "modulate:a", 1.0, FADE_IN)
	# Estado inicial aplicado já, não no primeiro passo do tween: sem um quadro "piscando".
	if margin != null:
		var rest := margin.position
		margin.position = rest + Vector2(0, SLIDE)
		tween.tween_property(margin, "position", rest, FADE_IN)
	if shown.has_method("animate_in"): shown.animate_in()
	tween.chain().tween_callback(func() -> void:
		_reset(shown)
		if outgoing != null and outgoing != _active:
			outgoing.hide()
			_reset(outgoing)
		_unlock())
	WebPerf.measure("_display",perf_started)


## Tela saindo (Voltar): desce e some. Para o lobby, some inteira; para outra tela,
## só o conteúdo troca sobre o mesmo fundo.

func _leave(screen: PlayerScreen) -> void:
	_stop_motion(screen)
	_lock()
	screen.z_index = 1
	var tween := _motion(screen, Tween.EASE_IN)
	var margin := screen.get_node_or_null("Margin") as Control
	var under := _active
	if under == null:
		tween.tween_property(screen, "modulate:a", 0.0, FADE_OUT)
	else:
		_set_frame_alpha(screen, 0.0)
		if margin != null: tween.tween_property(margin, "modulate:a", 0.0, FADE_OUT)
		var under_margin := under.get_node_or_null("Margin") as CanvasItem
		if under_margin != null:
			under_margin.modulate.a = 0.0
			tween.tween_property(under_margin, "modulate:a", 1.0, FADE_IN - 0.02).set_delay(0.03)
	if margin != null:
		tween.tween_property(margin, "position", margin.position + Vector2(0, SLIDE * 0.6), FADE_OUT)
	tween.chain().tween_callback(func() -> void:
		if screen != _active: screen.hide()
		_reset(screen)
		if under != null and is_instance_valid(under) and under.get_node_or_null("Margin") != null:
			(under.get_node("Margin") as CanvasItem).modulate.a = 1.0
		_unlock())


## Guarda onde a moldura da tela descansa, para qualquer animação interrompida voltar ao lugar.
func _motion(screen: PlayerScreen, easing: Tween.EaseType) -> Tween:
	var margin := screen.get_node_or_null("Margin") as Control
	if margin != null: screen.set_meta("nav_rest", margin.position)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	screen.set_meta("nav_motion", tween)
	return tween


func _stop_motion(screen: PlayerScreen) -> void:
	var perf_started := Time.get_ticks_usec()
	var tween: Variant = screen.get_meta("nav_motion") if screen.has_meta("nav_motion") else null
	if tween is Tween and (tween as Tween).is_valid(): (tween as Tween).kill()
	_reset(screen)
	WebPerf.measure("_stop_motion",perf_started)


## Devolve a tela ao estado normal: tudo opaco, na posição de descanso e no plano de baixo.

func _reset(screen: PlayerScreen) -> void:
	screen.remove_meta("nav_motion")
	var margin := screen.get_node_or_null("Margin") as Control
	if margin != null:
		margin.modulate.a = 1.0
		if screen.has_meta("nav_rest"):
			margin.position = screen.get_meta("nav_rest")
			screen.remove_meta("nav_rest")
	_set_frame_alpha(screen, 1.0)
	screen.modulate.a = 1.0
	screen.z_index = 0


func _set_frame_alpha(screen: PlayerScreen, alpha: float) -> void:
	for part in ["Backdrop", "Tint"]:
		var node := screen.get_node_or_null(part) as CanvasItem
		if node != null: node.modulate.a = alpha


func _lock() -> void:
	_busy = true
	_locked_at = Time.get_ticks_msec()

func _unlock() -> void:
	_busy = false
	_locked_at = 0
	_drain_pending.call_deferred()

func _drain_pending() -> void:
	if _busy or _pending.is_empty(): return
	var next := _pending
	_pending = {}
	if next.kind=="back": back()
	else: open(next.route,next.params)

func _process(_delta: float) -> void:
	if not _busy: return
	if _locked_at==0: _locked_at=Time.get_ticks_msec()
	if Time.get_ticks_msec()-_locked_at < LOCK_TIMEOUT_MS: return
	# Killed/paused tweens must never own the input lock indefinitely.
	_load_generation += 1
	for screen: PlayerScreen in _screens.values():
		if not is_instance_valid(screen): continue
		_stop_motion(screen)
		screen.visible = screen==_active
	if is_instance_valid(_veil): _veil.finish()
	_veil = null
	_unlock()
	WebPerf.measure("navigation.recovered",Time.get_ticks_usec())


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not _history.is_empty():
		back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree() and not _history.is_empty():
		back()
