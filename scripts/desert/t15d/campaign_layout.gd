extends RefCounted
## Campanha noturna 01–09. Dados determinísticos separados do controlador e da Fase 10.
## O percurso mínimo vem da distância real: não há bloqueio por relógio nem espera na saída.
const MAX_HORIZONTAL_SPEED := 6.0
const DEFAULT_DISTANCE := 1200.0
const CHUNK_LENGTH := 24.0
const NAMES := [
	"Entrada do Deserto", "Dunas Perdidas", "Oásis da Meia-Noite",
	"Ruínas Esquecidas", "Pontes do Abismo", "Tempestade de Areia",
	"Fortaleza dos Cactus", "Cavernas de Cristal", "Laboratório Proibido",
]
const THEMES := [
	"gates", "dunes_streets", "oasis_quarter", "ruined_quarter", "bridges",
	"sand_lanes", "cactus_fortress", "crystal_galleries", "forbidden_district",
]
const DESCRIPTIONS := [
	"Atravesse os portões e as primeiras ruas da cidade no deserto, sob a luz da lua.",
	"Siga pelas ruas cobertas de areia entre muros antigos e passagens abertas no chão.",
	"Atravesse o bairro do oásis à meia-noite e encontre a passagem para o centro da cidade.",
	"Percorra o bairro das ruínas, entre pátios de pedra e arcos iluminados pela noite.",
	"Atravesse as pontes e os vãos que dividem os distritos da cidade adormecida.",
	"Avance pelas vielas tomadas pela areia e atravesse os desníveis do distrito noturno.",
	"Cruze os pátios da fortaleza e enfrente os Cactus que guardam a rota urbana.",
	"Percorra as galerias da cidade e suas passagens de pedra até o distrito seguinte.",
	"Alcance o distrito proibido e a entrada do laboratório, no coração da cidade noturna.",
]
const DISTRICT_LABELS := ["Portões", "Ruas da Areia", "Pátio Antigo", "Passagens", "Mercado", "Muralhas", "Galerias", "Saída"]

static func metadata(order: int) -> Dictionary:
	if order < 1 or order > 9: return {}
	return {
		"id": "desert_phase_%02d" % order,
		"order": order,
		"name": NAMES[order-1],
		"description": DESCRIPTIONS[order-1],
		"theme": THEMES[order-1],
	}

static func build(order: int, minimum_seconds: float = 180.0) -> Dictionary:
	var stage := metadata(order)
	if stage.is_empty(): return {}
	# Reserva 20 segundos além do piso pedido: aceleração, colisão da saída e qualquer
	# margem de entrada não podem baixar uma fase de 180s para menos de três minutos.
	var requested_seconds := maxf(minimum_seconds,180.0)
	var distance := maxf(DEFAULT_DISTANCE,ceilf(requested_seconds*MAX_HORIZONTAL_SPEED)+120.0)
	var spawn_x := -8.0
	var goal_x := spawn_x+distance
	var pit_count := mini(14+order-1,20)
	var enemy_count := mini(14+order-1,20)
	var pits: Array = []
	var spans: Array = []
	var platforms: Array = []
	var enemies: Array = []
	var pickups: Array = []
	var signs: Array = []
	var districts: Array = []
	var landmarks: Array = []
	var checkpoints: Array = []
	var geysers: Array = []
	var prefix := "p%02d" % order
	var left := spawn_x-8.0
	# As distâncias normais são 57–84m entre vãos, com variação de posição/largura.
	# A mesma passagem é alcançável nos dois sentidos, sem plataformas de mão única.
	for index in range(pit_count):
		var normalized := float(index)/maxf(float(pit_count-1),1.0)
		var jitter: float = [2.0,-3.0,4.0,-1.0,0.0,3.0,-2.0][(index+order)%7]
		var center := lerpf(spawn_x+62.0,goal_x-48.0,normalized)+jitter
		var width := 3.0+float((index+order)%3)*0.25
		# Vão largo com pedra no meio que desmorona: dois saltos rápidos em vez de um.
		var stepping := index > 0 and (index*3+order)%5 == 1
		# Pulo normal saindo da borda pousa na pedra (2,4m larga, 2,5m de cada borda).
		if stepping: width = 7.4
		var pit_left := center-width*0.5
		var pit_right := center+width*0.5
		spans.append({"left":left,"right":pit_left})
		pits.append({"id":"%s.pit.%02d" % [prefix,index],"start":pit_left,"end":pit_right,"width":width,"stepping":stepping})
		if stepping:
			platforms.append({"id":"%s.crumble.%02d" % [prefix,index],"kind":"crumble","pos":[center,-0.3,0.0],"size":[2.4,0.6,3.0],"span_start":center-1.2,"span_end":center+1.2,"chunk":floori(center/CHUNK_LENGTH)})
		signs.append({"id":"%s.pit.%02d.left" % [prefix,index],"kind":"pit_warning","pos":[pit_left-5.0,0.0,-1.5],"direction":1})
		signs.append({"id":"%s.pit.%02d.right" % [prefix,index],"kind":"pit_warning","pos":[pit_right+5.0,0.0,-1.5],"direction":-1})
		left = pit_right
	spans.append({"left":left,"right":goal_x+10.0})
	var defense_slots := {}
	for index in range(12):
		defense_slots[roundi(float(index)*float(enemy_count-1)/11.0)] = true
	var extra_attack_slots := [maxi(2,enemy_count/4),enemy_count/2,enemy_count-2]
	for index in range(spans.size()):
		var span: Dictionary = spans[index]
		var span_left := float(span.left)
		var span_right := float(span.right)
		var span_width := span_right-span_left
		_ground(platforms,prefix,index,span_left,span_right)
		if index >= enemy_count: continue
		var variation := float((index+order)%3-1)*1.0
		var enemy_x := span_left+span_width*0.40+variation
		enemy_x = clampf(enemy_x,span_left+minf(14.0,span_width*0.3),span_right-minf(18.0,span_width*0.3))
		enemies.append({
			"id":"%s.cactus.%02d" % [prefix,index],"type":"cactus",
			"pos":[enemy_x,0.02,0.0],
			"patrol":[maxf(span_left+7.0,enemy_x-4.0),minf(span_right-10.0,enemy_x+4.0)],
			"district":clampi(int((enemy_x-spawn_x)/(distance/8.0)),0,7),
		})
		# A primeira carga vem do inventário inicial. A reposição fica depois do Cactus,
		# em piso livre; também pode ser alcançada saltando sobre ele e voltando.
		pickups.append({"id":"%s.attack.%02d" % [prefix,index],"kind":"attack","pos":[enemy_x+6.0,0.55,0.0]})
		if index in extra_attack_slots:
			pickups.append({"id":"%s.attack.extra.%02d" % [prefix,index],"kind":"attack","pos":[enemy_x-5.0,0.55,0.0]})
		# Recarga de vida: um coração a cada três trechos, entre o Cactus e os degraus.
		if index % 3 == 1:
			pickups.append({"id":"%s.health.%02d" % [prefix,index],"kind":"health","pos":[span_left+span_width*0.58,0.55,0.0]})
		if defense_slots.has(index):
			pickups.append({"id":"%s.defense.%02d" % [prefix,index],"kind":"defense","pos":[enemy_x-9.0,0.55,0.0]})
		# Os degraus ficam fora do espaço de duelo/reposição e a pelo menos 8m do vão.
		# Módulos alternam pátio aberto, degrau baixo, degrau largo e salto duplo.
		var pattern := (index+order*3)%7
		# Peças de parkour que se revezam com os degraus: telhados em escada e muralha com gêiser.
		var piece := (index*5+order*2)%6
		if span_width >= 50.0 and index > 0 and piece == 0:
			var center_x := span_left+span_width*0.74
			for step in range(3):
				_ledge(platforms,prefix,index,step,center_x+(step-1)*3.8,2.6,[1.0,1.9,2.6][step])
		elif span_width >= 50.0 and index > 0 and piece == 3:
			var wall_x := span_left+span_width*0.74
			platforms.append({"id":"%s.wall.%02d" % [prefix,index],"kind":"geyser_wall","pos":[wall_x,2.1,0.0],"size":[2.4,4.2,3.0],"span_start":wall_x-1.2,"span_end":wall_x+1.2,"chunk":floori(wall_x/CHUNK_LENGTH)})
			for side in [-1.0,1.0]:
				geysers.append({"id":"%s.geyser.%02d.%s" % [prefix,index,"l" if side < 0 else "r"],"pos":[wall_x+side*4.2,0.0,0.0]})
		elif span_width >= 48.0 and pattern != 4:
			var ledge_x := span_left+span_width*0.74
			var height: float = [1.2,2.7,1.3,1.3,0.0,2.5,1.0][pattern]
			var width: float = [3.4,3.2,3.6,5.0,0.0,3.4,3.8][pattern]
			_ledge(platforms,prefix,index,0,ledge_x,width,height)
			if pattern == 2 and span_width >= 64.0:
				# Duas elevações no mesmo pátio, com topos que aceitam o retorno.
				platforms.pop_back()
				_ledge(platforms,prefix,index,0,span_left+span_width*0.66,3.0,1.2)
				_ledge(platforms,prefix,index,1,span_left+span_width*0.82,3.2,1.3)
	for index in range(8):
		var start := spawn_x+distance*float(index)/8.0
		var end := spawn_x+distance*float(index+1)/8.0
		var district_theme: String = THEMES[(order-1+index)%THEMES.size()]
		districts.append({"id":"%s.district.%02d" % [prefix,index],"index":index,"name":DISTRICT_LABELS[index],"start":start,"end":end,"theme":district_theme})
		var landmark_x := _safe_floor_x(start+12.0,pits)
		landmarks.append({"id":"%s.landmark.%02d" % [prefix,index],"kind":"district_gate","pos":[landmark_x,0.0,-4.5],"theme":district_theme})
		# Checkpoint no começo de cada distrito (menos o primeiro, que é o spawn), em chão
		# firme: fora de vãos e degraus e longe da patrulha dos Cactus.
		if index > 0:
			checkpoints.append({"id":"%s.checkpoint.%02d" % [prefix,index],"district":index,"pos":[_checkpoint_x(start+4.0,pits,platforms,enemies),0.0,0.0]})
	stage.merge({
		"protagonist":"el_fuego","player_spawn":[spawn_x,1.0,0.0],
		"length":distance,"total_length":distance,"minimum_seconds":requested_seconds,
		"minimum_traversal_seconds":(distance-1.0)/MAX_HORIZONTAL_SPEED,
		"maximum_horizontal_speed":MAX_HORIZONTAL_SPEED,
		"platforms":platforms,"enemies":enemies,"pickups":pickups,"holes":pits,
		"signs":signs,"districts":districts,"landmarks":landmarks,
		"checkpoints":checkpoints,"geysers":geysers,"goal":{"pos":[goal_x,1.5,0.0]},
		"kill_plane_y":-8.0,"boss_id":null,"legacy_placeholder_visuals":false,
		"bounds":{"min_x":spawn_x-8.0,"max_x":goal_x+10.0},
		"next_scene":"res://scenes/desert/phase_%02d.tscn" % (order+1),
		"reach":{"max_gap":3.5,"single_jump_max_step_top":1.3,"double_jump_max_step_top":2.7},
	},true)
	return stage

static func _ground(platforms: Array, prefix: String, span: int, left: float, right: float) -> void:
	var pieces := maxi(1,ceili((right-left)/CHUNK_LENGTH))
	for piece in range(pieces):
		var x0 := lerpf(left,right,float(piece)/pieces)
		var x1 := lerpf(left,right,float(piece+1)/pieces)
		platforms.append({
			"id":"%s.ground.%02d.%02d" % [prefix,span,piece],
			"kind":"ground","pos":[(x0+x1)*0.5,-0.5,0.0],"size":[x1-x0,1.0,4.0],
			"span_start":x0,"span_end":x1,"chunk":floori(((x0+x1)*0.5)/CHUNK_LENGTH),
		})

static func _ledge(platforms: Array, prefix: String, span: int, index: int, x: float, width: float, height: float) -> void:
	platforms.append({
		"id":"%s.ledge.%02d.%02d" % [prefix,span,index],
		"kind":"ledge_high" if height > 1.5 else "ledge",
		"pos":[x,height*0.5,0.0],"size":[width,height,3.0],
		"span_start":x-width*0.5,"span_end":x+width*0.5,"chunk":floori(x/CHUNK_LENGTH),
	})

static func _checkpoint_x(value: float, holes: Array, platforms: Array, enemies: Array) -> float:
	var x := value
	for attempt in range(40):
		var blocked := false
		for hole: Dictionary in holes:
			if x >= float(hole.start)-3.0 and x <= float(hole.end)+3.0: blocked = true
		for platform: Dictionary in platforms:
			var margin := 6.0 if platform.kind == "geyser_wall" else 1.5
			if platform.kind != "ground" and absf(x-float(platform.pos[0])) <= float(platform.size[0])*0.5+margin: blocked = true
		for enemy: Dictionary in enemies:
			if x >= float(enemy.patrol[0])-7.0 and x <= float(enemy.patrol[1])+7.0: blocked = true
		if not blocked: return x
		x += 2.0
	return x

static func _safe_floor_x(value: float, holes: Array) -> float:
	for hole: Dictionary in holes:
		if value >= float(hole.start)-2.0 and value <= float(hole.end)+2.0:
			return float(hole.end)+4.0
	return value
