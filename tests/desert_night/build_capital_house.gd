extends SceneTree
func _initialize() -> void:
	var image := Image.load_from_file("res://assets/desert/modular/source/capital_house.png")
	if image == null: quit(1); return
	image=image.get_region(image.get_used_rect())
	image.resize(1024,roundi(1024.0*image.get_height()/image.get_width()),Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var error := ResourceSaver.save(texture,"res://assets/desert/modular/capital_house.res",ResourceSaver.FLAG_COMPRESS)
	print("CAPITAL_HOUSE_SAVE ",error)
	quit.call_deferred(error)
