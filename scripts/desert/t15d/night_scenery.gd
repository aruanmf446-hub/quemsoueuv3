extends Node3D
## Três profundidades por fase. Cenário ilustrativo sem colisão; o solo permanece mundial.
signal location_changed(place: Dictionary)
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
const DEPTHS := [0.02,0.12,0.30]
var _layers: Array[Sprite3D] = []
var _order := 1
var _length := 1452.0
var _start := -8.0
var travel := 0.0
var parallax_offset := 0.0
var district := 0
var place_index := -1
func configure(order: int, length: float = 1452.0, start: float = -8.0) -> void:
	_order = clampi(order,1,9)
	_length = length
	_start = start
func _ready() -> void:
	for index in range(3):
		var layer := Sprite3D.new()
		layer.name = ["MoonlitSky","DistantCity","NearArchitecture"][index]
		layer.texture = load("res://assets/desert/reino_v3/parallax/phase_%02d/%s.png" % [_order,["01_sky_mountains","02_city_distance","03_architecture_near"][index]])
		layer.pixel_size = 0.01
		layer.shaded = false
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.render_priority = index
		add_child(layer)
		_layers.append(layer)
func current_place() -> Dictionary:
	return {"name":Layout.STAGE_DISTRICTS[_order-1][district],"ambient":Color(["#819ecb","#99a5bf","#718eaf","#9698b0","#8199ba","#a79c88","#8a9fc0","#819ecb"][district])}
func follow(camera: Camera3D, x: float) -> void:
	travel = clampf((x-_start)/_length,0,1)
	district = mini(7,int(travel*8))
	if district != place_index:
		place_index = district
		location_changed.emit(current_place())
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	for index in range(_layers.size()):
		var layer := _layers[index]
		var texture_aspect := float(layer.texture.get_width())/layer.texture.get_height()
		var overscan: float = [1.25,1.45,1.65][index]
		var height := maxf(camera.size*overscan,camera.size*aspect/texture_aspect*overscan)
		var margin := maxf(0.0,(height*texture_aspect-camera.size*aspect)*0.5)
		parallax_offset = lerpf(-margin,margin,travel)*DEPTHS[index]/0.30
		layer.basis = camera.basis
		layer.position = camera.position-camera.basis.z*(48.0-index*0.5)-camera.basis.x*parallax_offset
		layer.scale = Vector3.ONE*height/(layer.texture.get_height()*0.01)
