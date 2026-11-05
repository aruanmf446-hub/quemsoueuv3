extends "res://scripts/decks/repository_service.gd"
## Atualização de status isolada: nenhum HTTP ou backend real.
var rows: Array=[]
func request(_path: String, _method := HTTPClient.METHOD_GET, _body: Variant=null) -> Dictionary:
	return ServiceResult.success({"items":rows})
