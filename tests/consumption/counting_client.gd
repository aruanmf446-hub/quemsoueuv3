extends "res://scripts/services/supabase_client.gd"
## FIXTURE DE TESTE: conta requisições e responde localmente (nenhuma ida à rede).
var count := 0
var by_path: Dictionary = {}


func configured() -> bool:
	return true


func request(path: String, _method: HTTPClient.Method, _body: Dictionary = {}, _authenticated: bool = true, _token_override: String = "") -> Dictionary:
	count += 1
	by_path[path] = int(by_path.get(path, 0)) + 1
	await get_tree().process_frame
	if path.begins_with("/rest/v1/qse_catalog_"): return ServiceResult.success([])
	return ServiceResult.success({})
