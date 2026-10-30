extends PanelContainer
## Scalable, native geometry. No bitmap frame, text or fake controls in the decoration.
@export var atmosphere := false
@export var active := false
@export var padding := 9
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(padding if not atmosphere else 0)
	add_theme_stylebox_override("panel", style)
	resized.connect(queue_redraw)
func _draw() -> void:
	if size.x < 8 or size.y < 8: return
	if atmosphere:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#080f18"))
		for i in range(4):
			var x := size.x * (0.12 + i * 0.27)
			draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+30,0),Vector2(x-size.y*0.65,size.y),Vector2(x-size.y*0.65-18,size.y)]), Color(0.07,0.14,0.21,0.3))
			draw_line(Vector2(x+35,0),Vector2(x-size.y*0.65+35,size.y),Color(0.55,0.34,0.12,0.12),1,true)
		return
	var bounds := Rect2(Vector2(1,1), size - Vector2(2,2))
	_outline(bounds, Color("#211c15") if active else Color("#142637"), PlayerUI.GOLD if active else Color("#35546c"), 13)
	_outline(bounds.grow(-3), Color("#171812") if active else Color("#0a121c"), PlayerUI.GOLD if active else Color("#6b5533"), 10)
func _outline(rect: Rect2, fill: Color, edge: Color, cut: float) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	cut = minf(cut,minf(rect.size.x,rect.size.y)*0.28)
	var p := rect.position
	var e := rect.end
	var points := PackedVector2Array([Vector2(p.x+cut,p.y),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),Vector2(e.x,e.y-cut),Vector2(e.x-cut,e.y),Vector2(p.x+cut,e.y),Vector2(p.x,e.y-cut),Vector2(p.x,p.y+cut)])
	draw_colored_polygon(points,fill)
	points.append(points[0])
	draw_polyline(points,edge,1,true)
