extends SceneTree
## T32: headless regression — no network, no microphone, no fabricated voice session.
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + description)
	if not ok: failures += 1

func _run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	for i in 4: await process_frame
	check(services.voice != null, "VoiceService is composed with PlayerServices")
	check(services.voice.state == "off", "voice begins disconnected")
	check(not services.voice.mic_enabled, "microphone begins disabled")
	check(not services.voice.eligible(), "anonymous user cannot join voice")
	check(not services.voice.supported(), "headless test does not claim working native/browser voice")
	services.duel.mode = "local"
	services.duel.room = {"room": {"id": "00000000-0000-4000-8000-000000000032", "status": "lobby"}}
	services.duel.changed.emit()
	check(not services.voice.eligible(), "local practice does not contact LiveKit")
	var widget := load("res://scripts/ui/battle/battle_voice.gd").new()
	widget.setup(services)
	root.add_child(widget)
	for i in 3: await process_frame
	var connect_button := widget.find_child("VoiceConnect", true, false) as Button
	var mic_button := widget.find_child("VoiceMicrophone", true, false) as Button
	check(connect_button != null and connect_button.disabled, "voice join disabled in local/headless mode")
	check(mic_button != null and mic_button.disabled, "microphone cannot be activated offline")
	services.voice.disconnect_voice()
	check(services.voice.state == "off" and services.voice.room_id.is_empty(), "disconnect clears all voice state")
	print("T32_VOICE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
