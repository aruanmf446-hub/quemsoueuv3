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
		"email_address_invalid": return "Informe um e-mail válido."
		"password_required": return "Digite sua senha."
		"weak_password": return "A senha deve ter pelo menos 6 caracteres."
		"email_not_confirmed": return "Confirme o e-mail recebido antes de entrar."
		"email_exists", "user_already_exists": return "Esta conta já existe. Experimente entrar."
		"email_provider_disabled", "signup_disabled": return "Cadastro por e-mail indisponível. Verifique a configuração do GAME."
		"over_email_send_rate_limit", "over_request_rate_limit", "rate_limit": return "Limite de tentativas ou de envio de e-mails atingido. Aguarde antes de repetir."
		"provider_unavailable": return "Este provedor ainda não está habilitado no GAME."
		"oauth_access_denied": return "Autorização cancelada no Google. Você pode tentar novamente."
		"oauth_missing_verifier": return "O retorno do Google expirou ou foi aberto em outra aba. Inicie o login novamente."
		"oauth_storage_unavailable": return "Permita o armazenamento temporário da aba para entrar com Google."
		"oauth_unavailable", "oauth_exchange_failed": return "Não foi possível concluir o login Google. Confira o retorno autorizado e tente novamente."
		"invalid_refresh_token", "refresh_token_not_found": return "Sua sessão expirou. Entre novamente."
		"otp_expired", "otp_disabled": return "O link expirou ou não é mais válido. Solicite outro."
		"captcha_failed": return "A verificação de segurança não foi concluída."
		"auth_request_failed", "validation_failed": return "Confira os dados e tente novamente."
		"invalid_credentials": return "Não foi possível entrar. Confira e-mail, senha e confirmação da conta."
		"verification_unavailable": return "A validação das conclusões ainda não está integrada."
		"invalid_contract": return "O servidor retornou dados incompatíveis. Nenhuma alteração foi aplicada."
		_: return "Não foi possível concluir a ação. Atualize e tente novamente."
