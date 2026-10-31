class_name OAuthDesktopLoopback
extends Node
## Windows PKCE callback over loopback only; requires one manual Supabase allowlist entry.
## No tokens are sent to or stored by the browser callback page.
signal callback_received(code: String, error: String)
signal callback_timeout
const PORT := 49173
var _server := TCPServer.new()
var _peer: StreamPeerTCP
var _request := ""
var _expires_msec := 0

func start() -> bool:
	if _server.is_listening():
		return false
	if _server.listen(PORT, "127.0.0.1") != OK:
		return false
	_expires_msec = Time.get_ticks_msec() + 180000
	set_process(true)
	return true

func close() -> void:
	_server.stop()
	_peer = null
	_request = ""
	set_process(false)

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if not _server.is_listening():
		set_process(false)
		return
	if Time.get_ticks_msec() > _expires_msec:
		close()
		callback_timeout.emit()
		return
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
		_request = ""
	if _peer == null:
		return
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_peer = null
		return
	var amount := _peer.get_available_bytes()
	if amount > 0:
		_request += _peer.get_utf8_string(mini(amount, 4096))
	if _request.length() > 4096:
		_send_response(400, "Requisicao invalida")
		_peer = null
		return
	if not _request.contains("\r\n\r\n"):
		return
	var first := _request.split("\r\n")[0]
	var host_ok := _request.to_lower().contains("\r\nhost: 127.0.0.1:49173\r\n")
	var valid := first.begins_with("GET /oauth/callback?") and first.ends_with(" HTTP/1.1") and host_ok
	if not valid:
		_send_response(404, "Retorno invalido")
		_peer = null
		return
	var url := first.trim_prefix("GET ").trim_suffix(" HTTP/1.1")
	var data := _parse_query(url.get_slice("?", 1))
	var code := str(data.get("code", ""))
	var err := str(data.get("error", ""))
	if not OAuthPkce.valid_callback(code) and err.is_empty():
		_send_response(400, "Codigo invalido")
		_peer = null
		return
	_send_response(200, "Volte ao Quem Sou Eu V3 para continuar.")
	close()
	callback_received.emit(code, err)

func _send_response(status: int, body: String) -> void:
	if _peer == null:
		return
	var message := "<!doctype html><meta charset='utf-8'><title>Quem Sou Eu V3</title><p>" + body + "</p>"
	var header := "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: default-src 'none'\r\nConnection: close\r\n\r\n" % [status, "OK" if status == 200 else "Error", message.to_utf8_buffer().size()]
	_peer.put_data((header + message).to_utf8_buffer())

static func _parse_query(query: String) -> Dictionary:
	var output := {}
	for entry: String in query.split("&", false):
		var k := entry.get_slice("=", 0).uri_decode()
		if not k in ["code", "error", "error_description"]:
			continue
		output[k] = entry.substr(entry.find("=") + 1).replace("+", " ").uri_decode()
	return output
