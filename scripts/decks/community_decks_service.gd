class_name CommunityDecksService
extends Node
## Entitlements belong to GAME. Only signed CATALOG preview URLs leave the gateway.
signal changed
const PATH := "/functions/v1/qse-deck-catalog"
const SIGNED_ROOT := "https://bsxicvlngphazesuzaee.supabase.co/storage/v1/object/sign/qse-community-previews/"
static var cards: Dictionary = {}
static var _textures: Dictionary = {}
var owned: Array[Dictionary] = []
var _owner := ""
var _known: Dictionary = {}
var _claiming := false
var _confirmed: Dictionary = {}
var _generation := 0
var _inventory_request := 0

func clear() -> void:
	_generation+=1
	_inventory_request+=1
	_owner=""
	owned.clear()
	_known.clear()
	cards.clear()
	_textures.clear()
	_claiming=false
	_confirmed.clear()

func _services() -> PlayerServices: return PlayerServices.current
func _account() -> String:
	var services := _services()
	return str(services.session.user.get("id","")) if services!=null and services.session.authenticated() else ""

static func is_ref(value: String) -> bool:
	return RegEx.create_from_string("^community_[0-9a-f]{32}$").search(value)!=null

static func valid_manifest(value: Variant) -> bool:
	if not value is Dictionary or not is_ref(str(value.get("id",""))) or not CreatorSync.is_uuid(str(value.get("deck_id",""))) or not CreatorSync.is_uuid(str(value.get("version_id",""))): return false
	if value.id!="community_"+str(value.version_id).replace("-","") or not value.get("name") is String or not value.get("cards") is Array: return false
	if value.cards.size()<5 or value.cards.size()>30: return false
	var seen := {}
	for card: Variant in value.cards:
		if not card is Dictionary or not card.get("name") is String: return false
		var id := str(card.get("id",""))
		if id.get_slice("/",0)!=value.id or id.get_slice_count("/")!=2 or not CreatorSync.is_uuid(id.get_slice("/",1)) or seen.has(id): return false
		seen[id]=true
		for format in ["library","duel"]:
			if str(card.get(format+"_path",""))!=str(value.version_id)+"/"+id.get_slice("/",1)+"_"+format+".png": return false
	return true

func _adopt_owner() -> void:
	var owner := _account()
	if owner==_owner: return
	clear()
	_owner=owner
	if owner.is_empty(): return
	var path := OwnerStorage.path(OwnerStorage.safe(owner),"community/inventory.json")
	if not FileAccess.file_exists(path): return
	var cached: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if cached is Dictionary and cached.get("owner")==owner and cached.get("items") is Array:
		_apply_inventory(cached.items)

func _register(manifest: Dictionary) -> void:
	_known[str(manifest.id)]=manifest
	for card: Dictionary in manifest.cards:
		var paths := {"name":str(card.name)}
		for format in ["library","duel"]: paths[format]=_image_path(str(card.id),format)
		cards[str(card.id)]=paths

func _apply_inventory(items: Array) -> bool:
	for item: Variant in items:
		if not valid_manifest(item) or not item.get("available") is bool: return false
	owned.assign(items)
	for item: Dictionary in owned: _register(item)
	changed.emit()
	return true

func refresh() -> Dictionary:
	_adopt_owner()
	_inventory_request+=1
	var request_id := _inventory_request
	if _owner.is_empty(): return ServiceResult.failure("not_authenticated")
	var epoch := _generation
	var result := await _services().client.call_rpc("qse_community_inventory")
	if epoch!=_generation or _account()!=_owner: return ServiceResult.failure("session_changed")
	if request_id!=_inventory_request: return ServiceResult.failure("superseded")
	if not result.ok: return result
	if not result.data is Dictionary or not result.data.get("items") is Array or not _apply_inventory(result.data.items): return ServiceResult.failure("invalid_contract")
	var file := FileAccess.open(OwnerStorage.path(OwnerStorage.safe(_owner),"community/inventory.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify({"owner":_owner,"items":owned}))
	return result

func is_claimed(deck_id: String) -> bool:
	_adopt_owner()
	return _confirmed.has(deck_id) or owned.any(func(item:Dictionary)->bool:return str(item.deck_id)==deck_id)

func playable() -> Array:
	_adopt_owner()
	return owned.filter(func(item:Dictionary)->bool:return bool(item.available))

func _gateway(body: Dictionary) -> Dictionary:
	_adopt_owner()
	if _owner.is_empty(): return ServiceResult.failure("not_authenticated")
	var epoch := _generation
	var response := await _services().client.send(PATH,HTTPClient.METHOD_POST,body,PackedStringArray(),PackedByteArray(),"application/json",120.0)
	if epoch!=_generation or _account()!=_owner: return ServiceResult.failure("session_changed")
	if not response.ok: return response
	var data: Variant=response.data.get("data") if response.data is Dictionary else null
	if not data is Dictionary: return ServiceResult.failure("invalid_contract")
	if data.has("error"): return ServiceResult.failure(str(data.error))
	return ServiceResult.success(data)

func claim(deck_id: String) -> Dictionary:
	_adopt_owner()
	var epoch := _generation
	if _claiming: return ServiceResult.failure("busy")
	if not CreatorSync.is_uuid(deck_id): return ServiceResult.failure("invalid_contract")
	_claiming=true
	var result := await _gateway({"action":"claim","deck_id":deck_id})
	if epoch!=_generation: return ServiceResult.failure("session_changed")
	_claiming=false
	if not result.ok: return result
	if result.data.get("claimed")!=true or result.data.get("deck_id")!=deck_id or not is_ref(str(result.data.get("deck_ref",""))): return ServiceResult.failure("invalid_contract")
	_inventory_request+=1
	_confirmed[deck_id]=true
	# Ownership is already committed. A failed refresh must not erase that fact.
	var inventory_result := await refresh()
	if epoch!=_generation: return ServiceResult.failure("session_changed")
	result.data.inventory_refreshed=inventory_result.ok
	if inventory_result.ok:
		await ensure_ready([str(result.data.deck_ref)],["library"],true)
		if epoch!=_generation: return ServiceResult.failure("session_changed")
	return result

func _image_path(id: String,format: String) -> String:
	return OwnerStorage.path(OwnerStorage.safe(_owner),"community/assets/"+id.sha256_text()+"_"+format+".png")

func _download(url: String,path: String) -> bool:
	var epoch := _generation
	var http := HTTPRequest.new()
	http.accept_gzip=not OS.has_feature("web")
	http.timeout=30.0
	http.body_size_limit=4*1024*1024
	add_child(http)
	if http.request(url)!=OK:
		http.queue_free()
		return false
	var response: Array=await http.request_completed
	http.queue_free()
	if epoch!=_generation or _account()!=_owner or response[0]!=HTTPRequest.RESULT_SUCCESS or int(response[1])!=200: return false
	var bytes: PackedByteArray=response[3]
	var image := Image.new()
	if image.load_png_from_buffer(bytes)!=OK or image.get_width()>2048 or image.get_height()>2048: return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_buffer(bytes)
	return true

func ensure_ready(refs: Array,formats: Array=["duel"],cover_only:=false) -> Dictionary:
	_adopt_owner()
	var required: Array=[]
	for ref: Variant in refs:
		if ref is String and is_ref(ref) and not required.has(ref): required.append(ref)
	if required.is_empty(): return ServiceResult.success({})
	if required.size()>5 or _owner.is_empty(): return ServiceResult.failure("not_authenticated")
	var missing := false
	for ref: String in required:
		if not _known.has(ref):
			missing=true
			continue
		for card: Dictionary in (_known[ref].cards.slice(0,1) if cover_only else _known[ref].cards):
			for format: String in formats:
				if not FileAccess.file_exists(_image_path(str(card.id),format)): missing=true
	if not missing: return ServiceResult.success({})
	var epoch := _generation
	var result := await _gateway({"action":"manifests","deck_refs":required})
	if not result.ok: return result
	if not result.data.get("items") is Array or result.data.items.size()!=required.size(): return ServiceResult.failure("invalid_contract")
	for item: Variant in result.data.items:
		if not valid_manifest(item) or not required.has(item.id): return ServiceResult.failure("invalid_contract")
		_register(item)
		for card: Dictionary in (item.cards.slice(0,1) if cover_only else item.cards):
			for format: String in formats:
				var path := _image_path(str(card.id),format)
				if FileAccess.file_exists(path): continue
				var url := str(card.get(format+"_url",""))
				if not url.begins_with(SIGNED_ROOT+str(card[format+"_path"])+"?token="): return ServiceResult.failure("invalid_contract")
				if not await _download(url,path): return ServiceResult.failure("preview_unavailable")
				if epoch!=_generation: return ServiceResult.failure("session_changed")
	return ServiceResult.success({})

func local_entries() -> Array:
	var result: Array=[]
	for item: Dictionary in playable():
		result.append({"id":str(item.id),"name":str(item.name),"cards":item.cards.map(func(card:Dictionary)->String:return str(card.id)),"community":true})
	return result

static func texture(id: String,format: String="duel") -> Texture2D:
	var key := id+":"+format
	if _textures.has(key): return _textures[key]
	var path := str(cards.get(id,{}).get(format,""))
	if path.is_empty() or not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	if image==null or image.is_empty(): return null
	_textures[key]=ImageTexture.create_from_image(image)
	return _textures[key]

func library_entries() -> Array[Dictionary]:
	_adopt_owner()
	var result: Array[Dictionary]=[]
	for item: Dictionary in owned:
		var images: Array=item.cards.map(func(card:Dictionary)->String:return _image_path(str(card.id),"library"))
		result.append({"id":str(item.deck_id),"name":str(item.name),"origin":"community","community":true,"owned":true,"owned_ref":str(item.id),"creator":str(item.creator),"category":str(item.category),"count":item.cards.size(),"tags":[],"cover":images[0] if FileAccess.file_exists(images[0]) else "","images":images,"focus":DeckCover.PORTRAIT_FOCUS,"ref":"creator:"+str(item.deck_id)})
	return result

func open_owned(ref: String) -> Dictionary:
	var result := await ensure_ready([ref],["library","duel"])
	if not result.ok: return result
	var item: Dictionary=_known.get(ref,{})
	if item.is_empty(): return ServiceResult.failure("deck_unavailable")
	var list: Array[Dictionary]=[]
	for card: Dictionary in item.cards:
		list.append({"id":str(card.id),"name":str(card.name),"description":str(card.get("description","")),"image":_image_path(str(card.id),"library")})
	return ServiceResult.success({"id":str(item.deck_id),"name":str(item.name),"creator":str(item.creator),"category":str(item.category),"description":str(item.description),"official":false,"community":true,"tags":[],"age_rating":"","content_warnings":[],"visibility":"public","origin":"community","cards":list,"count":list.size()})


func source_deck_id(ref: String) -> String:
	return str(_known.get(ref,{}).get("deck_id",""))

func cover_image(ref: String) -> String:
	var list: Array=_known.get(ref,{}).get("cards",[])
	if list.is_empty(): return ""
	var path := _image_path(str(list[0].id),"library")
	return path if FileAccess.file_exists(path) else ""
