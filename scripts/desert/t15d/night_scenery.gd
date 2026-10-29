extends Node3D
## Cidade do deserto à noite: uma panorâmica coerente por distrito, sem dissolve.
## configure() pode ser chamado antes ou depois de add_child(); follow() mantém
## a mesma API do fundo original e nunca usa a distância total como período de loop.
const DISTRICTS := [
	"res://assets/desert/night_city/outskirts.png",
	"res://assets/desert/night_city/bazaar.png",
	"res://assets/desert/night_city/citadel.png",
]
var _panorama: Sprite3D
var _order := 1
var _length := 1200.0
var _start := -8.0
var travel := 0.0
var parallax_offset := 0.0
var district := 0

func configure(order: int, length: float = 1200.0, start: float = -8.0) -> void:
	_order = clampi(order,1,9)
	_length = maxf(length,1.0)
	_start = start
	district = clampi(int((_order-1)/3.0),0,2)
	if is_instance_valid(_panorama): _load_district()

func _ready() -> void:
	_panorama = Sprite3D.new()
	_panorama.name = "MoonlitCityPanorama"
	_panorama.pixel_size = 0.01
	_panorama.shaded = false
	# O pano de fundo não disputa luminância com El Fuego e os indicadores de ação.
	_panorama.modulate = Color(0.88,0.88,0.88,1.0)
	_panorama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panorama.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_panorama)
	_load_district()

func _load_district() -> void:
	_panorama.texture = load(DISTRICTS[district]) as Texture2D

func follow(camera: Camera3D, x: float) -> void:
	if not is_instance_valid(_panorama) or _panorama.texture == null: return
	travel = clampf((x-_start)/_length,0.0,1.0)
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	# A margem de 25% cobre as duas razões landscape testadas e a paralaxe vertical.
	var texture_aspect := float(_panorama.texture.get_width())/_panorama.texture.get_height()
	var height := maxf(camera.size*1.25,camera.size*aspect/texture_aspect*1.25)
	_panorama.basis = camera.basis
	var margin := camera.size*aspect*0.065
	parallax_offset = lerpf(-margin,margin,travel)
	var rise := clampf((camera.position.y-2.65)*0.22,0.0,height*0.05)
	_panorama.position = camera.position-camera.basis.z*48-camera.basis.x*parallax_offset-camera.basis.y*rise
	_panorama.scale = Vector3.ONE*height/(_panorama.texture.get_height()*0.01)
