extends Control
## Indicadores pequenos apenas para inimigos próximos: vida real e preparação real.
var phase: Node3D
var _font: FontFile
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = preload("res://assets/desert/phase01/interface.ttf")
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(phase) or phase.completed or phase._respawning: return
	var camera: Camera3D = phase._camera
	var unit := get_viewport_rect().size.y/maxf(get_window().size.y,1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not phase.is_ancestor_of(enemy) or absf(enemy.position.x-phase._player.position.x) > 5.0: continue
		var head: Vector3 = enemy.global_position+Vector3.UP*1.65
		if camera.is_position_behind(head): continue
		var point := camera.unproject_position(head)
		for pip in range(1):
			var rect := Rect2(point+Vector2(pip*9-3,-3)*unit,Vector2(6,4)*unit)
			draw_style_box(_pip_style(Color("#e1b56c") if pip < enemy.health else Color(0.05,0.09,0.13,0.8)),rect)
		if enemy._windup > 0:
			var center := point+Vector2(0,-20)*unit
			draw_circle(center,10*unit,Color("#45292a"))
			draw_arc(center,11*unit,-PI*0.5,-PI*0.5+TAU*(1.0-enemy._windup/0.36),24,Color("#ffe0a2"),2*unit,true)
			draw_string(_font,center+Vector2(-2.4,5)*unit,"!",HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*unit),Color("#ffe0a2"))
func _pip_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(1)
	return box
