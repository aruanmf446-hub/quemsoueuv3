extends SceneTree
## Bake the actual equippable 3D characters for clean installs and exported builds.
## Run with a rendering display; output is shipped, never user:// dependent.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Portrait baking needs a rendering display")
		quit(1)
		return
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cache := ThumbnailCache.new(load("res://scenes/lobby/lobby_stage.tscn"))
	var entries := CharacterCatalog.load_entries()
	var paths := await cache.ensure(host, entries)
	DirAccess.make_dir_recursive_absolute("res://assets/portraits")
	for entry: Dictionary in entries:
		if not paths.has(entry.id): quit(1); return
		var source := Image.load_from_file(paths[entry.id])
		var bounds := source.get_used_rect()
		# Humans need a closer head-and-shoulders crop than the oversized Cowboy hat.
		var height := mini(source.get_height() - bounds.position.y, roundi(bounds.size.y * (0.48 if entry.id == "cowboy" else 0.34)))
		var width := mini(source.get_width(), roundi(height * 1.05))
		var left := clampi(roundi(bounds.get_center().x - width * 0.5), 0, source.get_width() - width)
		var image := source.get_region(Rect2i(left, bounds.position.y, width, height))
		if image.get_height() > 720: image.resize(roundi(width * 720.0 / height), 720, Image.INTERPOLATE_LANCZOS)
		if image == null or image.is_empty(): quit(1); return
		var error := image.save_png("res://assets/portraits/%s.png" % entry.id)
		if error != OK: quit(1); return
		print("PORTRAIT ", entry.id, " ", image.get_size())
	host.queue_free()
	await process_frame
	quit()
