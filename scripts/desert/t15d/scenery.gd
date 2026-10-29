extends Node3D
## Panorâmica contínua: sem dissolver arquiteturas diferentes no mesmo horizonte.
var _panorama: Sprite3D
var travel := 0.0
var parallax_offset := 0.0
func _ready() -> void:
	_panorama = Sprite3D.new()
	_panorama.texture = preload("res://assets/desert/phase01/desert_canyon.png")
	_panorama.pixel_size = 0.01
	_panorama.shaded = false
	_panorama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panorama.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_panorama)
func follow(camera: Camera3D, x: float) -> void:
	travel = clampf((x+8.0)/60.0,0.0,1.0)
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var height := maxf(camera.size*1.25,camera.size*aspect/1.778*1.25)
	_panorama.basis = camera.basis
	# Margem maior que a paralaxe nas duas orientações landscape.
	var margin := camera.size*aspect*0.065
	parallax_offset = lerpf(-margin,margin,travel)
	var rise := clampf((camera.position.y-2.65)*0.22,0.0,height*0.05)
	_panorama.position = camera.position-camera.basis.z*48-camera.basis.x*parallax_offset-camera.basis.y*rise
	_panorama.scale = Vector3.ONE*height/(_panorama.texture.get_height()*0.01)
