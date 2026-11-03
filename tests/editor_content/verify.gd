extends SceneTree
## Verificações off-line das novidades editáveis. Não depende de rede nem altera banco.
var checks := 0
var failures := 0

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS editor_content: ", message)
	else:
		failures += 1
		push_error("FAIL editor_content: " + message)

func _initialize() -> void:
	var reader := EditorContentService.new()
	_expect(not EditorContentService._valid_path("https://evil.example/p.png"), "URL arbitrária recusada")
	_expect(not EditorContentService._valid_path("covers/../secret.webp"), "path traversal recusado")
	_expect(EditorContentService._valid_path("covers/asset.webp"), "capa WebP permitida")
	_expect(EditorContentService._valid_path("covers/asset.jpg"), "capa JPEG permitida")
	_expect(not EditorContentService._valid_path("other/asset.png"), "bucket fora da pasta recusado")
	_expect(reader.deck("lendas_urbanas").is_empty(), "dados locais mantidos antes da rede")
	reader.state = "remote"
	reader.entries = {
		"deck:lendas_urbanas": {"id":"deck:lendas_urbanas","kind":"deck","title":"Lendas novas","description":"Descrição publicada","cover_path":"covers/asset.webp","active":true},
		"news:nova": {"id":"news:nova","kind":"news","title":"Notícia nova","subtitle":"EVENTOS","description":"Texto de teste","cover_path":"covers/asset.webp","priority":20,"active":true},
		"news:antiga": {"id":"news:antiga","kind":"news","title":"Notícia antiga","description":"Histórico","cover_path":"","priority":10,"active":true}
	}
	_expect(reader.deck("lendas_urbanas").get("title") == "Lendas novas", "editor substitui nome oficial")
	_expect(reader.news_cards().size() == 2, "múltiplas notícias no carrossel")
	_expect(reader.news_cards()[0].title == "Notícia nova", "ordem por prioridade respeitada")
	_expect(reader.news_cards()[0].cover_path == "covers/asset.webp", "capa remota vinculada")
	_expect(reader.news_cards()[0].message == "Texto de teste", "descrição remota vinculada")
	print("Editor content smoke: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
