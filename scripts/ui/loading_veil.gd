class_name LoadingVeil
extends CanvasLayer
## Véu "Carregando…" com anel girando, mostrado antes de trabalhos pesados (abrir tela,
## iniciar fase). Sem ele o toque parecia travar o celular: nada mudava até o fim do carregamento.
var _time := 0.0
var _ring: Control
var _finishing := false
var _request_owner: WeakRef

## Mostra o véu e espera ele ser desenhado; depois o chamador faz o trabalho pesado
## e chama finish().
static func begin(tree: SceneTree, text := "Carregando…", request_owner: Node = null) -> LoadingVeil:
	var veil := LoadingVeil.new()
	if request_owner != null: veil._request_owner = weakref(request_owner)
	veil.layer = 90
	veil.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(veil)
	veil._build(text)
	# Dois quadros: o véu chega à tela antes do carregamento bloquear o processamento.
	# (frame_post_draw não é emitido sem renderizador, por isso process_frame.)
	await tree.process_frame
	await tree.process_frame
	return veil

func finish() -> void:
	if not is_inside_tree() or _finishing: return
	_finishing = true
	# Libera o toque na hora; só o desvanecer continua.
	(get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween()
	fade.tween_property(get_child(0), "modulate:a", 0.0, 0.15)
	fade.tween_callback(queue_free)

func _build(text: String) -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	var unit := UIScale.unit_for(holder.get_viewport()) if UIScale.is_compact() else 1.0
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(56, 56) * unit
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.position = holder.get_viewport().get_visible_rect().size * 0.5 - Vector2(28, 44) * unit
	_ring.size = _ring.custom_minimum_size
	_ring.draw.connect(func() -> void:
		var c := _ring.size * 0.5
		_ring.draw_arc(c, c.x - 3 * unit, 0, TAU, 48, Color(1, 1, 1, 0.15), 4 * unit, true)
		_ring.draw_arc(c, c.x - 3 * unit, _time * 6.0, _time * 6.0 + 1.9, 32, PlayerUI.GOLD, 4 * unit, true))
	holder.add_child(_ring)
	var label := PlayerUI.label(text, int(18 * unit), Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_top = 70 * unit
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)

func _process(delta: float) -> void:
	if _request_owner != null and not is_instance_valid(_request_owner.get_ref()): finish()
	_time += delta
	if is_instance_valid(_ring): _ring.queue_redraw()
