extends SceneTree
func _initialize() -> void:
	var failures := 0
	var valid := RegEx.new()
	valid.compile("^[a-z][a-z0-9_]+$")
	for key: String in OS.get_cmdline_user_args():
		if valid.search(key) == null:
			failures += 1
			continue
		var image := Image.load_from_file("res://assets/desert/modular/source/"+key+".png")
		if image == null:
			failures += 1
			continue
		if image.detect_alpha() == Image.ALPHA_NONE: failures += 1
		image=image.get_region(image.get_used_rect())
		var factor := minf(1.0,1024.0/maxi(image.get_width(),image.get_height()))
		image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		var target := "res://assets/desert/modular/"+key+".res"
		var error := ResourceSaver.save(ImageTexture.create_from_image(image),target,ResourceSaver.FLAG_COMPRESS)
		var loaded := load(target) as Texture2D
		if error != OK or loaded == null: failures += 1
		elif loaded.get_size()!=Vector2(image.get_size()): failures += 1
		print("ASSET_BOT ",key," size=",image.get_size()," save=",error)
	print("ASSET_BOT_RESULT failures=",failures)
	quit.call_deferred(1 if failures else 0)
