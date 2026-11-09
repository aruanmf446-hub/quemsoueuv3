extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("MALAGUETA_", "PASS " if ok else "FAIL ", label)
func run() -> void:
	var encounter := preload("res://scripts/desert/malagueta/encounter.gd").new()
	root.add_child(encounter)
	var attacks: Array = []
	encounter.attack_requested.connect(func(kind: String) -> void: attacks.append(kind))
	encounter.tick(4)
	check(attacks == ["green"], "phase1 green only")
	encounter.tick(9)
	check(attacks.size() == 1, "one green active at a time")
	check(not encounter.complete_task(1), "cannot skip stun")
	for stage in range(1,4):
		encounter.hit(4)
		check(encounter.is_stunned() and encounter.remaining == 5, "five second stun "+str(stage))
		var count := attacks.size()
		encounter.tick(4.99)
		check(attacks.size()==count, "no attacks while stunned")
		encounter.tick(0.02)
		check(encounter.fighting() and encounter.completed_tasks==stage-1, "timeout retains completed tasks")
		check(not encounter.complete_task(stage), "expired task rejected")
		encounter.hit(4)
		check(not encounter.complete_task(stage+1), "out of order rejected")
		check(encounter.complete_task(stage), "real task advances")
		check(not encounter.complete_task(stage), "duplicate task rejected")
		attacks.clear()
		encounter.green_active=false
		if stage < 3:
			encounter.tick(4)
			check(attacks==(["red"] if stage==1 else ["green","red"]), "attack pattern follows task progress")
	check(encounter.state==encounter.State.CHEMICAL_REACTION, "three tasks start reaction")
	check(not encounter.hit(4), "cannot damage reaction")
	encounter.tick(2)
	check(encounter.state==encounter.State.BOSS_DEFEATED, "reaction completes boss")
	attacks.clear()
	encounter.tick(100)
	check(attacks.is_empty(), "no attacks after defeat")
	encounter.queue_free()
	print("MALAGUETA_SUMMARY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
