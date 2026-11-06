extends RefCounted
## Campanha por dono, com cópia local e sincronização monotônica. Sem recompensas online.
const SAVE_PATH := "user://desert_campaign_v1.cfg"
const TEMP_PATH := "user://desert_campaign_v1.cfg.tmp"
const VERSION := 1
const LAST_UPDATED_PHASE := 10
## Backup local Web contra falhas de sincronizacao do user:// no navegador.
## Não valida recompensas/achievements no GAME. Storage exclusivo da origem.
const WEB_BACKUP := "qse-v3:desert:campaign:v1"

static func completed_orders() -> Array[int]:
	var result: Array[int] = []
	for order in range(1,_highest_completed()+1): result.append(order)
	return result

static func highest_unlocked() -> int:
	return mini(_highest_completed()+1,10)

static func is_unlocked(order: int) -> bool:
	return order >= 1 and order <= 10 and order <= highest_unlocked()

static func is_completed(order: int) -> bool:
	return order >= 1 and order <= LAST_UPDATED_PHASE and order <= _highest_completed()

static func complete(order: int) -> Error:
	if order < 1 or order > LAST_UPDATED_PHASE: return ERR_INVALID_PARAMETER
	var previous := _highest_completed()
	if order > previous+1: return ERR_UNAUTHORIZED
	if order <= previous: return OK
	var owner:=OwnerStorage.owner_id()
	var result:=merge_highest(owner,order)
	var services:=PlayerServices.current
	if result==OK and services!=null and services.story_progress!=null and not owner.is_empty():
		services.story_progress.sync.call_deferred()
	return result

static func _path(owner: String) -> String:
	return SAVE_PATH if owner.is_empty() else OwnerStorage.path(owner,"desert_campaign_v2.cfg")

static func _backup_key(owner: String) -> String:
	return WEB_BACKUP if owner.is_empty() else WEB_BACKUP+":"+owner

static func merge_highest(owner: String,order: int) -> Error:
	if order<0 or order>10:return ERR_INVALID_PARAMETER
	var previous:=highest_for(owner)
	if order<=previous:return OK
	var path:=_path(owner)
	var config:=ConfigFile.new()
	config.load(path)
	config.set_value("campaign","version",VERSION)
	config.set_value("campaign","highest_completed",order)
	var error:=config.save(path+".tmp")
	if error==OK:error=DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if error!=OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".tmp"))
	return OK if _write_web_backup(order,owner) else error

static func adopt_guest(owner: String) -> Error:
	if owner.is_empty():return ERR_INVALID_PARAMETER
	var guest:=highest_for("")
	var config:=ConfigFile.new()
	config.load(SAVE_PATH)
	var claimed:=int(config.get_value("transfer","highest_claimed",0))
	if OS.has_feature("web"):
		var value: Variant=JavaScriptBridge.eval("(()=>{try{return Number(localStorage.getItem("+JSON.stringify(WEB_BACKUP+":claimed")+")||0);}catch(e){return 0;}})()")
		if value is float or value is int:claimed=maxi(claimed,int(value))
	if guest<=claimed:return OK
	var previous:=highest_for(owner)
	var result:=merge_highest(owner,guest)
	if result!=OK:return result
	if guest>previous:
		var carry:=carry_for(guest+1,"")
		if not carry.is_empty():store_carry(guest+1,carry,owner)
	_migrate_guest_lessons(owner)
	# A cópia original fica preservada. Um avanço já importado não contamina outra conta.
	config.set_value("transfer","highest_claimed",guest)
	config.save(SAVE_PATH)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem("+JSON.stringify(WEB_BACKUP+":claimed")+","+JSON.stringify(str(guest))+");}catch(e){}")
	return OK


static func _write_web_backup(order: int,owner:="") -> bool:
	if not OS.has_feature("web"): return false
	var success: Variant = JavaScriptBridge.eval("(function(){try{var k=" + JSON.stringify(_backup_key(owner)) + ";var n=Number(localStorage.getItem(k)||0);localStorage.setItem(k,String(Math.max(n," + str(order) + ")));return true;}catch(e){return false;}})()")
	return UIScale.js_true(success)


static func _highest_completed() -> int:
	return highest_for(OwnerStorage.owner_id())

static func highest_for(owner: String) -> int:
	var backup := _read_web_backup(owner)
	var config := ConfigFile.new()
	if config.load(_path(owner)) != OK: return backup
	if not config.has_section_key("campaign","version") or not config.has_section_key("campaign","highest_completed"): return backup
	var version: Variant = config.get_value("campaign","version")
	var highest: Variant = config.get_value("campaign","highest_completed")
	if typeof(version) != TYPE_INT or version != VERSION: return backup
	if typeof(highest) != TYPE_INT or highest < 0 or highest > LAST_UPDATED_PHASE: return backup
	return maxi(highest, backup)


static func _read_web_backup(owner:="") -> int:
	if not OS.has_feature("web"): return 0
	var value: Variant = JavaScriptBridge.eval("(function(){try{return Number(localStorage.getItem(" + JSON.stringify(_backup_key(owner)) + ")||0);}catch(e){return 0;}})()")
	if value == null or not (value is float or value is int): return 0
	return clampi(int(value), 0, LAST_UPDATED_PHASE)

static func store_carry(phase: int,charges: Dictionary,owner: String) -> Error:
	if phase<2 or phase>10:return ERR_INVALID_PARAMETER
	var clean:={}
	for key: String in ["attack","defense","amber","dash","rupture"]:
		clean[key]=clampi(int(charges.get(key,0)),0,3)
	var config:=ConfigFile.new()
	config.load(_path(owner))
	config.set_value("carry","phase",phase)
	config.set_value("carry","charges",clean)
	var result:=config.save(_path(owner))
	if OS.has_feature("web"):
		var payload:=JSON.stringify({"phase":phase,"charges":clean})
		var ok: Variant=JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+JSON.stringify(_backup_key(owner)+":carry")+","+JSON.stringify(payload)+");return true;}catch(e){return false;}})()")
		if UIScale.js_true(ok):return OK
	return result

static func carry_for(phase: int,owner: String) -> Dictionary:
	var config:=ConfigFile.new()
	config.load(_path(owner))
	var target:=int(config.get_value("carry","phase",0))
	var value: Variant=config.get_value("carry","charges",{})
	if OS.has_feature("web"):
		var raw: Variant=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+JSON.stringify(_backup_key(owner)+":carry")+")||'';}catch(e){return '';}})()")
		var backup: Variant=JSON.parse_string(raw) if raw is String and not raw.is_empty() else null
		if backup is Dictionary and int(backup.get("phase",0))==phase:
			target=phase
			value=backup.get("charges",{})
	if target!=phase or not value is Dictionary:return {}
	var clean:={}
	for key: String in ["attack","defense","amber","dash","rupture"]:
		if not value.get(key,0) is int and not value.get(key,0) is float:return {}
		clean[key]=clampi(int(value.get(key,0)),0,3)
	return clean

static func _migrate_guest_lessons(owner: String) -> void:
	var lessons:=ConfigFile.new()
	var path:="user://desert_first_use_v1.cfg"
	lessons.load(path)
	for key: String in ["attack","defense_spear_v1","task","amber","dash","rupture"]:
		var seen:=bool(lessons.get_value("guest",key,false))
		if OS.has_feature("web"):
			var guest_key:=JSON.stringify("qse-desert-first-use-v1:guest:"+key)
			seen=seen or UIScale.js_true(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+guest_key+")==='1';}catch(e){return false;}})()"))
		if seen:
			lessons.set_value(owner,key,true)
			if OS.has_feature("web"):
				JavaScriptBridge.eval("try{localStorage.setItem("+JSON.stringify("qse-desert-first-use-v1:"+owner+":"+key)+",'1');}catch(e){}")
	lessons.save(path)
