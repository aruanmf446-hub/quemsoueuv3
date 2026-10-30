extends Control
## Small reflected edges above the illustration, independent of the card geometry.
var selected := false
var removed := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	if size.x < 8 or size.y < 8: return
	var warm := Color(1,0.8,0.46,0.9 if selected else 0.48)
	if removed: warm = Color(0.6,0.67,0.76,0.22)
	draw_line(Vector2(4,1),Vector2(size.x*0.42,1),warm,1,true)
	draw_line(Vector2(1,4),Vector2(1,size.y*0.30),warm,1,true)
	draw_line(Vector2(size.x*0.7,size.y-1),Vector2(size.x-4,size.y-1),Color(warm,0.28),1,true)
	if selected:
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color("#f8ce88")
		badge.set_corner_radius_all(3)
		draw_style_box(badge,Rect2(size.x-20,4,16,14))
		draw_polyline(PackedVector2Array([Vector2(size.x-17,11),Vector2(size.x-14,14),Vector2(size.x-8,8)]),Color("#302316"),1.8,true)
