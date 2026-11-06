extends Node
## Isolated Web export only; all account/deck calls use fixtures, never Supabase.
var services: PlayerServices
var ui: Control
var callback: JavaScriptObject
var fixture_mode := "deck"
var report_sequence := 0
func _ready() -> void:
	if OS.has_feature("web") and not OS.has_feature("iphone_layout_fixture"):
		push_error("Use only the isolated fixture export")
		return
	_run.call_deferred()
func _run() -> void:
	services=PlayerServices.new()
	add_child(services)
	await get_tree().process_frame
	var fake := preload("res://tests/community_t27/fake_game.gd").new()
	add_child(fake)
	var profile := preload("res://tests/nickname_onboarding/fake_profile_client.gd").new()
	add_child(profile)
	fake.user=profile.user_id
	fake.access_token="fixture-not-real"
	services.client=fake
	services.session.client=fake
	services.session.user={"id":profile.user_id,"user_metadata":{"name":"Nome do Gmail"}}
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	services.session.set_process(false)
	services.profile.client=profile
	services.profile.data=profile.profile()
	services.profile.state="success"
	var mode := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('fixture')||'nickname'")) if OS.has_feature("web") else fixture_mode
	if mode=="nickname":
		services.profile.state="loading"
		ui=preload("res://scripts/ui/nickname_onboarding.gd").new()
		ui.setup(services)
		add_child(ui)
		await get_tree().create_timer(0.35).timeout
		services.profile.state="success"
		services.profile.changed.emit()
	else:
		ui=load("res://scenes/player/deck_library.tscn").instantiate()
		add_child(ui)
		ui._create_deck()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.qseSetInternalScreen && window.qseSetInternalScreen(true)")
		callback=JavaScriptBridge.create_callback(_probe)
		JavaScriptBridge.get_interface("window").qseDeckInputProbe=callback
		await get_tree().create_timer(1.0).timeout
		_probe([])
		JavaScriptBridge.eval("window.qseDeckInputReady=true")
func _probe(args: Array) -> void:
	if args.size() and str(args[0]).begins_with("focus:"):
		var target := ui.find_child(str(args[0]).trim_prefix("focus:"),true,false) as Control
		var scroll := ui.get_node_or_null("Margin/Column/Scroll") as ScrollContainer
		if target!=null and scroll!=null and scroll.is_ancestor_of(target): scroll.ensure_control_visible(target)
	if args.size() and str(args[0])=="bottom":
		var scroll: ScrollContainer=ui.get_node("Margin/Column/Scroll")
		scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	report_sequence+=1
	var result := {"sequence":report_sequence,"size":[ui.size.x,ui.size.y],"controls":[],"fields":{},"cards":0,"labels":[]}
	for node: Control in ui.find_children("*","Control",true,false):
		if not node.is_visible_in_tree(): continue
		if node is Label: result.labels.append(node.text)
		if node is LineEdit or node is TextEdit: result.fields[str(node.name)]=str(node.text)
		if node is BaseButton or node is LineEdit or node is TextEdit:
			var r := node.get_global_rect()
			result.controls.append({"name":str(node.name),"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
	if ui.get("_draft") is Dictionary:
		result.cards=ui._draft.get("cards",[]).size()
		result.card_names=ui._draft.get("cards",[]).map(func(c:Dictionary)->String:return str(c.get("name","")))
		result.description=str(ui._draft.get("description",""))
		result.name=str(ui._draft.get("name",""))
		result.category=str(ui._draft.get("category",""))
		result.cover=ui._draft.get("cover",{})
	JavaScriptBridge.eval("window.qseDeckInputReport="+JSON.stringify(result))
