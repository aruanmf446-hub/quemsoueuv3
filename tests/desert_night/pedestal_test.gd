extends SceneTree
## Fixture local: capacidade e coleta reais; teleporte somente para auditar chunks.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+text)
func frames() -> void:
	for i in 3: await process_frame
func matching(group: String, id: String) -> Array:
	return get_nodes_in_group(group).filter(func(n: Node) -> bool: return n.get_meta("pickup_id","") == id)
func capacity(player: Node, kind: String, amount: int) -> void:
	match kind:
		"health": player.health = amount
		"attack": player.attack_charges = amount
		"defense": player.defense_charges = amount
		_: player.abilities[kind] = amount
func run() -> void:
	var phase: Node3D = load("res://scenes/desert/phase_05.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	phase._player.position = Vector3(-1000,0,0)
	for kind: String in ["attack","health","defense","amber","dash","rupture"]:
		var spawn: Dictionary = {}
		for value: Dictionary in phase._phase.pickups:
			if value.kind == kind: spawn = value; break
		check(not spawn.is_empty(),kind+": recarga existe")
		if spawn.is_empty(): continue
		var id := str(spawn.id)
		phase._stream_world(float(spawn.pos[0]),true)
		await frames()
		var items := matching("campaign_pickups",id)
		var bases := matching("campaign_pedestals",id)
		check(items.size()==1 and bases.size()==1,kind+": um item e uma base")
		if items.size()!=1 or bases.size()!=1: continue
		var item: Area3D = items[0]
		var base: MeshInstance3D = bases[0]
		if kind=="attack":check(base.mesh.get_aabb().end.y<0.04,"estação embutida no piso, sem torrão elevado")
		check(item.get_parent()==base.get_parent(),kind+": base pertence ao chunk e não ao item")
		var collected := [0]
		var full := [0]
		item.collected.connect(func(_id: String,_kind: String) -> void: collected[0] += 1)
		item.full_touched.connect(func(_kind: String) -> void: full[0] += 1)
		capacity(phase._player,kind,3)
		item._try_collect(phase._player)
		item._try_collect(phase._player)
		check(not item.is_queued_for_deletion() and collected[0]==0 and full[0]==1,kind+": cheia preserva item, capacidade e aviso único")
		check(not bool(base.get_meta("spent",true)),kind+": estação cheia continua visualmente disponível")
		capacity(phase._player,kind,2)
		item._try_collect(phase._player)
		item._try_collect(phase._player)
		check(collected[0]==1 and phase._collected_ids.has(id),kind+": coleta uma vez e persiste ID")
		check(bool(base.get_meta("spent",false)),kind+": coleta apaga o acento da estação sem removê-la")
		check((phase._player.health if kind=="health" else phase._player.charges(kind))==3,kind+": repõe exatamente uma carga")
		await frames()
		check(matching("campaign_pickups",id).is_empty() and is_instance_valid(base) and base.is_inside_tree(),kind+": coletável removido, pedestal permanece")
		phase._stream_world(1100.0 if float(spawn.pos[0])<500.0 else 0.0,true)
		await frames()
		check(not is_instance_valid(base) and matching("campaign_pedestals",id).is_empty(),kind+": descarregar chunk remove base sem resíduos")
		phase._stream_world(float(spawn.pos[0]),true)
		await frames()
		check(matching("campaign_pedestals",id).size()==1 and matching("campaign_pickups",id).is_empty(),kind+": revisitar recupera só a base, sem duplicar ou reaparecer item")
		var restored:=matching("campaign_pedestals",id)
		check(restored.size()==1 and bool(restored[0].get_meta("spent",false)),kind+": aparência consumida é restaurada ao revisitar")
	for x in [0.0,350.0,700.0,1100.0,0.0]:
		phase._stream_world(x,true)
		await frames()
		var ids := {}
		var unique := true
		for base: Node in get_nodes_in_group("campaign_pedestals"):
			var id := str(base.get_meta("pickup_id"))
			if ids.has(id): unique = false
			ids[id] = true
		check(unique and phase._loaded_chunks.size()<=5,"stream %.0f: bases únicas em até cinco chunks" % x)
	phase.free()
	await frames()
	check(get_nodes_in_group("campaign_pedestals").is_empty(),"sair da fase remove todos os pedestais")
	print("PEDESTALS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
