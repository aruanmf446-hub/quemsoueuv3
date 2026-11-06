extends SceneTree
const Assets=preload("res://scripts/desert/t15d/kingdom_assets.gd")
const KINDS={1:"city_courtyard",3:"market_delivery",4:"canal",5:"riverbank",6:"buried_courtyard",7:"ore_road",8:"guard_supplies",9:"loading_yard",10:"mine_railway"}
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func frames() -> void:
	for i in 3:await process_frame
func run() -> void:
	for id: String in ["riverbank_context","city_supplies_context"]:
		var texture:=load("res://assets/desert/modular/"+id+".res") as Texture2D
		var image:=texture.get_image()
		check(maxi(texture.get_width(),texture.get_height())<=1024 and image.has_mipmaps() and image.detect_alpha()!=Image.ALPHA_NONE,id+": tamanho limitado, transparência e mipmaps")
	var shared: Dictionary={}
	for order in range(1,11):
		var paths:=Assets.paths(order)
		check(paths.has("res://assets/desert/modular/riverbank_context.res")== (order in [4,5]) and paths.has("res://assets/desert/modular/city_supplies_context.res")== (order in [1,3]),"fase%02d: aquece somente o complemento da região" % order)
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		phase.set_physics_process(false)
		phase._player.set_physics_process(false)
		for x: float in [12.0,350.0,700.0,1100.0,12.0]:
			phase._player.position.x=x
			phase._stream_world(x,true)
			for i in 2400:
				if phase._build_queue.is_empty():break
				phase._process(0)
			await frames()
			var valid: bool=phase._loaded_chunks.size()<=5
			var ids: Dictionary={}
			for props: Node3D in get_nodes_in_group("regional_context"):
				if not phase.is_ancestor_of(props):continue
				var batches:=0
				for mesh: Node in props.get_children():
					if not mesh is MeshInstance3D or not String(mesh.name).begins_with("City_context_"):continue
					batches+=1
					if mesh.get_aabb().end.z > -2.60 or mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or mesh.get_child_count()!=0:valid=false
					var key:=String(mesh.name)
					var material_id: int=mesh.material_override.get_instance_id()
					if shared.has(key) and shared[key]!=material_id:valid=false
					shared[key]=material_id
				if batches>3:valid=false
				for record: Dictionary in props.get_meta("regional_context"):
					var surface: Dictionary=phase._phase.surfaces[record.slot]
					if ids.has(record.id) or record.kind!=KINDS.get(order,"") or surface.get("task_void",false) or record.left<surface.left or record.right>surface.right or (order==10 and record.slot>=40):valid=false
					ids[record.id]=true
			for sprite: Sprite3D in get_nodes_in_group("regional_context_art"):
				if not phase.is_ancestor_of(sprite):continue
				var span: Vector2=sprite.get_meta("context_span")
				var half:=sprite.texture.get_width()*sprite.pixel_size*0.5
				var base: Texture2D=sprite.texture
				while base is AtlasTexture:base=(base as AtlasTexture).atlas
				if sprite.position.z > -3.50 or sprite.position.x-half<span.x-0.01 or sprite.position.x+half>span.y+0.01 or absf(sprite.position.y-sprite.texture.get_height()*sprite.pixel_size*0.5-float(sprite.get_meta("ground_y")))>0.01 or not paths.has(base.resource_path):valid=false
			if order==2 and not ids.is_empty():valid=false
			if order not in [2,10] and ids.is_empty():valid=false
			check(valid,"fase%02d x%.0f: tema correto, sem invasão da pista/vãos, até três lotes por chunk, materiais compartilhados" % [order,x])
		phase.free()
		await frames()
		check(get_nodes_in_group("regional_context").is_empty() and get_nodes_in_group("regional_context_art").is_empty(),"fase%02d: descarrega toda a decoração" % order)
	print("REGIONAL_CONTEXT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
