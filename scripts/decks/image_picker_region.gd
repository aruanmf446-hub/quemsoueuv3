extends Node
## HTML file input aligned with a native Godot button, clipped with the UI.
var button: Button
var picker: Node
var maximum := 0
var prepare: Callable
var _api: JavaScriptObject
var _callbacks: Array=[]
var _id := ""
var _last := ""
func _ready() -> void:
	_id="image_"+str(get_instance_id())
	_api=JavaScriptBridge.get_interface("qseImageInputs")
	if _api==null:
		set_process(false)
		return
	_callbacks=[JavaScriptBridge.create_callback(func(_args: Array)->void:prepare.call()),JavaScriptBridge.create_callback(func(args: Array)->void:picker.call("_web_result",args))]
func _process(_delta: float) -> void:
	if _api==null: return
	var rect := WebTextBridge.visible_control_rect(button)
	if rect.size==Vector2.ZERO or button.disabled:
		if _last!="off": _api.clearRegion(_id)
		_last="off"
		return
	var transform := button.get_viewport().get_final_transform()*button.get_canvas_transform()
	var first := transform*rect.position
	var last := transform*rect.end
	var key := str(first)+str(last)
	if key==_last: return
	_last=key
	_api.setRegion(_id,first.x,first.y,last.x-first.x,last.y-first.y,_callbacks[0],_callbacks[1],maximum,button.text)
func _exit_tree() -> void:
	if _api!=null: _api.clearRegion(_id)
