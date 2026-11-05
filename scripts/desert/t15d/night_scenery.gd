extends Node3D
## Panorâmicas aprovadas somente ao longe. Toda a rota próxima é geometria 3D modular.
signal location_changed(place: Dictionary)
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var _panorama: Sprite3D
var _skyline: Node3D
var _order := 1
var _length := 1452.0
var _start := -8.0
var travel := 0.0
var parallax_offset := 0.0
var district := 0
var place_index := -1
func configure(order: int,length: float = 1452.0,start: float = -8.0) -> void:
	_order = clampi(order,1,10)
	_length = length
	_start = start
func _ready() -> void:
	if _order in [6,10]: return
	_panorama = Sprite3D.new()
	var key := "bazaar" if _order == 3 else ("outskirts" if _order in [6,7,9] else "citadel")
	_panorama.texture = load("res://assets/desert/modular/capital_desert.res")
	_panorama.pixel_size = 0.01
	_panorama.shaded = false
	_panorama.modulate = Color(0.72,0.75,0.90)
	_panorama.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_panorama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panorama)
	_skyline = preload("res://scripts/desert/t15d/capital_skyline.gd").new()
	_skyline.configure(_order)
	add_child(_skyline)
func current_place() -> Dictionary:
	return {"name":Layout.STAGE_DISTRICTS[_order-1][district],"ambient":Color("#8895be")}
func follow(camera: Camera3D,x: float) -> void:
	travel = clampf((x-_start)/_length,0,1)
	district = mini(7,int(travel*8))
	if district != place_index:
		place_index = district
		location_changed.emit(current_place())
	if not is_instance_valid(_panorama): return
	if _order == 7: _panorama.modulate.a = lerpf(1.0,0.5,travel)
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var height := maxf(camera.size*1.65,camera.size*aspect/1.778*1.65)
	parallax_offset = lerpf(-1.0,1.0,travel)*camera.size*0.22
	_panorama.basis = camera.basis
	_panorama.position = camera.position-camera.basis.z*48-camera.basis.x*parallax_offset
	_panorama.position += camera.basis.y*camera.size*0.22
	_panorama.scale = Vector3.ONE*height/(_panorama.texture.get_height()*0.01)
	if is_instance_valid(_skyline): _skyline.follow(camera,x,travel)
