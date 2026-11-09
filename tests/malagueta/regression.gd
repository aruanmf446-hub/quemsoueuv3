extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var base:=preload("res://scripts/desert/t15d/phase.gd").new()
	var layout:=preload("res://scripts/desert/t15d/campaign_layout.gd")
	for order in range(1,10):
		assert(JSON.stringify(base._layout_for_phase(order))==JSON.stringify(layout.build(order)))
		var actor: Node3D=base._new_cactus_actor()
		assert(actor.get_script()==preload("res://scripts/desert/t15d/cactus.gd"))
		assert(actor._chase_direction(Vector3(-4,1,0))==-1)
		assert(actor._chase_direction(Vector3(0,1,0))==0)
		actor.free()
		print("PREVIOUS_PHASE_PASS ",order)
	base.free()
	print("REGRESSION_SUMMARY phases=9 failures=0")
	quit()
