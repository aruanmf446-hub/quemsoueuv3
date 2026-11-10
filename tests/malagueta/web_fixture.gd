extends Node
var phase: Node3D
var callback: JavaScriptObject
var inspect_motion := ""
var motion_label: Label
func _ready() -> void:
	UIScale.apply_device_profile(get_tree().root)
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	phase=load("res://scenes/desert/phase_10.tscn").instantiate()
	add_child(phase)
	phase._player._invulnerable=999
	phase.encounter.suspended=true
	var overlay:=CanvasLayer.new();overlay.layer=200;add_child(overlay)
	motion_label=Label.new();motion_label.position=Vector2(24,24);motion_label.add_theme_font_size_override("font_size",24);motion_label.hide();overlay.add_child(motion_label)
	callback=JavaScriptBridge.create_callback(_report)
	var window:=JavaScriptBridge.get_interface("window")
	window.bossProbe=callback
	window.bossReady=true
	_report([])
func _report(args: Array) -> void:
	if not args.is_empty() and str(args[0]).begins_with("motion:"):
		inspect_motion=str(args[0]).trim_prefix("motion:")
		phase.encounter.suspended=true
		phase._clear_chemicals()
		phase._boss.set_physics_process(false)
		phase._boss._model.set_rate(1.0)
		phase._boss._model.play_animation(inspect_motion,inspect_motion in ["base","carry","retreat","dizzy"],0.0)
		phase._boss._held.hide()
		phase._player.hide()
		phase._hud.hide()
		motion_label.text="PRÉVIA · "+str(phase._boss._model.MOTIONS.get(inspect_motion,inspect_motion))
		motion_label.show()
	elif not args.is_empty() and str(args[0])=="arena":
		inspect_motion=""
		phase._boss.set_physics_process(true)
		phase._player.show()
		phase._hud.show()
		motion_label.hide()
	if not args.is_empty() and str(args[0])=="phase3":
		phase.encounter.restore(2)
		phase.encounter.suspended=false
		phase._player.position=phase.files[2].global_position+Vector3.UP*0.1
		phase._player.velocity=Vector3.ZERO
	JavaScriptBridge.eval("window.bossReport="+JSON.stringify({"state":phase.encounter.state,"cacti":phase._troops.get_child_count(),"files":phase.files.size(),"phase":phase._order,"player":[phase._player.position.x,phase._player.position.y],"motion":inspect_motion,"clip":phase._boss._model.current_clip(),"camera":[phase._camera.position.x,phase._camera.position.y],"charges":[phase._player.attack_charges,phase._player.defense_charges]}),true)

func _process(_delta: float) -> void:
	# This isolated inspection fixture is invulnerable; avoid photographing the blink-off frame.
	# The production player and its damage/invulnerability visuals are unchanged.
	if is_instance_valid(phase) and is_instance_valid(phase._player): phase._player._model.visible=true
	if not inspect_motion.is_empty():
		phase._camera.size=4.2
		phase._camera.position=Vector3(phase._boss.position.x,phase._boss.position.y+1.05,24)
