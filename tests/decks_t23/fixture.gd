extends RefCounted
## FIXTURE DE TESTE (T23): decks de demonstração com os títulos das referências.
## Só entra em _demo_entries de testes/capturas; nunca aparece no jogo distribuído.
const ART := "res://assets/duel/decks/lendas_urbanas/%s.png"


static func entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var rows := [
		["Heróis Clássicos", "Comunidade", "Heróis", 24, "slender_man"],
		["Mitologia Grega", "Comunidade", "Mitologia", 18, "dama_de_branco"],
		["Monstros do Folclore", "Comunidade", "Folclore", 20, "cobra_grande"],
		["Vilões do Cinema", "Comunidade", "Cinema", 16, "homem_sorridente"],
		["Ícones do Terror", "Comunidade", "Terror", 12, "momo"],
	]
	for i in rows.size():
		var row: Array = rows[i]
		list.append({"id": "demo:%d" % i, "name": "[DEMO] " + str(row[0]), "origin": "community", "creator": str(row[1]),
			"category": str(row[2]), "count": int(row[3]), "cover": ART % row[4], "item": {}, "demo": true})
	return list
