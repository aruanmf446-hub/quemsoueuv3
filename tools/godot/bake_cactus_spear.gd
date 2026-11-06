extends SceneTree
## Asset original do projeto, gerado no Godot. Eixo +X; ponta em +0,94m.
func _initialize() -> void:
	var mesh:=ArrayMesh.new()
	var builders: Array[SurfaceTool]=[]
	for i in 4:
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders.append(st)
	cylinder(builders[0],-0.10,1.25,0.026)
	cylinder(builders[3],-0.22,0.30,0.034)
	for x: float in [-0.39,-0.05,0.47,-0.72]:cylinder(builders[2],x,0.055,0.038)
	var base:=Vector3(0.49,0,0)
	var tip:=Vector3(0.94,0,0)
	var a:=Vector3(0.67,0.105,0)
	var b:=Vector3(0.67,-0.105,0)
	for z: float in [-0.035,0.035]:
		var ridge:=Vector3(0.68,0,z)
		for triangle: Array in [[base,a,ridge],[a,tip,ridge],[tip,b,ridge],[b,base,ridge]]:
			for p: Vector3 in triangle:builders[1].add_vertex(p)
	var colors: Array[Color]=[Color("#82502c"),Color("#c1d2db"),Color("#b5873c"),Color("#36291f")]
	for i in 4:
		builders[i].generate_normals()
		var material:=StandardMaterial3D.new()
		material.albedo_color=colors[i]
		material.roughness=0.28 if i==1 else (0.4 if i==2 else 0.85)
		material.metallic=0.65 if i in [1,2] else 0.0
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		builders[i].set_material(material)
		builders[i].commit(mesh)
	var error:=ResourceSaver.save(mesh,"res://assets/desert/weapons/cactus_spear.res",ResourceSaver.FLAG_COMPRESS)
	print("CACTUS_SPEAR_ASSET save=",error," vertices=",mesh.get_aabb())
	quit(0 if error==OK else 1)
func cylinder(st: SurfaceTool,x: float,length: float,radius: float) -> void:
	var part:=CylinderMesh.new()
	part.top_radius=radius
	part.bottom_radius=radius
	part.height=length
	part.radial_segments=8
	part.rings=1
	st.append_from(part,0,Transform3D(Basis(Vector3.FORWARD,PI*0.5),Vector3(x,0,0)))
