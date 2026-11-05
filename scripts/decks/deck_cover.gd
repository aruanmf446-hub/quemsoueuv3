class_name DeckCover
extends RefCounted
## Capa individual dos decks (T24). Três modos: "auto" (o jogo escolhe a carta mais
## representativa), "card" (uma carta do deck) e "upload" (imagem própria, enquadrada).
## Se a fonte escolhida some (carta excluída, arquivo apagado), volta sozinho para "auto";
## sem nenhuma imagem, a Biblioteca desenha um monograma — nunca fica sem identificação.

## Proporção das capas nos cartões da Biblioteca.
const ASPECT := 16.0 / 10.0
## Retratos de personagem: o rosto costuma ficar no terço superior.
const PORTRAIT_FOCUS := Vector2(0.5, 0.34)

static var _scores := {}
static var _textures := {}
static var _versions := {}


## Chave de cache que muda quando o arquivo é substituído (prévia nova, capa nova). A data do
## arquivo tem resolução de segundos; `touch` (chamado por quem grava) cobre trocas rápidas.
static func stamp(path: String) -> String:
	if path.begins_with("res://"): return path
	return "%s@%d#%d" % [path, FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0, int(_versions.get(path, 0))]


static func touch(path: String) -> void:
	_versions[path] = int(_versions.get(path, 0)) + 1


static func exists(path: String) -> bool:
	if path.is_empty(): return false
	return ResourceLoader.exists(path, "Texture2D") if path.begins_with("res://") else FileAccess.file_exists(path)


static func load_texture(path: String) -> Texture2D:
	if path.begins_with("res://assets/duel/decks/community/") and path.get_file()!="cover.webp":
		var id := path.trim_prefix("res://assets/duel/decks/community/").trim_suffix(".webp")
		return preload("res://scripts/decks/repository_art.gd").texture(id)
	if not exists(path): return null
	var key := stamp(path)
	if not _textures.has(key):
		if path.begins_with("res://"): _textures[key] = load(path) as Texture2D
		else:
			var image := Image.load_from_file(path)
			_textures[key] = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	return _textures[key]


## Quão "representativa" é uma imagem: contraste e cor na área do rosto/torso.
## Calculado numa miniatura (48 px) e guardado por arquivo+data; barato e determinístico.
static func score(path: String) -> float:
	var key := stamp(path)
	if _scores.has(key): return _scores[key]
	var value := 0.0
	var texture := load_texture(path)
	var image: Image = texture.get_image() if texture != null else null
	if image != null and not image.is_empty():
		image = image.duplicate() as Image
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(48, maxi(8, roundi(48.0 * image.get_height() / image.get_width())), Image.INTERPOLATE_BILINEAR)
		var sum := 0.0
		var sum2 := 0.0
		var saturation := 0.0
		var count := 0
		var top := int(image.get_height() * 0.12)
		var bottom := int(image.get_height() * 0.7)
		for y in range(top, bottom):
			for x in range(int(image.get_width() * 0.15), int(image.get_width() * 0.85)):
				var color := image.get_pixel(x, y)
				var luma := color.get_luminance()
				sum += luma
				sum2 += luma * luma
				saturation += color.s
				count += 1
		if count > 0:
			var mean := sum / count
			var deviation := sqrt(maxf(sum2 / count - mean * mean, 0.0))
			# Nem escura demais nem estourada; contraste e cor contam mais.
			value = deviation * 2.0 + saturation / count * 0.6 + (1.0 - absf(mean - 0.42) * 1.6) * 0.4
	_scores[key] = value
	return value


## Índice da imagem mais representativa (empate: a primeira). -1 se nenhuma existir.
static func auto_pick(paths: Array) -> int:
	var best := -1
	var best_score := -INF
	for i in paths.size():
		var path := str(paths[i])
		if not exists(path): continue
		var value := score(path)
		if value > best_score + 0.0001:
			best = i
			best_score = value
	return best


## Ordem por representatividade (para escolher personagens do header).
static func ranked(paths: Array) -> Array[int]:
	var order: Array[int] = []
	for i in paths.size(): if exists(str(paths[i])): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa := score(str(paths[a]))
		var sb := score(str(paths[b]))
		return a < b if is_equal_approx(sa, sb) else sa > sb)
	return order


## Recorte proporcional (sem esticar) focado em `focus`; reaproveitado entre telas.
static func framed(path: String, aspect := ASPECT, focus := PORTRAIT_FOCUS, zoom := 1.0) -> Texture2D:
	var source := load_texture(path)
	if source == null: return null
	var key := "%s|%.3f|%.2f,%.2f|%.2f" % [stamp(path), aspect, focus.x, focus.y, zoom]
	if _textures.has(key): return _textures[key]
	var size := Vector2(source.get_size())
	var region_size := Vector2(size.x, size.x / aspect)
	if region_size.y > size.y: region_size = Vector2(size.y * aspect, size.y)
	region_size /= maxf(zoom, 1.0)
	var origin := (focus * size - region_size * 0.5).clamp(Vector2.ZERO, size - region_size)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(origin, region_size)
	_textures[key] = atlas
	return atlas


## Capa de um rascunho: {path, mode, card_id, focus}. path vazio = sem imagem (monograma).
static func resolve_draft(store: DeckDrafts, draft: Dictionary) -> Dictionary:
	var choice: Dictionary = draft.get("cover", {}) if draft.get("cover") is Dictionary else {}
	var id := str(draft.get("id", ""))
	var cards: Array = draft.get("cards", [])
	var mode := str(choice.get("mode", "auto"))
	if mode == "upload":
		var path := store.cover_path(id)
		if FileAccess.file_exists(path): return {"path": path, "mode": "upload", "card_id": "", "focus": Vector2(0.5, 0.5)}
	if mode == "card":
		for card: Dictionary in cards:
			if str(card.get("id", "")) == str(choice.get("card_id", "")):
				var chosen := store.preview_path(id, card)
				if FileAccess.file_exists(chosen): return {"path": chosen, "mode": "card", "card_id": str(card.id), "focus": PORTRAIT_FOCUS}
	var paths: Array = cards.map(func(card: Dictionary) -> String: return store.preview_path(id, card))
	var index := auto_pick(paths)
	if index < 0: return {"path": "", "mode": "auto", "card_id": "", "focus": PORTRAIT_FOCUS}
	return {"path": str(paths[index]), "mode": "auto", "card_id": str(cards[index].get("id", "")), "focus": PORTRAIT_FOCUS}


## Capa de um deck oficial/comunidade do catálogo local: "cover" do deck.json, senão automática.
static func resolve_item(item: Dictionary) -> String:
	var cards: Array = item.get("cards", [])
	var wanted := str(item.get("cover_card", ""))
	for card: Dictionary in cards:
		if not wanted.is_empty() and str(card.id).get_file() == wanted and exists(str(card.image)): return str(card.image)
	var paths: Array = cards.map(func(card: Dictionary) -> String: return str(card.get("image", "")))
	var index := auto_pick(paths)
	return str(paths[index]) if index >= 0 else ""
