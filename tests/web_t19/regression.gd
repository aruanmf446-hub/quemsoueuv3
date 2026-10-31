extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures+=1
func settle(seconds:=0.35) -> void: await create_timer(seconds).timeout
func run() -> void:
	var menu: Control=load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await settle()
	var nav: NavigationManager=menu.get_node("Navigation")
	nav.back()
	await settle()
	for index in range(20):
		nav.open("settings")
		await settle()
		var settings: PlayerScreen=nav.get("_active")
		check(settings!=null and not nav.get("_busy"),"open_%d"%index)
		for category in [1,2,3,0]: settings.call("_select",category)
		nav.back()
		await settle()
		check(nav.get("_active")==null and not nav.get("_busy"),"return_%d"%index)
	nav.open("settings")
	# A killed animation used to retain _busy forever. The deadline recovers its UI state.
	var screen: PlayerScreen=nav.get("_active")
	(screen.get_meta("nav_motion") as Tween).kill()
	await settle(2.2)
	check(not nav.get("_busy") and screen.visible,"cancelled_tween_recovers")
	nav.back()
	await settle()
	nav.open("settings")
	nav.back() # Intention during the entering animation must not be discarded.
	await settle(0.6)
	check(nav.get("_active")==null and not nav.get("_busy"),"rapid_back_not_dropped")
	var request_owner := Node.new()
	root.add_child(request_owner)
	var abandoned := await LoadingVeil.begin(self,"Teste",request_owner)
	request_owner.queue_free()
	await settle(0.4)
	check(not is_instance_valid(abandoned),"orphan_veil_releases_input")
	var music: MenuMusicPlayer=load("res://tests/web_t19/music_fixture.gd").new()
	root.add_child(music)
	music.set_process(false)
	music._inside=true
	music._menu=menu
	music.tracks.assign([{"id":"a","audio":"unused"},{"id":"b","audio":"unused"}])
	music._select(1)
	for index in range(20): music._process(0.5)
	check(music.requests==1,"autoplay_waits_for_inflight_download")
	var loading:=music._web_loading
	var wanted: String="b" if loading=="a" else "a"
	music._web_wanted={"track":{"id":wanted},"position":0.0}
	music._web_loaded(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray([1,2,3]))
	check(not music._web_cache.has(loading),"discarded_response_is_not_prepared")
	check(music._web_loading==wanted,"explicit_next_intent_is_preserved")
	# Real, unchanged MP3 bytes; no silence/re-encoding/quality replacement.
	var folder:=DirAccess.open("res://assets/music/Trap")
	var path:=""
	for file in folder.get_files():
		if file.ends_with(".mp3"): path="res://assets/music/Trap/"+file;break
	music._web_loaded(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),FileAccess.get_file_as_bytes(path))
	check(music.current_id==wanted and music._players[music._active].playing,"requested_audio_starts")
	check(music._players[music._active].stream==music._web_cache[wanted],"prepared_mp3_is_not_duplicated")
	check(not music._web_cache[wanted].loop,"playlist_can_advance")
	music.tracks.append({"id":"cached","audio":"unused"})
	music._web_cache["cached"] = music._web_cache[wanted]
	music._web_loading="late"
	music._web_wanted={"track":{"id":"late"},"position":0.0}
	music._history.append("cached")
	music.previous_track()
	check(music.current_id=="cached" and music._web_wanted.is_empty(),"cached_previous_supersedes_inflight_intent")
	music._web_loaded(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray([1,2,3]))
	check(music.current_id=="cached","late_completion_cannot_hijack_selection")
	if music._fade!=null: music._fade.kill();music._fade=null
	music._players[music._active].seek(music.track_length()-0.15)
	music._web_loading="future"
	music._web_wanted={"track":{"id":"future"},"position":0.0}
	var requests_before: int=music.requests
	music._process(0.01)
	check(music.requests==requests_before,"end_window_waits_for_existing_download")
	music._finished(music._active)
	check(music.requests==requests_before,"natural_finish_keeps_inflight_intent")
	music.pause()
	check(music._players[music._active].stream_paused,"pause_preserved")
	music.resume()
	check(not music.paused,"resume_preserved")
	music._web_wanted={"track":{"id":"missing"},"position":0.0}
	music._web_loading="missing"
	music._web_loaded(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())
	check(music._web_wanted.is_empty() and music._retry_in>=3.0,"failed_download_releases_pending_with_backoff")
	music.queue_free()
	menu.queue_free()
	await settle()
	print("T19_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
