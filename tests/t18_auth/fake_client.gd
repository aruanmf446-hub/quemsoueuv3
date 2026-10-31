extends SupabaseClient
## Sem requisicoes reais. Usado apenas em t18_auth/flow_test.gd.
var response: Dictionary = ServiceResult.failure("invalid_credentials")
var paths: Array[String] = []

func configured() -> bool:
	return true

func request(path: String, method: HTTPClient.Method, body: Dictionary = {}, authenticated: bool = true, token_override: String = "") -> Dictionary:
	paths.append(path)
	return response
