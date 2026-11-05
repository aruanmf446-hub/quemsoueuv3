extends RefCounted
## Percursos modulares mundiais: cada superfície, item e patrulha compartilha sua altura real.
const MAX_HORIZONTAL_SPEED := 7.4
const DEFAULT_DISTANCE := 1452.0
const CHUNK_LENGTH := 24.0
const NAMES := ["Portões da Capital","Telhados da Capital","Bazar da Cidade","Aqueduto do Deserto","Jardins do Oásis","Ruínas Enterradas","Estrada da Mineração","Posto de Controle","Entrada da Mineradora","Interior da Mineração"]
const THEMES := ["city_gates","rooftops","bazaar","aqueduct","oasis","ruins","mining_road","checkpoint","mine_entrance","mine_interior"]
const DESCRIPTIONS := ["Atravesse os portões, pátios e muralhas de acesso à capital.","Corra sobre lajes e terraços; a rua fica muito abaixo.","Cruze o mercado noturno, depósitos e corredores comerciais.","Atravesse canais, pontes e arcos do grande aqueduto.","Siga pelas águas, jardins e palmeiras do oásis.","Explore câmaras e passagens do reino antigo.","Deixe a capital pela rota de transporte de minério.","Atravesse os setores militares e o portão de controle.","Avance pelos pátios até a grande entrada da mineradora.","Entre nas cavernas industriais e atravesse o complexo subterrâneo."]
const STAGE_DISTRICTS := [
 ["Portão monumental","Muralha externa","Rua de acesso","Pátio das bandeiras","Torres de vigia","Defesas da capital","Arcadas iluminadas","Terraço da cidade"],
 ["Lajes da muralha","Casario elevado","Terraços de tecido","Telhados separados","Cúpulas vermelhas","Torres da capital","Coberturas antigas","Terraço do mercado"],
 ["Praça dos tecidos","Rua dos mercadores","Corredor de arcos","Depósitos de especiarias","Pátio comercial","Bancas de cerâmica","Galerias de carga","Saída do mercado"],
 ["Ponte de acesso","Arcos monumentais","Canal superior","Colunas de água","Ponte avariada","Travessia das cascatas","Reservatório","Saída para o oásis"],
 ["Palmeiras do reino","Margem iluminada","Jardins de pedra","Fontes antigas","Pontes do jardim","Pátio verde","Ribeirão noturno","Arco das ruínas"],
 ["Monumento enterrado","Colunas antigas","Câmara da areia","Arcos partidos","Galeria subterrânea","Pátio soterrado","Passagem de rochas","Saída do complexo"],
 ["Armazém de carga","Estrada rochosa","Ponte de madeira","Desfiladeiro","Torre de observação","Equipamentos de transporte","Trilhos de carga","Passagem militar"],
 ["Posto avançado","Pátio de vigia","Muralhas defensivas","Torres dos guardas","Depósito militar","Travessia fortificada","Grande portão","Estrada da mineradora"],
 ["Estrada de minério","Ponte de transporte","Depósitos externos","Pátio dos carrinhos","Guindastes de carga","Instalações de pedra","Aproximação da entrada","Portal da mineradora"],
 ["Galeria de entrada","Trilhos subterrâneos","Passarelas de madeira","Câmara dos cristais","Poço industrial","Guindastes internos","Galeria profunda","Coração da mineração"]]

static func metadata(order: int) -> Dictionary:
	if order < 1 or order > 10: return {}
	return {"id":"desert_phase_%02d" % order,"order":order,"name":NAMES[order-1],"description":DESCRIPTIONS[order-1],"theme":THEMES[order-1]}

static func build(order: int, minimum_seconds: float = 180.0) -> Dictionary:
	var stage := metadata(order)
	if stage.is_empty(): return {}
	var distance := maxf(DEFAULT_DISTANCE,ceilf(maxf(180,minimum_seconds)*MAX_HORIZONTAL_SPEED)+120)
	var spawn_x := -8.0
	var goal_x := spawn_x+distance
	var platforms: Array = []
	var holes: Array = []
	var enemies: Array = []
	var pickups: Array = []
	var checkpoints: Array = []
	var districts: Array = []
	var landmarks: Array = []
	var surfaces: Array = []
	var prefix := "p%02d" % order
	var modules: int = [48,72,56,48,48,56,48,56,48,48][order-1]
	var sector_modules := modules/8
	var module_length := (distance+(6.0 if order == 2 else 26.0))/modules
	var origin := spawn_x-(2.0 if order == 2 else 8.0)
	for index in range(modules):
		var left := origin+index*module_length
		var right := origin+(index+1)*module_length
		var top := _height(order,index)
		var next_top := _height(order,mini(index+1,modules-1))
		var gap := 0.0 if index == modules-1 else (2.3+0.18*float(index%6))
		if index%4 == 0 and order != 2: gap = 1.8
		var end := right-gap
		var district := mini(7,index/sector_modules)
		surfaces.append({"left":left,"right":end,"height":top,"index":index})
		# Peça central de3m independente; todas as outras mantêm colisão ao romper.
		var crack := left+(end-left)*0.62
		var bounds := [left,crack-1.5,crack+1.5,end]
		for segment in range(3):
			var x0: float = bounds[segment]
			var x1: float = bounds[segment+1]
			platforms.append({"id":"%s.surface.%02d.%d" % [prefix,index,segment],"kind":"ground","pos":[(x0+x1)*0.5,top-0.5,0],"size":[x1-x0,1.0,4.0],"span_start":x0,"span_end":x1,"chunk":floori((x0+x1)*0.5/64.0),"breakable":segment == 1 and index%3 == 1,"module":index,"district":district,"surface_top":top,"architecture":THEMES[order-1]})
		if gap > 0:
			holes.append({"id":"%s.gap.%02d" % [prefix,index],"start":end,"end":right,"width":gap,"from_y":top,"to_y":next_top,"stepping":false,"ferry":false})
		# Guarda e itens pertencem à mesma laje. Recargas antecipam desafios;
		# nenhuma é colocada em abismo, sobre obstáculo ou na peça destrutível.
		var guard_x := left+(3.8 if order == 2 else (23.0 if index == 0 else 10.0))
		if index%(6 if order == 2 else 2) == 0 and not (order == 2 and index == 0):
			enemies.append({"id":"%s.cactus.%02d" % [prefix,index],"type":"cactus","pos":[guard_x,top+0.02,0],"patrol":[left+1,end-1],"district":district})
		var supply_index := index/3 if order == 2 else index
		var kind: String = ["attack","defense","attack","health"][supply_index%4]
		if order != 2 or index%3 == 0:
			pickups.append({"id":"%s.supply.%02d" % [prefix,index],"kind":kind,"pos":[spawn_x+2 if index == 0 and order == 2 else (spawn_x+4 if index == 0 else left+(7.0 if order == 2 else 8)),top,0],"surface":index})
		for ability: String in ["rupture","amber","dash"]:
			if order < {"rupture":2,"amber":4,"dash":6}[ability]: continue
			if index%(24 if order == 2 else 8) == ({"rupture":1,"amber":9,"dash":17}[ability] if order == 2 else {"rupture":1,"amber":3,"dash":5}[ability]):
				pickups.append({"id":"%s.%s.%02d" % [prefix,ability,index],"kind":ability,"pos":[left+(3.6 if order == 2 else 12),top,0],"surface":index})
		# Obstáculos baixos são caixas/balaustradas integradas ao módulo, não escadas.
		if order != 2 and index > 0 and index%3 == 2:
			var height := 0.5 if order == 2 else 0.6
			platforms.append({"id":"%s.obstacle.%02d" % [prefix,index],"kind":"ledge","pos":[left+module_length*0.76,top+height*0.5,0],"size":[0.9,height,2.6],"span_start":left+module_length*0.76-0.45,"span_end":left+module_length*0.76+0.45,"chunk":floori(left/64),"architecture":THEMES[order-1],"surface_top":top})
	for index in range(8):
		var module := index*sector_modules
		var floor: Dictionary = surfaces[module]
		var start := spawn_x+distance*index/8.0
		districts.append({"id":"%s.district.%d" % [prefix,index],"name":STAGE_DISTRICTS[order-1][index],"start":start,"end":spawn_x+distance*(index+1)/8.0,"theme":THEMES[order-1]})
		landmarks.append({"id":"%s.landmark.%d" % [prefix,index],"kind":"district_gate","pos":[float(floor.left)+1.0,float(floor.height),-5.0],"theme":THEMES[order-1]})
		if index > 0: checkpoints.append({"id":"%s.checkpoint.%d" % [prefix,index],"district":index,"pos":[float(floor.left)+1.3,float(floor.height),0]})
	for platform: Dictionary in platforms:
		if not platform.get("breakable",false): continue
		for item: Dictionary in pickups+checkpoints:
			if float(item.pos[0])>=float(platform.span_start)-0.8 and float(item.pos[0])<=float(platform.span_end)+0.8: platform.breakable=false
	# Mantém Malagueta e seu modelo/animações originais no fim do percurso10.
	# Abastecimento de arena ocupa toda a laje final, não um item sobreposto ao chefe.
	if order == 10:
		var arena: Dictionary = surfaces[-1]
		pickups = pickups.filter(func(item: Dictionary) -> bool: return float(item.pos[0]) < float(arena.left))
		for index in range(8):
			pickups.append({"id":"p10.arena.attack.%d" % index,"kind":"attack","pos":[float(arena.left)+1.0+index*3.4,float(arena.height),0],"surface":47})
	var goal_top: float = surfaces[-1].height
	stage.merge({"protagonist":"el_fuego","player_spawn":[spawn_x,_height(order,0)+0.1,0],"length":distance,"total_length":distance,"minimum_seconds":180.0,"minimum_traversal_seconds":(distance-1)/MAX_HORIZONTAL_SPEED,"transport_allowance":0.0,"maximum_horizontal_speed":MAX_HORIZONTAL_SPEED,"platforms":platforms,"enemies":enemies,"pickups":pickups,"holes":holes,"signs":[],"districts":districts,"landmarks":landmarks,"checkpoints":checkpoints,"geysers":[],"storms":[],"surfaces":surfaces,"goal":{"pos":[goal_x,goal_top+1.5,0]},"kill_plane_y":-10.0 if order == 2 else -12.0,"boss_id":"malagueta" if order == 10 else null,"legacy_placeholder_visuals":false,"bounds":{"min_x":origin,"max_x":goal_x+10.0},"next_scene":"res://scenes/desert/phase_%02d.tscn" % (order+1) if order < 10 else "","reach":{"max_gap":3.2,"single_jump_max_step_top":0.65,"double_jump_max_step_top":1.3}},true)
	if order == 10:
		stage.boss = {"id":"p10.malagueta","pos":[goal_x-4.0,goal_top+0.02,0],"patrol":[goal_x-8.0,goal_x+8.0]}
	return stage

static func _height(order: int,index: int) -> float:
	var pattern: float = [0.0,0.4,0.8,0.3,0.7,0.2][index%6]
	match order:
		2: return 8.0+pattern
		4: return 3.5+pattern*0.6
		6: return -1.8+pattern
		7: return pattern*1.2
		10: return -2.0+pattern
	return pattern*0.5

static func floor_at(stage: Dictionary,x: float) -> Dictionary:
	for surface: Dictionary in stage.surfaces:
		if x >= float(surface.left) and x <= float(surface.right): return surface
	return {}
