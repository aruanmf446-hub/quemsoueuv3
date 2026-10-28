class_name ServiceResult
extends RefCounted

## Todos os adaptadores devolvem o mesmo envelope, sem erros internos/tokens na UI.
static func success(data: Variant) -> Dictionary:
	return {"ok": true, "state": "success", "data": data, "code": ""}


static func failure(code: String, state: String = "error") -> Dictionary:
	return {"ok": false, "state": state, "data": null, "code": code}


static func message(result: Dictionary) -> String:
	match result.get("code", ""):
		"not_configured": return "Conexão ainda não configurada. Você está na demonstração local."
		"not_authenticated", "session_changed": return "Entre na sua conta para continuar."
		"network": return "Sem conexão. Tente novamente quando estiver online."
		"revision_conflict": return "O progresso mudou em outro dispositivo. Atualize e tente novamente."
		"locked_character": return "Conclua as dez fases do Deserto para desbloquear El Fuego."
		"invalid_nickname": return "Use de 3 a 24 caracteres no nickname."
		"rate_limit": return "Muitas tentativas. Aguarde um pouco antes de tentar novamente."
		"invalid_credentials": return "Não foi possível entrar. Confira e-mail, senha e confirmação da conta."
		"verification_unavailable": return "A validação das conclusões ainda não está integrada."
		"invalid_contract": return "O servidor retornou dados incompatíveis. Nenhuma alteração foi aplicada."
		_: return "Não foi possível concluir a ação. Atualize e tente novamente."
