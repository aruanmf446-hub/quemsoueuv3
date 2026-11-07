extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	var fake := preload("res://tests/profile_languages/fake_game.gd").new()
	root.add_child(fake)
	fake.access_token="fixture-not-real"
	services.client=fake
	services.session.client=fake
	services.profile.client=fake
	services.friends.client=fake
	services.session.user={"id":"00000000-0000-4000-8000-000000000011"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	services.session.set_process(false)
	var screen: Control = load("res://scenes/player/public_profile.tscn").instantiate()
	root.add_child(screen)
	screen.show_screen({"public_id":fake.target.public_id})
	for i in 8: await process_frame
	check(screen.find_child("PublicNickname", true, false).text=="aruan", "public nickname preserved")
	check(screen.find_child("PublicProfileCharacter", true, false)!=null, "real avatar stage")
	check(screen.find_child("CopyPublicId", true, false)!=null, "copy public ID action")
	check(screen.find_child("ReportPlayer", true, false)!=null, "report action preserved")
	await screen._add_friend(fake.target.user_id)
	var button: Button=screen.find_child("AddPublicFriend", true, false)
	check(button.disabled and button.text==tr("Solicitação enviada"), "friend request confirmed by service")
	services.session.user={"id":fake.target.user_id}
	screen.show_screen({"public_id":fake.target.public_id})
	for i in 8: await process_frame
	check(screen.find_child("AddPublicFriend", true, false)==null, "no self request")
	print("PUBLIC_PROFILE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
