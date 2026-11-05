extends SceneTree
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var phase: Node3D=load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	var checks:=0
	var failures:=0
	for route: Dictionary in phase._phase.platforms:
		if not route.get("parkour_route",false):continue
		phase._stream_world(float(route.pos[0]),true)
		for i in 3:await physics_frame
		for offset in [-2.6,-1.8,-0.7,0.0,0.7,1.8,2.6]:
			var x:=float(route.pos[0])+float(offset)
			var base:=float(route.surface_top)
			var hit:=phase.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,base+3,0),Vector3(x,base+0.1,0),1))
			var expected:=base+Layout.roof_height(float(offset),float(route.size[0]))
			checks+=1
			if hit.is_empty() or absf(float(hit.position.y)-expected)>0.02:
				failures+=1
				print("FAIL roof collision x=",x," expected=",expected," hit=",hit)
	phase.free()
	for i in 3:await physics_frame
	print("ROOF_SURFACE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
