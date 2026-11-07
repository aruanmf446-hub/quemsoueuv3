extends RefCounted
## Partida em andamento por dono. Cópia local imediata; nuvem por revisão, sem somar cargas.
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
const VERSION:=1
const KEYS:=["attack","defense","amber","dash","rupture"]
const WEB_KEY:="qse-v3:story-run:v1:"
static func fresh(order: int,charges: Dictionary={}) -> Dictionary:
	var stage:=Layout.build(order)
	var inventory: Dictionary={}
	for key: String in KEYS:inventory[key]=clampi(int(charges.get(key,0 if order==1 or key not in ["attack","defense"] else 1)),0,3)
	return {"schema_version":VERSION,"run_id":PlayerContracts.uuid(),"change_id":PlayerContracts.uuid(),"phase":order,"checkpoint":-1,"position":[stage.player_spawn[0],stage.player_spawn[1]],"health":3,"charges":inventory,"defeated":[],"collected":[],"tasks":[],"task_steps":{},"elapsed":0.0,"lessons":[],"checkpoint_state":{"defeated":[],"collected":[],"tasks":[],"task_steps":{}},"boss_defeated":false,"boss_health":20}
static func valid(state: Variant) -> bool:
	if not state is Dictionary or state.get("schema_version")!=VERSION:return false
	for key: String in ["phase","checkpoint","health","elapsed","boss_health"]:
		if not state.get(key) is float and not state.get(key) is int:return false
		if not is_finite(float(state[key])):return false
		if key!="elapsed" and float(state[key])!=floorf(float(state[key])):return false
	if int(state.phase)<1 or int(state.phase)>10 or int(state.checkpoint)<-1 or int(state.checkpoint)>6 or int(state.health)<1 or int(state.health)>3 or float(state.elapsed)<0 or float(state.elapsed)>10000000:return false
	if not state.get("position") is Array or state.position.size()!=2:return false
	for value: Variant in state.position:
		if not (value is float or value is int) or not is_finite(float(value)):return false
	if float(state.position[0])< -32 or float(state.position[0])>1500 or float(state.position[1])< -16 or float(state.position[1])>64:return false
	if not state.get("charges") is Dictionary or state.charges.size()!=5:return false
	for key: String in KEYS:
		var value: Variant=state.charges.get(key)
		if not (value is float or value is int) or float(value)!=floorf(float(value)) or int(value)<0 or int(value)>3:return false
	for key: String in ["run_id","change_id"]:
		if not state.get(key) is String or RegEx.create_from_string("^[0-9a-f-]{36}$").search(state[key])==null:return false
	for key: String in ["defeated","collected","tasks","lessons"]:
		if not _ids(state.get(key)):return false
	if not state.get("checkpoint_state") is Dictionary:return false
	for key: String in ["defeated","collected","tasks"]:
		if not _ids(state.checkpoint_state.get(key)):return false
	for source: Dictionary in [state,state.checkpoint_state]:
		if not source.get("task_steps") is Dictionary or source.task_steps.size()>2:return false
		for value: Variant in source.task_steps.values():
			if not (value is float or value is int) or float(value)!=floorf(float(value)) or int(value)<0 or int(value)>2:return false
	return state.get("boss_defeated") is bool and int(state.boss_health)>=0 and int(state.boss_health)<=20 and JSON.stringify(state).length()<=65536
static func _ids(values: Variant) -> bool:
	if not values is Array or values.size()>512:return false
	for value: Variant in values:
		if not value is String or value.length()>96:return false
	return true
static func read(owner: String) -> Dictionary:
	var config:=ConfigFile.new()
	config.load(OwnerStorage.path(owner,"story_run_v1.cfg"))
	var data: Variant=config.get_value("run","record",{})
	if OS.has_feature("web"):
		var raw: Variant=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+JSON.stringify(WEB_KEY+owner)+")||'';}catch(e){return '';}})()")
		if raw is String and not raw.is_empty():
			var backup: Variant=JSON.parse_string(raw)
			if backup is Dictionary and valid(backup.get("state")) and (not data is Dictionary or int(backup.get("local_version",0))>=int(data.get("local_version",0))):data=backup
	if not data is Dictionary or not valid(data.get("state")):return {"state":{},"revision":0,"pending":false,"intent":"save"}
	return data
static func _write(owner: String,data: Dictionary) -> Error:
	var path:=OwnerStorage.path(owner,"story_run_v1.cfg")
	var config:=ConfigFile.new()
	config.load(path)
	var previous: Variant=config.get_value("run","record",{})
	data.local_version=maxi(int(data.get("local_version",0)),int(previous.get("local_version",0)) if previous is Dictionary else 0)+1
	config.set_value("run","record",data)
	var result:=config.save(path+".tmp")
	if result==OK:result=DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if OS.has_feature("web"):
		var ok: Variant=JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+JSON.stringify(WEB_KEY+owner)+","+JSON.stringify(JSON.stringify(data))+");return true;}catch(e){return false;}})()")
		if UIScale.js_true(ok):return OK
	return result
static func save(owner: String,state: Dictionary,intent:="save") -> Error:
	if not valid(state):return ERR_INVALID_DATA
	var data:=read(owner)
	data.state=state.duplicate(true)
	data.state.change_id=PlayerContracts.uuid()
	data.pending=true
	if intent=="start":data.intent="start"
	return _write(owner,data)
static func accept(owner: String,response: Dictionary,sent: Dictionary) -> void:
	if response.get("schema_version")!=1 or not valid(response.get("state")):return
	var current:=read(owner)
	var newer: bool=not current.state.is_empty() and current.state.get("change_id")!=sent.get("change_id")
	var acknowledged: bool=bool(response.get("applied",response.state.change_id==sent.get("change_id")))
	var unchanged: bool=int(response.revision)==int(current.revision)
	# Uma edição local durante a requisição não pode ressuscitar um inventário
	# rejeitado por revisão antiga nem recuar o avanço feito em outro aparelho.
	var follows_ack: bool=(acknowledged or unchanged) and (current.state.get("run_id")==response.state.run_id or response.state.run_id==sent.get("run_id"))
	var keep_newer: bool=newer and (follows_ack or farther(current.state,response.state))
	current.revision=int(response.revision)
	if keep_newer:
		current.pending=true
		if current.state.get("run_id")==response.state.run_id:current.intent="save"
	else:
		current.state=response.state.duplicate(true)
		current.pending=false
		current.intent="save"
	_write(owner,current)
static func farther(a: Dictionary,b: Dictionary) -> bool:
	if b.is_empty():return not a.is_empty()
	if a.is_empty():return false
	for key: String in ["phase","checkpoint"]:
		if int(a[key])!=int(b[key]):return int(a[key])>int(b[key])
	return float(a.position[0])>float(b.position[0])+0.1
static func adopt_guest(owner: String) -> void:
	if owner.is_empty():return
	var guest:=read("")
	if guest.state.is_empty():return
	var marker:=ConfigFile.new()
	var path:=OwnerStorage.path("","story_run_claimed.cfg")
	marker.load(path)
	var claimed:=str(marker.get_value("transfer","change_id",""))
	if OS.has_feature("web"):
		var raw: Variant=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('qse-v3:story-run-claimed')||'';}catch(e){return '';}})()")
		if raw is String and not raw.is_empty():claimed=raw
	if claimed==guest.state.change_id:return
	if farther(guest.state,read(owner).state):save(owner,guest.state)
	marker.set_value("transfer","change_id",guest.state.change_id)
	marker.save(path)
	if OS.has_feature("web"):JavaScriptBridge.eval("try{localStorage.setItem('qse-v3:story-run-claimed',"+JSON.stringify(guest.state.change_id)+");}catch(e){}")
