class_name OAuthPkce
extends RefCounted
## OAuth Google Web (GoTrue): RFC 7636. Nenhum segredo do provedor no cliente.
## Verificador permanece apenas em sessionStorage durante o redirecionamento.

const KEY := "qse-v3:google:pkce-verifier"

static func _base64url(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").replace("=", "")

static func generate_verifier() -> String:
	return _base64url(Crypto.new().generate_random_bytes(32))

static func challenge(verifier: String) -> String:
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hash.update(verifier.to_utf8_buffer()) != OK:
		return ""
	return _base64url(hash.finish())

static func google_authorize_path(redirect_url: String, code_challenge: String) -> String:
	return "/auth/v1/authorize?provider=google&redirect_to=" + redirect_url.uri_encode() + "&code_challenge=" + code_challenge.uri_encode() + "&code_challenge_method=s256"
