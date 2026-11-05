extends SceneTree
## Instala capas capturadas pelo motor; não executa importador nem renderiza conceitos.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():quit.call_deferred(2);return
	var failures:=0
	for order in range(1,11):
		var path:=args[0]+"/cover_phase_%02d.res" % order
		var source:=load(path) as Texture2D
		if source==null:failures+=1;continue
		var image:=source.get_image()
		image.resize(512,roundi(512.0*image.get_height()/image.get_width()),Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		var texture:=ImageTexture.create_from_image(image)
		var error:=ResourceSaver.save(texture,"res://assets/story/covers/phase_%02d.res" % order,ResourceSaver.FLAG_COMPRESS)
		if error!=OK:failures+=1
		print("NATIVE_COVER phase=",order," error=",error)
	print("NATIVE_COVERS failures=",failures)
	quit.call_deferred(1 if failures else 0)
