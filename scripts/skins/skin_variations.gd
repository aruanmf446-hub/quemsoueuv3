extends RefCounted
## Editable palette variants, using the original mesh, texture detail and animation.
## Preview only: no ownership, price, unlock or multiplayer equipment is fabricated.
const SHADER=preload("res://scripts/skins/variation_palette.gdshader")
const PALETTES := {
	"cowboy":[0.0,0.05,"Patrulheiro Azul","Forasteiro Violeta"],
	"el_fuego":[0.0,0.05,"Chama Azul","Chama Violeta"],
	"halloween":[0.12,0.07,"Bosque Encantado","Colheita Arcana"],
	"michelly":[0.15,0.055,"Guardiã Azul","Guardiã Violeta"],
	"rodrigo":[0.0,0.05,"Cavaleiro Azul","Cavaleiro Violeta"],
	"lorena":[0.65,0.11,"Armadura Esmeralda","Armadura Carmesim"],
	"gus":[0.27,0.09,"Sentinela Azul","Sentinela Violeta"],
	"lana":[0.085,0.025,"Lua Azul","Lua Violeta"],
}
static func entries(id: String) -> Array[Dictionary]:
	if not PALETTES.has(id): return []
	var colors: Array=[0.57,0.77] if id!="lorena" else [0.38,0.98]
	return [{"id":"original","name":"Original","target":0.0},
		{"id":"style_1","name":PALETTES[id][2],"target":colors[0]},
		{"id":"style_2","name":PALETTES[id][3],"target":colors[1]}]

static func apply(slot: CharacterSlot,style: String) -> bool:
	var id := str(slot.character_id)
	if not PALETTES.has(id) or slot.get("_model_root")==null: return false
	var selected: Dictionary={}
	for option in entries(id):
		if option.id==style: selected=option
	if selected.is_empty(): return false
	for mesh: MeshInstance3D in slot.get("_model_root").find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_meta("qse_surface_material_%d" % surface) as BaseMaterial3D if mesh.has_meta("qse_surface_material_%d" % surface) else null
			if original==null: continue
			if style=="original":
				mesh.set_surface_override_material(surface,original)
				continue
			var material := mesh.get_meta("qse_variation_material_%d" % surface) as ShaderMaterial if mesh.has_meta("qse_variation_material_%d" % surface) else null
			if material==null:
				material=ShaderMaterial.new()
				material.shader=SHADER
				mesh.set_meta("qse_variation_material_%d" % surface,material)
			for pair in [["base_color",original.albedo_color],["base_texture",original.albedo_texture],
				["has_texture",original.albedo_texture!=null],["has_normal",original.normal_enabled],
				["normal_texture",original.normal_texture],["normal_strength",original.normal_scale],
				["vertex_color_enabled",original.vertex_color_use_as_albedo],
				["surface_roughness",original.roughness],["surface_metallic",original.metallic],
				["clothing_height",1.3 if id in ["halloween","michelly"] else 10000.0],
				["source_hue",PALETTES[id][0]],["hue_width",PALETTES[id][1]],["target_hue",selected.target]]:
				material.set_shader_parameter(pair[0],pair[1])
			mesh.set_surface_override_material(surface,material)
	return true
