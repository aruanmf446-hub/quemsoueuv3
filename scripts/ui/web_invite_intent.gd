class_name WebInviteIntent
extends RefCounted
## Intenção transitória; o token permanece apenas na URL até o Duelo consumi-lo.
## Nunca persistir em user://, logs ou no histórico de rotas.

var pending := false
var consumed := false

func capture(has_invite: bool) -> void:
	if has_invite and not consumed:
		pending = true

func next_route(authenticated: bool) -> String:
	if not pending or consumed:
		return ""
	return "duel" if authenticated else "account"

func mark_opened(route: String) -> void:
	if route == "duel" and pending:
		pending = false
		consumed = true
