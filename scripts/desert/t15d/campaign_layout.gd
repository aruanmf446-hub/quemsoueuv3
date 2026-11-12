extends RefCounted
## Percursos modulares mundiais: cada superfície, item e patrulha compartilha sua altura real.
const ABILITY_PHASE := {"amber":3,"dash":4,"rupture":5}
const MAX_HORIZONTAL_SPEED := 7.4
const DEFAULT_DISTANCE := 1452.0
const CHUNK_LENGTH := 24.0
const TASK_MIN_GAP := 18.0
const TASK_GATE_HEIGHT := 5.2
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
	var tasks: Array = []
	var prefix := "p%02d" % order
	var modules: int = [48,120,56,48,48,56,48,56,48,48][order-1]
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
		if order<10 and index<modules-1:
			var patterns: Array=[
				[1.8,2.2,2.6,2.0,2.8,2.2],[1.8,2.4,3.0,2.2,2.8,2.0],
				[1.8,2.0,2.4,1.8,2.6,2.2],[2.2,2.8,3.1,2.4,2.9,2.0],
				[1.8,2.2,2.8,2.0,2.6,1.8],[2.0,2.4,2.8,2.2,3.0,2.0],
				[2.2,3.0,2.6,3.1,2.4,2.8],[1.8,2.6,2.2,2.8,2.0,2.4],
				[2.0,2.8,3.0,2.2,2.6,3.1]]
			gap=float(patterns[order-1][index%6])
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
			var crumble := order < 10 and index in [floori(modules*0.3),floori(modules*0.7)]
			holes.append({"id":"%s.gap.%02d" % [prefix,index],"start":end,"end":right,"width":gap,"from_y":top,"to_y":next_top,"stepping":false,"ferry":false,"crumble_bridge":crumble,"earth_bridge":false})
		# Guarda e itens pertencem à mesma laje. Recargas antecipam desafios;
		# nenhuma é colocada em abismo, sobre obstáculo ou na peça destrutível.
		# Ritmo: a partir da fase 3 guarda, recarga e poder não caem sempre no mesmo metro da laje.
		var varied := order >= 3 and order < 10 and index > 0
		var supply_offset: float = [8.0,5.5,10.5,6.5,11.0,4.5][(index+order)%6] if varied else 8.0
		var guard_x := left+(6.0 if order == 2 else (23.0 if index == 0 else (float([13.0,18.0,9.5,21.0,15.0][(index/2+order)%5]) if varied else 13.0)))
		if index%(10 if order == 2 else 2) == 0 and not (order == 2 and index == 0):
			enemies.append({"id":"%s.cactus.%02d" % [prefix,index],"type":"cactus","pos":[guard_x,top+0.02,0],"patrol":[left+1,end-1],"district":district,"challenger":order<10,"elite":order in [3,5,7,8,9] and index%12==6})
		var supply_index := index/5 if order == 2 else index
		var kind: String = ["attack","defense","attack","health"][supply_index%4]
		if order != 2 or index%5 == 0:
			pickups.append({"id":"%s.supply.%02d" % [prefix,index],"kind":kind,"pos":[spawn_x+2 if index == 0 and order == 2 else (spawn_x+4 if index == 0 else left+(7.0 if order == 2 else supply_offset)),top,0],"surface":index})
		for ability: String in ["rupture","amber","dash"]:
			if order < ABILITY_PHASE[ability]: continue
			if index%(24 if order == 2 else 8) == ({"rupture":1,"amber":9,"dash":17}[ability] if order == 2 else {"rupture":1,"amber":3,"dash":5}[ability]):
				pickups.append({"id":"%s.%s.%02d" % [prefix,ability,index],"kind":ability,"pos":[left+(3.6 if order == 2 else (14.5 if supply_offset > 9.0 else 12.0)),top,0],"surface":index})
		# Patamares e obstáculos apoiados na mesma superfície do módulo.
		var stair_run := index%sector_modules == (3 if order==10 else mini(sector_modules-2,[3,4,4,3,2,4,3,5,3][order-1]+int(index/sector_modules)%2))
		if order==2: stair_run=false # O teto da própria casa é a rota, sem plataforma sobreposta.
		if order==10 and index>=modules/2: stair_run=false # Arena final preservada.
		if stair_run:
			var shapes: Array=[[0.0,5.6,1.1]]
			if order==1:shapes=[[-1.6,3.2,0.60],[1.6,3.2,1.1]]
			if order in [5,6]:shapes=[[-2.3,2.4,0.55],[0.0,2.4,1.1],[2.3,2.4,0.55]]
			if order in [7,9]:shapes=[[-1.4,2.8,0.55],[1.4,2.8,1.1]]
			var center:=end-5.2 if order<10 else left+module_length*0.5
			for step in shapes.size():
				var spec: Array=shapes[step]
				var route_x:=center+float(spec[0])
				var route_width:=float(spec[1])
				var route_top:=top+float(spec[2])
				var route_id:="%s.route.%02d" % [prefix,index] if shapes.size()==1 else "%s.route.%02d.%d" % [prefix,index,step]
				platforms.append({"id":route_id,"kind":"route","pos":[route_x,route_top-0.10,0],"size":[route_width,0.20,3.8],"span_start":route_x-route_width*0.5,"span_end":route_x+route_width*0.5,"module":index,"architecture":THEMES[order-1],"surface_top":top,"parkour_route":true})
		if not stair_run and index > 0 and order != 2 and index%3 == 2:
			var height := 0.5 if order == 2 else 0.6
			platforms.append({"id":"%s.obstacle.%02d" % [prefix,index],"kind":"ledge","pos":[left+module_length*0.55,top+height*0.5,0],"size":[0.9,height,2.6],"span_start":left+module_length*0.55-0.45,"span_end":left+module_length*0.55+0.45,"chunk":floori(left/64),"architecture":THEMES[order-1],"surface_top":top})
	for index in range(8):
		var module := index*sector_modules
		var floor: Dictionary = surfaces[module]
		var start := spawn_x+distance*index/8.0
		districts.append({"id":"%s.district.%d" % [prefix,index],"name":STAGE_DISTRICTS[order-1][index],"start":start,"end":spawn_x+distance*(index+1)/8.0,"theme":THEMES[order-1]})
		landmarks.append({"id":"%s.landmark.%d" % [prefix,index],"kind":"district_gate","pos":[float(floor.left)+1.0,float(floor.height),-5.0],"theme":THEMES[order-1]})
		if index > 0: checkpoints.append({"id":"%s.checkpoint.%d" % [prefix,index],"district":index,"pos":[float(floor.left)+1.3,float(floor.height),0]})
	# Mantém Malagueta e seu modelo/animações originais no fim do percurso10.
	# Abastecimento de arena ocupa toda a laje final, não um item sobreposto ao chefe.
	if order == 10:
		var arena: Dictionary = surfaces[-1]
		var supply_room: Dictionary = surfaces[-2]
		pickups=pickups.filter(func(item: Dictionary)->bool:return float(item.pos[0])<float(supply_room.left) or float(item.pos[0])>float(supply_room.right))
		for index in range(6):
			var kind: String=["attack","health","attack","amber","attack","attack"][index]
			pickups.append({"id":"p10.preparation.%d" % index,"kind":kind,"pos":[float(supply_room.left)+3+index*4.0,float(supply_room.height),0],"surface":46})
		pickups = pickups.filter(func(item: Dictionary) -> bool: return float(item.pos[0]) < float(arena.left))
		for index in range(12):
			pickups.append({"id":"p10.arena.attack.%d" % index,"kind":"attack","pos":[float(arena.left)+1.0+index*2.4,float(arena.height),0],"surface":47})
	for platform: Dictionary in platforms:
		if not platform.get("breakable",false): continue
		for item: Dictionary in pickups+checkpoints:
			if float(item.pos[0])>=float(platform.span_start)-0.8 and float(item.pos[0])<=float(platform.span_end)+0.8: platform.breakable=false
	# Duas intervenções próprias do cenário; na fase final, uma antes da arena.
	var plans: Array = [
	 [["gate","Abrir portão da capital"],["bridge","Baixar ponte da muralha"]],
	 [["bridge","Estender passarela dos telhados"],["lift","Içar plataforma de manutenção"]],
	 [["bridge","Estender toldo do mercado"],["gate","Liberar depósito de especiarias"]],
	 [["gate","Abrir comporta do aqueduto"],["bridge","Reconstruir passagem do canal"]],
	 [["bridge","Reposicionar tronco do oásis"],["gate","Abrir passagem dos jardins"]],
	 [["lift","Alinhar laje das ruínas"],["gate","Abrir portal antigo"]],
	 [["lift","Acionar plataforma de carga"],["bridge","Baixar viga do desfiladeiro"]],
	 [["gate","Abrir portão do posto"],["bridge","Baixar passarela de vigia"]],
	 [["lift","Acionar guindaste de minério"],["gate","Liberar portão de serviço"]],
	 [["lift","Içar passarela da galeria"]]
	][order-1]
	for i in plans.size():
		var module := 7 if i==0 else floori(modules*0.58)
		var floor: Dictionary=surfaces[module]
		# A área de operação da Task fica livre de balcões/caixas aleatórios.
		platforms=platforms.filter(func(p: Dictionary) -> bool:return int(p.get("module",-1))!=module or p.kind=="ground")
		var kind: String=plans[i][0]
		var data: Dictionary
		if kind=="gate":
			var x := float(floor.left)+module_length*0.77
			data={"start":x-1.2,"end":x+1.2,"from_y":floor.height,"to_y":floor.height}
		else:
			data=holes[module].duplicate(true)
			data.crumble_bridge=false
			holes[module].crumble_bridge=false
			var landing := module+1
			while float(surfaces[landing].left)-float(data.start)<TASK_MIN_GAP:
				surfaces[landing].task_void=true
				landing+=1
			data.end=surfaces[landing].left
			data.to_y=surfaces[landing].height
			holes[module].end=data.end
			holes[module].to_y=data.to_y
			holes[module].width=float(data.end)-float(data.start)
			holes[module].requires_task=true
		data.merge({"id":"%s.task.%d" % [prefix,i],"task_kind":kind,"task_text":plans[i][1],"theme":order,"width":float(data.end)-float(data.start)})
		var actions: Array=[
			[["Acionar portão"],["Destravar guincho","Baixar passarela"]],
			[["Soltar passarela","Fixar ancoragem"],["Prender cabo","Içar plataforma"]],
			[["Prender tecido","Esticar toldo"],["Liberar trinco","Abrir depósito"]],
			[["Fechar alimentação","Abrir comporta"],["Fixar apoio","Montar passagem"]],
			[["Soltar amarra","Reposicionar tronco"],["Soltar trava","Abrir passagem"]],
			[["Liberar contrapeso","Alinhar laje"],["Destravar selo","Abrir portal"]],
			[["Prender carga","Acionar elevador"],["Soltar viga","Baixar travessia"]],
			[["Liberar ferrolho","Erguer portão"],["Prender cabo","Baixar passarela"]],
			[["Engatar minério","Acionar guindaste"],["Destravar trilho","Abrir portão"]],
			[["Içar passarela"]]][order-1][i]
		data.actions=actions
		data.operation_span=[floor.left,floor.right]
		data.width=float(data.end)-float(data.start)
		tasks.append(data)
	# Retira de fato piso, atores e decoração dentro da passagem que depende da Task.
	for task: Dictionary in tasks:
		if task.task_kind=="gate":continue
		platforms=platforms.filter(func(p: Dictionary) -> bool:return float(p.pos[0])<=float(task.start) or float(p.pos[0])>=float(task.end))
		pickups=pickups.filter(func(p: Dictionary) -> bool:return float(p.pos[0])<=float(task.start) or float(p.pos[0])>=float(task.end))
		enemies=enemies.filter(func(p: Dictionary) -> bool:return float(p.pos[0])<=float(task.start) or float(p.pos[0])>=float(task.end))
		holes=holes.filter(func(h: Dictionary) -> bool:return float(h.start)<=float(task.start) or float(h.start)>=float(task.end))
	var goal_top: float = surfaces[-1].height
	# Lanceiros espaçados entre começo, meio e fim; fases 2/3 preservadas sem eles.
	var spear_counts:={1:3,4:2,5:2,6:3,7:2,8:4,9:3}
	if spear_counts.has(order):
		var supplies: Array=pickups.filter(func(p: Dictionary) -> bool:
			var floor: Dictionary=surfaces[int(p.surface)]
			return p.kind=="defense" and not floor.get("task_void",false) and float(p.pos[0])+8.0<float(floor.right)-1.2)
		var count:=mini(int(spear_counts[order]),supplies.size())
		for n in count:
			var selection:=roundi(float(n)*(supplies.size()-1)/maxi(1,count-1))
			var item: Dictionary=supplies[selection]
			var floor: Dictionary=surfaces[int(item.surface)]
			var tutorial:=order==1 and n==0
			var sx:=float(item.pos[0])+(5.5 if tutorial else 8.0)
			# Evita somar um atacante corpo a corpo ao mesmo disparo surpresa.
			enemies=enemies.filter(func(e: Dictionary) -> bool:return absf(float(e.pos[0])-sx)>(18.0 if tutorial else 5.0))
			enemies.append({"id":prefix+".spear."+str(n+1),"type":"cactus","pos":[sx,float(floor.height)+0.02,0],"patrol":[sx-0.2,sx+0.2],"spear":true,"spear_supply":str(item.id) if tutorial else "","spear_tutorial":tutorial,"district":int(item.surface)/sector_modules})
	stage.merge({"protagonist":"el_fuego","player_spawn":[spawn_x,_height(order,0)+0.1,0],"length":distance,"total_length":distance,"minimum_seconds":180.0,"minimum_traversal_seconds":(distance-1)/MAX_HORIZONTAL_SPEED,"transport_allowance":0.0,"maximum_horizontal_speed":MAX_HORIZONTAL_SPEED,"tasks":tasks,"platforms":platforms,"enemies":enemies,"pickups":pickups,"holes":holes,"signs":[],"districts":districts,"landmarks":landmarks,"checkpoints":checkpoints,"geysers":[],"storms":[],"surfaces":surfaces,"goal":{"pos":[goal_x,goal_top+1.5,0]},"kill_plane_y":-10.0 if order == 2 else -12.0,"boss_id":"malagueta" if order == 10 else null,"legacy_placeholder_visuals":false,"bounds":{"min_x":origin,"max_x":goal_x+10.0},"next_scene":"res://scenes/desert/phase_%02d.tscn" % (order+1) if order < 10 else "","reach":{"max_gap":3.2,"single_jump_max_step_top":0.65,"double_jump_max_step_top":1.3}},true)
	if order == 10:
		stage.boss = {"id":"p10.malagueta","pos":[goal_x-4.0,goal_top+0.02,0],"patrol":[goal_x-8.0,goal_x+8.0]}
	return stage

static func _height(order: int,index: int) -> float:
	var pattern: float = [0.0,0.4,0.8,0.3,0.7,0.2][index%6]
	# Sequências de subida, patamar e descida. Degraus entre prédios continuam <=0,55m.
	if order < 10:
		var profiles: Array=[
			[0.0,0.0,0.35,0.7,0.7,0.35,0.0,0.0,0.35,0.35,0.0,0.0],
			[0.0,0.45,0.9,0.9,1.35,1.8,1.8,1.35,0.9,0.9,0.45,0.0],
			[0.0,0.35,0.35,0.0,0.0,0.45,0.9,0.9,0.45,0.0,0.0,0.0],
			[0.0,0.5,1.0,1.5,2.0,2.5,2.5,2.0,1.5,1.0,0.5,0.0],
			[0.0,0.3,0.6,0.9,0.6,0.3,0.0,0.0,0.35,0.7,0.35,0.0],
			[0.0,-0.45,-0.9,-1.35,-1.8,-1.8,-1.35,-0.9,-0.45,0.0,0.45,0.0],
			[0.0,0.5,1.0,1.5,1.5,1.0,0.5,0.0,-0.5,-1.0,-0.5,0.0],
			[0.0,0.55,1.1,1.65,2.2,2.75,2.75,2.2,1.65,1.1,0.55,0.0],
			[1.8,1.35,0.9,0.45,0.0,-0.45,-0.9,-0.9,-0.45,0.0,0.45,0.9,1.35,1.8]]
		var climb: float=profiles[order-1][index%profiles[order-1].size()]
		var base := 8.0 if order == 2 else (3.5 if order == 4 else (-1.8 if order == 6 else 0.0))
		return base+climb
	match order:
		2: return 8.0+pattern
		4: return 3.5+pattern*0.6
		6: return -1.8+pattern
		7: return pattern*1.2
		10: return -2.0+pattern
	return pattern*0.5

static func floor_at(stage: Dictionary,x: float) -> Dictionary:
	for surface: Dictionary in stage.surfaces:
		if surface.get("task_void",false):continue
		if x >= float(surface.left) and x <= float(surface.right): return surface
	return {}
