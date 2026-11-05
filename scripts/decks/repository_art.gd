extends RefCounted
## Recursos aprovados no manifesto do repositório; sem download ou imagem provisória.
const ROOT := "res://assets/duel/decks/community"
const MANIFEST := "res://data/community/approved_decks.json"
static var _textures := {}
static func approved_ids() -> Array[String]:
	var result: Array[String]=[]
	for row: Variant in PlayerContracts.read_json(MANIFEST).get("decks",[]):
		if not row is Dictionary: continue
		var id := str(row.get("id",""))
		if RegEx.create_from_string("^repo_[a-f0-9]{24}$").search(id)!=null and not result.has(id): result.append(id)
	return result
static func is_card(id: String) -> bool:
	return RegEx.create_from_string("^repo_[a-f0-9]{24}/card_[0-9]{2}$").search(id)!=null and approved_ids().has(id.get_slice("/",0))
static func definition(id: String) -> Dictionary:
	if not is_card(id): return {}
	var info := PlayerContracts.read_json(ROOT+"/"+id.get_slice("/",0)+"/deck.json")
	var row: Variant=info.get("cards",{}).get(id.get_slice("/",1),{})
	return row if row is Dictionary else {}
static func texture(id: String,format := "library") -> Texture2D:
	if not is_card(id): return null
	var key := id+":"+format
	if _textures.has(key): return _textures[key]
	var path := ROOT+"/"+id+".webp"
	if not ResourceLoader.exists(path): return null
	var source := load(path) as Texture2D
	if source==null: return null
	var image := source.get_image()
	if image==null: return null
	if image.is_compressed() and image.decompress()!=OK: return null
	var row := definition(id)
	var aspect := CardFramer.DUEL_ASPECT if format=="duel" else CardFramer.LIBRARY_ASPECT
	var preview := CardFramer.preview(image,aspect,row.get("crops",{}).get(format,{}),720 if format=="library" else 960)
	var value := ImageTexture.create_from_image(preview)
	if _textures.size()>=48: _textures.erase(_textures.keys()[0])
	_textures[key]=value
	return value
