extends SceneTree
## Converte a fonte de autoria em recurso nativo editável, sem importador de editor.
func _initialize() -> void:
	var image := Image.load_from_file("res://assets/desert/modular/source/capital_desert.png")
	if image == null: quit(1); return
	image.resize(1672,941,Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var error := ResourceSaver.save(texture,"res://assets/desert/modular/capital_desert.res",ResourceSaver.FLAG_COMPRESS)
	print("CAPITAL_BACKDROP_SAVE ",error)
	quit.call_deferred(error)
