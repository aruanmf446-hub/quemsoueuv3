extends RefCounted
## Acabamento dos módulos industriais, sem duplicar ou substituir suas texturas.
## O material compartilhado também acompanha os recortes de fachada e das Tasks.
const FINISH=preload("res://scripts/desert/t15d/industrial_finish.gdshader")
static var _materials: Dictionary={}

static func apply_to(sprite: Sprite3D) -> void:
	var base: Texture2D=sprite.texture
	while base is AtlasTexture:base=(base as AtlasTexture).atlas
	var path:=base.resource_path
	if not (path.ends_with("/desert_timber_bridge.res") or path.ends_with("/desert_mining_gantry.res")):return
	var key:=base.get_instance_id()
	if not _materials.has(key):
		var material:=ShaderMaterial.new()
		material.shader=FINISH
		material.set_shader_parameter("source_art",base)
		material.set_shader_parameter("gantry",path.ends_with("/desert_mining_gantry.res"))
		_materials[key]=material
	sprite.material_override=_materials[key]
