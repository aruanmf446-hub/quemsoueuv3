class_name FeaturedPicker
extends RefCounted
## Destaques da Biblioteca (T24). Prioridade:
##   1. Deck oficial fixado pela administração ("pin")
##   2. Evento sazonal ativo ("campaign": por deck ou por temática, com início e fim)
##   3. Populares (score real > 0 de qse_deck_stats)
##   4. Lançamentos (published_at real nos últimos RECENT_DAYS)
##   5. Deck oficial padrão
## Sem dado real, o critério é pulado. As regras vêm do CATALOG (qse_catalog_featured),
## editáveis sem mudar o código. Rascunhos privados nunca são destacados.

const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
const MAX_SLIDES := 5
const RECENT_DAYS := 45
const LABELS := {"pin": "Destaque oficial", "campaign": "Evento", "popular": "Em alta", "recent": "Lançamento", "default": "Coleção oficial"}


## Uma regra válida e ativa em `now` (segundos Unix). Datas inválidas invalidam a regra.
static func active(rule: Dictionary, now: float) -> bool:
	if rule.get("active", true) == false: return false
	if not str(rule.get("kind", "")) in ["pin", "campaign"]: return false
	var starts := str(rule.get("starts_at", "")) if rule.get("starts_at") != null else ""
	var ends := str(rule.get("ends_at", "")) if rule.get("ends_at") != null else ""
	if not starts.is_empty():
		var start := PlayerContracts.iso_seconds(starts)
		if start <= 0.0 or now < start: return false
	if not ends.is_empty():
		var finish := PlayerContracts.iso_seconds(ends)
		if finish <= 0.0 or now >= finish: return false
	return true


static func _matches_theme(entry: Dictionary, theme: String) -> bool:
	var key := Catalog.search_key(theme)
	if key.is_empty(): return false
	var fields: Array = [str(entry.get("category", ""))]
	fields.append_array(entry.get("tags", []))
	for field: Variant in fields:
		if Catalog.search_key(str(field)) == key: return true
	return false


static func pick(entries: Array, rules: Array, stats: Dictionary, now: float) -> Array[Dictionary]:
	var pool: Array = entries.filter(func(e: Dictionary) -> bool: return str(e.get("origin", "")) != "mine")
	var by_ref := {}
	for entry: Dictionary in pool: by_ref[str(entry.get("ref", ""))] = entry
	var slides: Array[Dictionary] = []
	var used := {}
	var add := func(entry: Dictionary, reason: String, label: String) -> void:
		var ref := str(entry.get("ref", entry.get("id", "")))
		if used.has(ref) or slides.size() >= MAX_SLIDES: return
		used[ref] = true
		slides.append({"entry": entry, "reason": reason, "label": label if not label.is_empty() else LABELS[reason]})
	var live: Array = rules.filter(func(r: Variant) -> bool: return r is Dictionary and active(r, now))
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	for kind: String in ["pin", "campaign"]:
		for rule: Dictionary in live:
			if str(rule.kind) != kind: continue
			var label := str(rule.get("title", "")).strip_edges().left(40)
			var ref := str(rule.get("deck_ref", ""))
			if by_ref.has(ref):
				# Fixar é só para decks oficiais.
				if kind == "pin" and str(by_ref[ref].origin) != "official": continue
				add.call(by_ref[ref], kind, label)
			elif kind == "campaign" and rule.get("theme") is String:
				for entry: Dictionary in pool:
					if _matches_theme(entry, str(rule.theme)): add.call(entry, kind, label)
	var popular: Array = pool.filter(func(e: Dictionary) -> bool: return _score(e, stats) > 0.0)
	popular.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _score(a, stats) > _score(b, stats))
	for entry: Dictionary in popular.slice(0, 2): add.call(entry, "popular", "")
	var recent: Array = pool.filter(func(e: Dictionary) -> bool:
		var when := float(e.get("published", 0.0))
		return when > 0.0 and when <= now and now - when <= RECENT_DAYS * 86400.0)
	recent.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.published) > float(b.published))
	for entry: Dictionary in recent.slice(0, 2): add.call(entry, "recent", "")
	if slides.is_empty():
		for entry: Dictionary in pool:
			if str(entry.get("origin", "")) == "official":
				add.call(entry, "default", "")
				break
	return slides


static func _score(entry: Dictionary, stats: Dictionary) -> float:
	return float(stats.get(str(entry.get("ref", "")), {}).get("score", entry.get("score", 0.0)))
