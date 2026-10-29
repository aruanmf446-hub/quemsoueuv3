extends Button
## Ícone vetorial leve; evita cor/forma dependente das fontes emoji da plataforma.
var active := false:
	set(value):
		active = value
		queue_redraw()
func _draw() -> void:
	var points := PackedVector2Array()
	for index in range(65):
		var t := TAU * index / 64.0
		var point := Vector2(16.0 * pow(sin(t), 3), -(13.0*cos(t)-5.0*cos(2*t)-2.0*cos(3*t)-cos(4*t)))
		points.append(size * 0.5 + point * 0.65)
	var tint := Color("#e5c582") if active else Color("#a8b9d0")
	if active:
		draw_colored_polygon(points, tint)
	else:
		draw_polyline(points, tint, 1.5, true)
