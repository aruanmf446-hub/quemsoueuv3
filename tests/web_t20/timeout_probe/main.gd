extends Node
## T20: HTTPRequest com tempo-limite contra servidor que nunca responde (Web).
var frames := 0
func _ready() -> void:
	for round in 3:
		var http := HTTPRequest.new()
		http.timeout = 2.0
		add_child(http)
		http.request("http://127.0.0.1:%d/hang" % (8099 if round % 2 == 0 else 8100))
		var r: Array = await http.request_completed
		print("T20_ROUND ", round, " result=", r[0])
		http.queue_free()
		await get_tree().create_timer(3.0).timeout
	print("T20_DONE frames=", frames)
func _process(_d: float) -> void:
	frames += 1
	if frames % 120 == 0: print("T20_ALIVE ", frames)
