extends SceneTree
## Compara a arte original e o acabamento no render real, inclusive transparência.
## Protege contra a remoção de madeira/cordas junto com os estandartes.
const Finish=preload("res://scripts/desert/t15d/industrial_finish.gd")
var checks:=0
var failures:=0
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func capture(view: SubViewport) -> Image:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func run() -> void:
	var out:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for id: String in ["desert_timber_bridge","desert_mining_gantry"]:
		var view:=SubViewport.new()
		view.size=Vector2i(1024,768)
		view.transparent_bg=true
		view.own_world_3d=true
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var texture:=load("res://assets/desert/modular/"+id+".res") as Texture2D
		var sprite:=Sprite3D.new()
		sprite.texture=texture
		sprite.shaded=false
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.pixel_size=3.8/texture.get_width()
		view.add_child(sprite)
		var camera:=Camera3D.new()
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=4.0
		camera.position.z=5.0
		view.add_child(camera)
		var before:=await capture(view)
		Finish.apply_to(sprite)
		var after:=await capture(view)
		check(before.save_png(out+"/"+id+"_original.png")==OK,id+": original salvo")
		check(after.save_png(out+"/"+id+"_sem_bandeiras.png")==OK,id+": acabamento salvo")
		var controls: Array=[Vector2(0.32,0.16),Vector2(0.55,0.35),Vector2(0.60,0.90),Vector2(0.92,0.57)] if id.ends_with("gantry") else [Vector2(0.08,0.17),Vector2(0.38,0.35),Vector2(0.60,0.90),Vector2(0.92,0.47)]
		var banners: Array=[Vector2(0.15,0.40),Vector2(0.50,0.80)] if id.ends_with("gantry") else [Vector2(0.204,0.55),Vector2(0.484,0.55),Vector2(0.764,0.55)]
		var dimensions:=Vector2(texture.get_size())*sprite.pixel_size
		var differences: Array=[]
		for uv: Vector2 in controls+banners:
			var screen:=Vector2i(camera.unproject_position(Vector3((uv.x-0.5)*dimensions.x,(0.5-uv.y)*dimensions.y,0)).round())
			var original:=before.get_pixelv(screen)
			var cleaned:=after.get_pixelv(screen)
			var delta:=(Vector4(original.r,original.g,original.b,original.a)-Vector4(cleaned.r,cleaned.g,cleaned.b,cleaned.a)).length()
			check(delta<0.04 if controls.has(uv) else delta>0.12,id+(": estrutura preservada " if controls.has(uv) else ": bandeira removida ")+str(uv))
			if banners.has(uv):
				check(cleaned.a>0.95 if id.ends_with("gantry") else cleaned.a<0.05,id+": pilar/carrinho sólido ou vão da treliça aberto "+str(uv))
			differences.append({"uv":[uv.x,uv.y],"delta":delta,"control":controls.has(uv)})
		records.append({"asset":id,"differences":differences})
		view.free()
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":true,"records":records},"\t"))
	print("INDUSTRIAL_FINISH_RENDER checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
