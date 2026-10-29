extends SceneTree
## Provas geométricas independentes de tempo, alcance e suprimento das nove fases.
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func run() -> void:
	var identities := {}
	for order in range(1,10):
		var stage: Dictionary = Layout.build(order)
		var start := float(stage.player_spawn[0])
		var goal := float(stage.goal.pos[0])
		var prefix := "fase %02d · " % order
		check(stage.get("order",0) == order,prefix+"ordem estável")
		check((goal-start-1.0)/6.0 >= 180.0,prefix+"limite inferior de duração >=180s")
		check(stage.get("checkpoints",[]).size() == 7,prefix+"um checkpoint por distrito depois do primeiro")
		check(stage.next_scene == "res://scenes/desert/phase_%02d.tscn" % (order+1),prefix+"saída aponta para a próxima cena existente")
		check(ResourceLoader.exists(stage.next_scene),prefix+"próxima cena existe")
		check(not identities.has(stage.name),prefix+"identidade de fase distinta")
		identities[stage.name] = true
		var ids := {}
		var grounds: Array = []
		var spawn_safe := false
		var goal_safe := false
		var max_step := 0.0
		var islands: Array = []
		var walls: Array[float] = []
		var bad_ids: Array[String] = []
		var unsafe_pickups: Array[String] = []
		var unsafe_enemies: Array[String] = []
		for platform: Dictionary in stage.platforms:
			if not platform.has("id") or ids.has(platform.get("id","")): bad_ids.append(str(platform.get("id","platform_without_id")))
			ids[platform.get("id","")] = true
			var left := float(platform.pos[0])-float(platform.size[0])*0.5
			var right := float(platform.pos[0])+float(platform.size[0])*0.5
			var top := float(platform.pos[1])+float(platform.size[1])*0.5
			if platform.kind == "crumble":
				# Pedra do vão largo: ponto de apoio no meio, não chão seguro.
				islands.append([left,right])
				continue
			if platform.kind == "geyser_wall":
				walls.append(float(platform.pos[0]))
				continue
			if platform.kind == "ground":
				grounds.append([left,right])
				if start > left+1 and start < right-1: spawn_safe = true
				if goal > left+1 and goal < right-1: goal_safe = true
			else: max_step = maxf(max_step,top)
		check(spawn_safe and goal_safe,prefix+"spawn e saída sobre chão seguro")
		check(max_step <= 2.7+0.01,prefix+"degraus acessíveis ao pulo duplo")
		grounds.sort_custom(func(a: Array,b: Array) -> bool: return a[0] < b[0])
		# Colisores contíguos são divididos para streaming; suas emendas não são bordas fatais.
		var connected: Array = []
		for interval: Array in grounds:
			if not connected.is_empty() and float(interval[0]) <= float(connected[-1][1])+0.01:
				connected[-1][1] = maxf(float(connected[-1][1]),float(interval[1]))
			else: connected.append(interval.duplicate())
		grounds = connected
		var holes := 0
		var ferries := 0
		var gaps_ok := true
		for index in range(grounds.size()-1):
			var gap: float = grounds[index+1][0]-grounds[index][1]
			if gap > 0.1:
				holes += 1
				# Vão largo: cada metade (borda→pedra→borda) precisa estar no alcance.
				var parts: Array[float] = [gap]
				for island: Array in islands:
					if island[0] > grounds[index][1] and island[1] < grounds[index+1][0]:
						parts = [float(island[0])-float(grounds[index][1]), float(grounds[index+1][0])-float(island[1])]
				# Vão com balsa: a balsa (2,6m) para a 0,1m de cada borda; o vão ao subir é curto.
				for hole: Dictionary in stage.holes:
					if hole.get("ferry",false) and absf(float(hole.start)-float(grounds[index][1])) < 0.05:
						parts = [0.1, 0.1]
						ferries += 1
				for part in parts:
					if part > 3.5+0.01 or (parts.size() == 1 and part < 2.5) or (part < 1.5 and part > 0.2): gaps_ok = false
		check(holes >= 12,prefix+"buracos reais distribuídos pelo percurso")
		check(islands.size() >= 2,prefix+"vãos largos com pedra que desmorona")
		check(ferries >= 1,prefix+"vão com balsa de pedra (%d)" % ferries)
		var storms: Array = stage.get("storms",[])
		check(storms.size() == 1 and float(storms[0].end)-float(storms[0].start) >= 50.0,prefix+"trecho de tempestade de areia")
		var geysers_ok := walls.size() >= 2
		for x in walls:
			var sides := 0
			for geyser: Dictionary in stage.geysers:
				if absf(absf(float(geyser.pos[0])-x)-4.2) < 0.01: sides += 1
			if sides != 2: geysers_ok = false
		check(geysers_ok,prefix+"muralhas altas com gêiser dos dois lados")
		check(gaps_ok,prefix+"vãos reversíveis dentro do alcance de salto")
		var attack := 0
		var defense := 0
		for pickup: Dictionary in stage.pickups:
			if ids.has(pickup.id): bad_ids.append(str(pickup.id))
			ids[pickup.id] = true
			if pickup.kind == "attack": attack += 1
			if pickup.kind == "defense": defense += 1
			var safe := false
			for ground: Array in grounds:
				if float(pickup.pos[0]) > ground[0]+1 and float(pickup.pos[0]) < ground[1]-1: safe = true
			if not safe: unsafe_pickups.append(str(pickup.id))
		check(attack+1 >= stage.enemies.size(),prefix+"ataques suficientes para todos os Cactus")
		check(defense >= 5,prefix+"defesa pode ser reposta no mapa")
		check(stage.enemies.size() >= 12 and stage.enemies.size() <= 24,prefix+"densidade de Cactus adequada ao percurso longo")
		for enemy: Dictionary in stage.enemies:
			if ids.has(enemy.id): bad_ids.append(str(enemy.id))
			ids[enemy.id] = true
			var safe := false
			for ground: Array in grounds:
				if float(enemy.pos[0]) > ground[0]+3 and float(enemy.pos[0]) < ground[1]-3: safe = true
			if not safe: unsafe_enemies.append(str(enemy.id))
		check(bad_ids.is_empty(),prefix+"ids únicos e estáveis: "+str(bad_ids))
		check(unsafe_pickups.is_empty(),prefix+"reposições em áreas seguras: "+str(unsafe_pickups))
		check(unsafe_enemies.is_empty(),prefix+"combates afastados dos vãos: "+str(unsafe_enemies))
		print("LAYOUT_SUMMARY order=",order," distance=",goal-start," lower_seconds=",(goal-start-1.0)/6.0," pits=",holes," enemies=",stage.enemies.size()," attack_pickups=",attack," defense_pickups=",defense)
	print("NIGHT_LAYOUT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
