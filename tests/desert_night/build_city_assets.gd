extends SceneTree
## Prepara módulos de autoria com alfa, proporção preservada e mipmaps.
func _initialize() -> void:
	var failures := 0
	for key: String in ["capital_merchant","capital_watchtower"]:
		var image := Image.load_from_file("res://assets/desert/modular/source/"+key+".png")
		if image == null:
			failures += 1
			continue
		var alpha := image.detect_alpha()
		if alpha == Image.ALPHA_NONE: failures += 1
		image=image.get_region(image.get_used_rect())
		var factor := minf(1.0,1024.0/maxi(image.get_width(),image.get_height()))
		image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		var texture := ImageTexture.create_from_image(image)
		var target := "res://assets/desert/modular/"+key+".res"
		var error := ResourceSaver.save(texture,target,ResourceSaver.FLAG_COMPRESS)
		if error != OK: failures += 1
		var loaded := load(target) as Texture2D
		if loaded == null or loaded.get_width()!=image.get_width() or loaded.get_height()!=image.get_height(): failures += 1
		print("CITY_ASSET ",key," size=",image.get_size()," alpha=",alpha," save=",error)
	print("CITY_ASSETS failures=",failures)
	quit.call_deferred(1 if failures else 0)
