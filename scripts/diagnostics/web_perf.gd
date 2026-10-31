class_name WebPerf
extends Node
## Explicit opt-in diagnostics. Numeric timings and known UI states only; never session data.
static var enabled := false
static var events: Array = []
static func measure(label: String, started: int) -> void:
	if enabled:
		events.append({"label":label,"ms":(Time.get_ticks_usec()-started)/1000.0})
		if events.size()>600: events.pop_front()
func _ready() -> void:
	if OS.has_feature("web"):
		var requested: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('t19probe')",true)
		enabled = str(requested)=="1"
	set_process(enabled)
var elapsed := 0.0
var worst_frame := 0.0
func _process(delta: float) -> void:
	if not enabled: return
	worst_frame=maxf(worst_frame,delta*1000)
	elapsed+=delta
	if elapsed<0.2: return
	elapsed=0
	var menu:=get_tree().current_scene
	if menu==null or menu.name!="MainMenu": return
	var nav: NavigationManager=menu.get_node("Navigation")
	var widgets: Dictionary={}
	var settings_button: Control=menu.get_node("MenuButtons/BtnSettings")
	widgets.settings=_rect(settings_button)
	var active: PlayerScreen=nav.get("_active")
	var route: String=str(nav.get("_history").back().route) if not nav.get("_history").is_empty() else ""
	if active!=null:
		widgets.back=_rect(active.get_node("Margin/Column/Header/Back"))
		if route=="settings":
			for index in range(active.get("_tabs").size()): widgets["tab"+str(index)]=_rect(active.get("_tabs")[index])
	var player: Node=get_node("/root/MenuMusic")
	var state := {"route":route,"busy":nav.get("_busy"),"widgets":widgets,
		"worst_frame_ms":worst_frame,"events":events,"memory_bytes":OS.get_static_memory_usage(),
		"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"authenticated":menu.get_node("Services").session.authenticated(),
		"audio_playing":player.get("_players")[player.get("_active")].playing,"audio_loading":not str(player.get("_web_loading")).is_empty(),
		"audio_cache_count":player.get("_web_cache").size(),"audio_type":player.get("_players")[player.get("_active")].playback_type,"paused":player.get("paused"),"category":active.get("_category") if active!=null and route=="settings" else -1,
		"lobby_update":menu.get_node("LobbyArea/Stage/Viewport").render_target_update_mode}
	JavaScriptBridge.eval("window.QSE_PERF="+JSON.stringify(state),true)
func _rect(control: Control) -> Dictionary:
	if not control.is_visible_in_tree(): return {}
	var rect:=get_viewport().get_final_transform()*control.get_global_rect()
	return {"x":rect.get_center().x,"y":rect.get_center().y,"w":rect.size.x,"h":rect.size.y}
