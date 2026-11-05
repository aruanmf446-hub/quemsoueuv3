extends SceneTree
## Geometria independente: avalia os contratos jogáveis das dez regiões novas.
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func run() -> void:
	var themes:={}
	for order in range(1,11):
		var stage:=Layout.build(order)
		var label:="fase%02d: " % order
		check(stage.order==order and not themes.has(stage.theme),label+"identidade única e estável")
		themes[stage.theme]=true
		check(float(stage.length)>=1452 and float(stage.minimum_traversal_seconds)>=180,label+"distância e duração mínima")
		var start:=Layout.floor_at(stage,float(stage.player_spawn[0]))
		var goal:=Layout.floor_at(stage,float(stage.goal.pos[0]))
		check(not start.is_empty() and not goal.is_empty() and absf(float(stage.player_spawn[1])-float(start.height)-0.1)<0.01,label+"entrada e saída apoiadas no percurso")
		check(stage.surfaces.size()>=40 and stage.districts.size()==8,label+"módulos extensos em oito setores")
		check(stage.holes.all(func(h:Dictionary)->bool:return h.width>=1.8-0.01 and h.width<=3.2+0.01 and absf(h.from_y-h.to_y)<=0.65),label+"vãos e desníveis alcançáveis")
		var ids:={}
		var unique:=true
		for item: Dictionary in stage.platforms+stage.pickups+stage.enemies+stage.checkpoints:
			if ids.has(item.id):unique=false
			ids[item.id]=true
		check(unique,label+"IDs únicos para streaming e persistência")
		var supported:=true
		var separate:=true
		var attacks:=0
		var defenses:=0
		for item: Dictionary in stage.pickups:
			var floor:=Layout.floor_at(stage,float(item.pos[0]))
			if floor.is_empty() or absf(float(item.pos[1])-float(floor.get("height",INF)))>0.01:supported=false
			if item.kind=="attack":attacks+=1
			if item.kind=="defense":defenses+=1
			for other: Dictionary in stage.pickups:
				if item.id!=other.id and absf(float(item.pos[0])-float(other.pos[0]))<2.0:separate=false
		check(supported and separate,label+"recargas sustentadas, separadas e fora dos abismos")
		check(attacks+1>=stage.enemies.size() and defenses>=5,label+"suprimento suficiente para combate")
		var guards:=true
		for guard: Dictionary in stage.enemies:
			var floor:=Layout.floor_at(stage,float(guard.pos[0]))
			if floor.is_empty() or absf(float(guard.pos[1])-float(floor.get("height",INF))-0.02)>0.01:guards=false
		check(guards,label+"soldados na mesma altitude da rota")
		var checkpoints: bool = stage.checkpoints.size()==7
		for checkpoint: Dictionary in stage.checkpoints:
			var floor:=Layout.floor_at(stage,float(checkpoint.pos[0]))
			if floor.is_empty() or absf(float(checkpoint.pos[1])-float(floor.get("height",INF)))>0.01:checkpoints=false
		check(checkpoints,label+"sete checkpoints apoiados no piso real")
		var cracks:=true
		for platform: Dictionary in stage.platforms:
			if not platform.get("breakable",false):continue
			if float(platform.size[0])>3.01:cracks=false
			for item: Dictionary in stage.pickups+stage.checkpoints:
				if float(item.pos[0])>=float(platform.span_start)-0.79 and float(item.pos[0])<=float(platform.span_end)+0.79:cracks=false
		check(cracks,label+"ruptura limitada a3m e sem destruir apoios de itens")
		check((ResourceLoader.exists(stage.next_scene) if order<10 else stage.next_scene.is_empty() and stage.boss_id=="malagueta"),label+"continuidade e conclusão do reino")
		check(stage.pickups.all(func(item:Dictionary)->bool:return item.kind in ["attack","defense","health","rupture","amber","dash"]),label+"nenhuma moeda decorativa ou item econômico")
	print("NIGHT_LAYOUT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
