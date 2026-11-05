extends SceneTree
## Converte a fonte de autoria em recurso nativo editável, sem importador de editor.
func _initialize() -> void:
	var image := Image.load_from_file("res://assets/desert/modular/source/stone_masonry.png")
	if image == null: quit(1); return
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var error := ResourceSaver.save(texture,"res://assets/desert/modular/stone_masonry.res",ResourceSaver.FLAG_COMPRESS)
	print("NATIVE_MATERIAL_SAVE ",error)
	quit.call_deferred(error)
