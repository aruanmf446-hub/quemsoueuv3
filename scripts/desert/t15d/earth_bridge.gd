extends Node3D
## Mecanismos pontuais do cenário: passagem giratória, portão e plataforma de carga.
## Mesma interação contextual, sem adicionar habilidade nem consumir cargas.
signal assembled
var hole: Dictionary
var raised := false
var _deck: StaticBody3D
var _shape: CollisionShape3D
var _hinge: Node3D
var _angle := 0.0
var _kind := "bridge"
var _art: Node3D
var _cables: Array[MeshInstance3D] = []
var _cable_anchors: Array[Vector3] = []
var _cable_ends: Array[Vector3] = []
func configure(data: Dictionary) -> void:
	hole = data
	_kind = str(data.get("task_kind","bridge"))
func _ready() -> void:
	add_to_group("earth_bridges")
	var start := Vector3(float(hole.start)-0.12,float(hole.from_y),0)
	var finish := Vector3(float(hole.end)+0.12,float(hole.to_y),0)
	var span := finish-start
	_angle = atan2(span.y,span.x)
	_hinge = Node3D.new()
	_hinge.position = start
	_hinge.rotation.z = _angle
	add_child(_hinge)
	_deck = StaticBody3D.new()
	_deck.name = "EarthDeck"
	_deck.collision_layer = 1
	_deck.position = Vector3(span.length()*0.5,-0.13,0)
	_hinge.add_child(_deck)
	var size := Vector3(span.length(),0.26,3.8)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.disabled = true
	_deck.add_child(_shape)
	_art = preload("res://scripts/desert/t15d/task_art.gd").new()
	_deck.add_child(_art)
	var theme := int(hole.get("theme",4))
	_deck.hide()
	if _kind=="gate":
		_hinge.position=Vector3((start.x+finish.x)*0.5,start.y,0)
		_hinge.rotation=Vector3.ZERO
		_deck.position=Vector3(0,2.6,0)
		box.size=Vector3(2.4,5.2,3.6)
		_deck.show()
		_shape.disabled=false
		_art.gate(theme)
	elif _kind=="lift":
		_deck.show()
		_deck.position.y-=1.6
	if _kind!="gate":_art.passage(span.length(),theme,_kind=="lift")
	# Estrutura do mecanismo, fora da pista; o piso e a porta têm seus próprios colisores.
	var props := preload("res://scripts/desert/t15d/task_art.gd").new()
	add_child(props)
	if _kind=="gate":
		props.gate_frame(theme,Vector3((start.x+finish.x)*0.5,start.y,0))
	elif _kind=="lift":
		props.supports(start,finish,theme)
		for side in [-1.0,1.0]:
			var anchor: Vector3 = (start if side<0 else finish)+Vector3(side*0.85,2.9,-2.3)
			for fraction in [0.08,0.27]:
				var cable := MeshInstance3D.new()
				var rope := CylinderMesh.new()
				rope.top_radius=0.015
				rope.bottom_radius=0.015
				rope.height=1.0
				rope.radial_segments=6
				rope.rings=1
				cable.mesh=rope
				cable.material_override=props._material("rope")
				cable.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(cable)
				_cables.append(cable)
				_cable_anchors.append(anchor)
				_cable_ends.append(Vector3(side*span.length()*(0.5-fraction),0,-1.7))
		_update_cables()
	else:
		for point in [start-Vector3(0.75,0,0),finish+Vector3(0.75,0,0)]:props.winch(point+Vector3(0,0,-1.2),theme)
		props._flush()
	# Marcas sobre o piso das duas margens. Nunca ficam flutuando sobre o vão.
	for point in [start-Vector3(0.65,0,0),finish+Vector3(0.65,0,0)]:
		var mark := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.24
		ring.outer_radius = 0.36
		ring.rings = 16
		ring.ring_segments = 6
		mark.mesh = ring
		mark.scale.y = 0.13
		mark.position = point+Vector3(0,0.035,-0.85)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#eec27f")
		mark.material_override = material
		add_child(mark)
func raise_bridge(animated := true) -> void:
	if raised: return
	raised = true
	_deck.show()
	if not animated:
		if _kind=="gate": _hinge.position.y+=5.5
		elif _kind=="lift": _deck.position.y=-0.13
		_update_cables()
		_shape.set_deferred("disabled",false)
		return
	# A física continua com a mesma duração. Só a arte se monta em módulos curtos.
	var tween := create_tween()
	_shape.set_deferred("disabled",true)
	if _kind=="gate":
		tween.tween_property(_hinge,"position:y",_hinge.position.y+5.5,0.8)
	elif _kind=="lift":
		tween.set_parallel(true)
		tween.tween_property(_deck,"position:y",-0.13,0.8)
		tween.tween_method(func(_progress: float) -> void:_update_cables(),0.0,1.0,0.8)
		tween.set_parallel(false)
	else:
		_art.deploy()
		tween.tween_interval(0.8)
	tween.tween_callback(func() -> void:
		_shape.set_deferred("disabled",false)
		assembled.emit())

func _update_cables() -> void:
	# Atualizado só ao montar/restaurar e durante os 0,8s de içamento.
	for index in _cables.size():
		var from := _cable_anchors[index]
		var to := to_local(_deck.to_global(_cable_ends[index]))
		var direction := to-from
		_cables[index].transform=Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized())).scaled_local(Vector3(1,direction.length(),1)),(from+to)*0.5)
