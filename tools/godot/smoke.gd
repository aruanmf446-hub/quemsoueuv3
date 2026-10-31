extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://scenes/desert/phase_01.tscn"
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SMOKE_LOAD_FAILED " + path)
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in range(30):
		await physics_frame
	if scene is Node3D:
		if scene.get("_player") == null or scene.get("_camera") == null:
			push_error("SMOKE_NODES_FAILED " + path)
			quit(1)
			return
		var config: Dictionary = scene.get("_phase")
		var next_path := str(config.get("next_scene", ""))
		if not next_path.is_empty() and not ResourceLoader.exists(next_path):
			push_error("SMOKE_TRANSITION_RESOURCE_FAILED " + next_path)
			quit(1)
			return
		if not next_path.is_empty() and "--transition" in args:
			scene.call("_advance", next_path)
			var replacement: Node = null
			var story_skipped := false
			var deadline := Time.get_ticks_msec() + 12000
			while Time.get_ticks_msec() < deadline:
				var story := root.get_node_or_null("PhaseStory") as PhaseStory
				if story != null and not story_skipped:
					if not story._carousel.manual_story or story._carousel.cards.size() < 2:
						push_error("SMOKE_STORY_FAILED " + next_path)
						quit(1)
						return
					story_skipped = true
					story._carousel.skip_requested.emit()
				for child in root.get_children():
					if child is Node3D and child.scene_file_path == next_path:
						replacement = child
						break
				if replacement != null: break
				await process_frame
			if not story_skipped or replacement == null or replacement.scene_file_path != next_path:
				push_error("SMOKE_TRANSITION_FAILED " + next_path)
				quit(1)
				return
			scene = replacement
			current_scene = scene
			print("SMOKE_TRANSITION_OK " + next_path)
	if scene is Control:
		var navigation := scene.get_node("Navigation")
		# A T18A coloca account como primeira tela. Este smoke percorre menus
		# do lobby depois que o visitante escolhe "Jogar sem conta".
		var initial_history: Array = navigation.get("_history")
		if not initial_history.is_empty() and initial_history.back().route == "account":
			navigation.call("back")
			var startup_deadline := Time.get_ticks_msec() + 2000
			while navigation.get("_busy") and Time.get_ticks_msec() < startup_deadline:
				await process_frame
			if not navigation.get("_history").is_empty():
				push_error("SMOKE_STARTUP_BACK_FAILED")
				quit(1)
				return
		var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/routes.json"))["routes"]
		for route: String in routes:
			navigation.call("open", route, {})
			for frame in range(20):
				await physics_frame
			var active: Control = navigation.get("_active")
			var history: Array = navigation.get("_history")
			if active == null or not active.is_visible_in_tree() or history.is_empty() or history.back().route != route:
				push_error("SMOKE_ROUTE_FAILED " + route)
				quit(1)
				return
			print("SMOKE_ROUTE_OPEN " + route)
			navigation.call("back")
			for frame in range(3):
				await physics_frame
			# A tela que sai anima (FADE_OUT) e a navegação ignora rotas até terminar.
			var settle_deadline := Time.get_ticks_msec() + 2000
			while navigation.get("_busy") and Time.get_ticks_msec() < settle_deadline:
				await process_frame
			if not navigation.get("_history").is_empty() or navigation.get("_active") != null:
				push_error("SMOKE_ROUTE_CLOSE_FAILED " + route)
				quit(1)
				return
	print("SMOKE_OPEN_OK " + path)
	# SceneTree encerra e libera a cena atual na ordem normal do motor.
	quit(0)
