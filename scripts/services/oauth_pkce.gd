class_name OAuthPkce
extends RefCounted
## PKCE RFC 7636; never send code_verifier to the browser URL or provider.
const PENDING_KEY := "qse-v3:oauth:pending"
const REFRESH_KEY := "qse-v3:game:refresh"
const REDIRECT_WINDOWS := "http://127.0.0.1:49173/oauth/callback"
const REDIRECT_ANDROID := "quemsoueuv3://oauth/callback"
const MAX_PENDING_SECONDS := 600

static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

static func make_verifier() -> String:
	return base64url(Crypto.new().generate_random_bytes(32))

static func challenge(verifier: String) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(verifier.to_utf8_buffer()) != OK:
		return ""
	return base64url(hashing.finish())

static func authorize_path(provider: String, redirect_url: String, code_challenge: String) -> String:
	if not provider in ["google", "discord"]:
		return ""
	return "/auth/v1/authorize?provider=" + provider.uri_encode() + "&redirect_to=" + redirect_url.uri_encode() + "&code_challenge=" + code_challenge.uri_encode() + "&code_challenge_method=s256"

static func valid_callback(code: String) -> bool:
	return not code.is_empty() and code.length() <= 4096 and not code.contains("\n") and not code.contains("\r")
