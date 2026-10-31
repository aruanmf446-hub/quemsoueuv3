extends Node
## T20: chamada nativa sem argumentos (int) em WebSocketPeer tipado que virou null.
var _socket: WebSocketPeer
var frames := 0
var step := 0
func _ready() -> void:
	_socket = WebSocketPeer.new()
	print("T20_START")
func _process(_d: float) -> void:
	frames += 1
	if frames % 60 == 0: print("T20_ALIVE ", frames)
	if frames == 120:
		_socket = null
		print("T20_NULL_CALL")
		var n := _socket.get_available_packet_count()
		print("T20_AFTER ", n)
