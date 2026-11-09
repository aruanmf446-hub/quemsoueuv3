extends Node
var phase: Node3D
var callback: JavaScriptObject
func _ready() -> void:
	UIScale.apply_device_profile(get_tree().root)
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	phase=load("res://scenes/desert/phase_10.tscn").instantiate()
	add_child(phase)
	phase._player._invulnerable=999
	phase.encounter.suspended=true
	callback=JavaScriptBridge.create_callback(_report)
	var window:=JavaScriptBridge.get_interface("window")
	window.bossProbe=callback
	window.bossReady=true
	_report([])
func _report(args: Array) -> void:
	if not args.is_empty() and str(args[0])=="phase3":
		phase.encounter.restore(2)
		phase.encounter.suspended=false
		phase._player.position=phase.files[2].global_position+Vector3.UP*0.1
		phase._player.velocity=Vector3.ZERO
	JavaScriptBridge.eval("window.bossReport="+JSON.stringify({"state":phase.encounter.state,"cacti":phase._troops.get_child_count(),"files":phase.files.size(),"phase":phase._order,"player":[phase._player.position.x,phase._player.position.y],"camera":[phase._camera.position.x,phase._camera.position.y],"charges":[phase._player.attack_charges,phase._player.defense_charges]}),true)

func _process(_delta: float) -> void:
	# This isolated inspection fixture is invulnerable; avoid photographing the blink-off frame.
	# The production player and its damage/invulnerability visuals are unchanged.
	if is_instance_valid(phase) and is_instance_valid(phase._player): phase._player._model.visible=true
