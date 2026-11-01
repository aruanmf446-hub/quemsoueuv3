extends RefCounted
## FIXTURE DE TESTE (T22): jogadores ilustrativos das referências aprovadas.
## Só para capturas e testes locais; nunca gravados no Supabase nem usados no jogo.

static func player(nickname: String, character: String, index: int) -> Dictionary:
	return {"user_id": "00000000-0000-4000-8000-%012d" % index, "public_id": "QSE-%08x" % (index * 2654435761 % 4294967296),
		"nickname": nickname, "equipped_character_id": character, "level": 3 + index % 7}


static func data() -> Dictionary:
	return {
		"friends": [player("LunaPlayer", "lana", 1), player("CaioQuest", "halloween", 2), player("BiaZeta", "lorena", 3), player("RafaNexus", "rodrigo", 4), player("GiCosta", "michelly", 5)],
		"incoming": [player("Misteriosa03", "michelly", 11), player("EnigmaBR", "halloween", 12), player("AstroPlayer", "gus", 13)],
		"outgoing": [player("QuizMaster", "rodrigo", 21), player("SabioDoJogo", "cowboy", 22)],
	}


static func search_results() -> Array:
	return [player("LunaBR", "lana", 31), player("LunaPlayer", "lana", 1), player("LunaQuest", "halloween", 32), player("LunaStar", "lorena", 33)]


## Sessão aparente sem rede: não emite session.changed (que buscaria dados reais).
static func apply(services: PlayerServices) -> void:
	services.session.user = {"id": "00000000-0000-4000-8000-000000000999", "email": "fixture@example.invalid"}
	services.session.client.access_token = "fixture-token-sem-rede"
	services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
	services.friends.data = data()
	services.friends.state = "success"
	for item: Dictionary in services.friends.data.friends:
		services.friends.presence_known[item.user_id] = true
	for id in [1, 2, 3]: services.friends.online_ids[player("", "", id).user_id] = true
	services.friends.presence_known[player("", "", 11).user_id] = true
	services.friends.online_ids[player("", "", 11).user_id] = true
