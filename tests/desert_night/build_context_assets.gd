extends SceneTree
## Fontes preservadas; recorte de conteúdo, proporção e mipmaps como o lote aprovado.
func _initialize() -> void:
	var failures:=0
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/desert/modular/context_assets.json"))
	for item: Dictionary in catalog.assets:
		var image:=Image.load_from_file(item.source)
		if image==null or image.detect_alpha()==Image.ALPHA_NONE:
			failures+=1
			continue
		var r: Array=item.content_pixel_rect
		image=image.get_region(Rect2i(r[0],r[1],r[2],r[3]))
		var factor:=minf(1.0,float(catalog.max_dimension)/maxi(image.get_width(),image.get_height()))
		image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		var error:=ResourceSaver.save(ImageTexture.create_from_image(image),item.texture,ResourceSaver.FLAG_COMPRESS)
		var loaded:=load(item.texture) as Texture2D
		if error!=OK or loaded==null or Vector2i(loaded.get_size())!=image.get_size():failures+=1
		print("CONTEXT_ASSET ",item.id," size=",image.get_size()," save=",error)
	quit.call_deferred(1 if failures else 0)
