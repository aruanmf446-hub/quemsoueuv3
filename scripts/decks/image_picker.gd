class_name ImagePicker
extends Node
## Importa uma imagem do aparelho. Web: <input type="file"> do navegador (os bytes vêm
## como base64). Android/Windows/Linux: diálogo nativo do sistema.
signal picked(image: Image, bytes: PackedByteArray, extension: String)
signal failed(message: String)

const MAX_BYTES := 12 * 1024 * 1024
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
var _callback: JavaScriptObject
var _dialog: FileDialog


func pick() -> void:
	if OS.has_feature("web"):
		_pick_web()
	else:
		_pick_native()


func _pick_native() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imagens"])
		_dialog.file_selected.connect(_load_path)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.7)


func _load_path(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	_decode(bytes, path.get_extension().to_lower())


func _pick_web() -> void:
	_callback = JavaScriptBridge.create_callback(_web_result)
	var window := JavaScriptBridge.get_interface("window")
	window.qse_image_picked = _callback
	JavaScriptBridge.eval("""(function(){
		var input=document.createElement('input');input.type='file';input.accept='image/png,image/jpeg,image/webp';
		input.onchange=function(){var f=input.files&&input.files[0];if(!f){return;}
			if(f.size>%d){window.qse_image_picked('', 'too_big');return;}
			var r=new FileReader();r.onload=function(){var s=String(r.result);window.qse_image_picked(s.slice(s.indexOf(',')+1),(f.name.split('.').pop()||'').toLowerCase());};
			r.onerror=function(){window.qse_image_picked('', 'read_error');};r.readAsDataURL(f);};
		input.click();})()""" % MAX_BYTES, true)


func _web_result(args: Array) -> void:
	if args.size() < 2 or str(args[0]).is_empty():
		failed.emit("Imagem muito grande (máx. 12 MB)." if args.size() > 1 and str(args[1]) == "too_big" else "Não foi possível ler a imagem.")
		return
	_decode(Marshalls.base64_to_raw(str(args[0])), str(args[1]))


func _decode(bytes: PackedByteArray, extension: String) -> void:
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		failed.emit("Imagem vazia ou maior que 12 MB.")
		return
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	match extension:
		"png": error = image.load_png_from_buffer(bytes)
		"jpg", "jpeg": error = image.load_jpg_from_buffer(bytes)
		"webp": error = image.load_webp_from_buffer(bytes)
	if error != OK or image.is_empty():
		failed.emit("Formato não suportado. Use PNG, JPG ou WEBP.")
		return
	picked.emit(image, bytes, "jpg" if extension == "jpeg" else extension)
