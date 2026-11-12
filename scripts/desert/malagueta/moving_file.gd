extends AnimatableBody3D
## Staggered full-width cutter: flat safe top, short handoff, serrated edge below.
@export var travel := 28.0
@export var speed := 2.2
@export var span := 3.4
@export var damage := 1
@export var sweep_index := 0
@export var sweep_count := 5
var origin := Vector3.ZERO
var elapsed := 0.0
var enabled := true
var direction := 1.0
@export var handoff_seconds := 3.6
var _active := false
## Uma serra fere no máximo uma vez por passada (antes a frente e a traseira tiravam duas vidas).
var _hit_wait := 0.0
var _danger_areas: Array[Area3D] = []
var _pass_through := {}
static var _steel: StandardMaterial3D
static var _dark: StandardMaterial3D
func _ready()->void:
 add_to_group("mining_files")
 origin=position;collision_layer=1;collision_mask=0;sync_to_physics=false
 if _steel==null:
  _steel=StandardMaterial3D.new();_steel.albedo_color=Color("#abb2b3");_steel.metallic=0.8;_steel.roughness=0.3
  _dark=StandardMaterial3D.new();_dark.albedo_color=Color("#343536");_dark.metallic=0.7;_dark.roughness=0.48
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(span,0.3,2.0)
 shape.shape=box;shape.position.y=-0.15;add_child(shape)
 _box(Vector3(0,-0.1,0),Vector3(span,0.2,2),_steel)
 _box(Vector3(0,-0.23,-0.2),Vector3(span-0.2,0.12,1.4),_dark)
 # Batch all teeth into one mesh. Their tips match the dangerous underside.
 var teeth:=SurfaceTool.new();teeth.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count:=14
 for i in count:
  var x:=-span*0.5+(i+0.5)*span/count
  var half:=span/count*0.46
  var a:=Vector3(x-half,-0.22,1.02);var b:=Vector3(x+half,-0.22,1.02);var c:=Vector3(x,-0.42,1.02)
  for v in [a,b,c,c,b,a]:teeth.add_vertex(v)
  var d:=Vector3(x,-0.32,0.6)
  for v in [a,c,d,c,b,d,b,a,d]:teeth.add_vertex(v)
 teeth.generate_normals()
 var edge:=MeshInstance3D.new();edge.name="SerratedCuttingEdge";edge.mesh=teeth.commit();edge.material_override=_steel;add_child(edge)
 _box(Vector3(0,-0.04,-0.82),Vector3(span-0.25,0.08,0.14),_dark)
 # Carriage and rollers sit behind the walkable surface, never another invisible floor.
 _box(Vector3(0,-0.12,-1.3),Vector3(0.85,0.6,0.42),_dark)
 for x in [-0.3,0.3]:
  var wheel:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=0.15;mesh.bottom_radius=0.15;mesh.height=0.18;mesh.radial_segments=12
  wheel.mesh=mesh;wheel.material_override=_steel;wheel.position=Vector3(x,-0.12,-1.03);wheel.rotation.x=PI*0.5;add_child(wheel)
 for side in [-1,1]:_danger(Vector3(side*(span*0.5+0.07),-0.32,0),Vector3(0.18,0.16,1.8))
 _danger(Vector3(0,-0.36,0.72),Vector3(span,0.16,0.65))
 position=future_position(0.0)
 _set_active(is_available())
func _box(at: Vector3,size: Vector3,material: Material)->void:
 var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.position=at;visual.material_override=material;add_child(visual)
func _danger(at: Vector3,size: Vector3)->void:
 var area:=Area3D.new();area.collision_layer=0;area.collision_mask=2
 var shape:=CollisionShape3D.new();var mesh:=BoxShape3D.new();mesh.size=size;shape.shape=mesh;shape.position=at;area.add_child(shape);add_child(area);_danger_areas.append(area)
 area.body_entered.connect(func(body: Node3D)->void:
  if enabled and _active and _hit_wait<=0.0 and body.is_in_group("player"):
   _hit_wait=2.4
   body.take_damage(damage,global_position.x))
func crossing_duration()->float:
 return maxf(travel,span+24.0)/maxf(speed,0.01)
func entry_interval()->float:
 return crossing_duration()-minf(handoff_seconds,crossing_duration()*0.4)
func cycle_duration()->float:
 return entry_interval()*maxi(1,sweep_count)+handoff_seconds+0.8
func local_time(seconds:=0.0)->float:
 return fposmod(elapsed+seconds,cycle_duration())-entry_interval()*sweep_index
func is_available(seconds:=0.0)->bool:
 var time:=local_time(seconds)
 return time>=0.0 and time<crossing_duration()
func future_position(seconds: float)->Vector3:
 var time:=clampf(local_time(seconds),0.0,crossing_duration())
 var side:=1.0 if sweep_index%2==0 else -1.0
 var edge:=maxf(travel,span+24.0)*0.5
 return Vector3(side*lerpf(-edge,edge,time/crossing_duration()),origin.y,origin.z)
func _set_active(value: bool)->void:
 _active=value
 visible=value
 collision_layer=1 if value else 0
 for area in _danger_areas:area.set_deferred("monitoring",value)
func _physics_process(delta: float)->void:
 if not enabled:return
 _hit_wait=maxf(_hit_wait-delta,0.0)
 var previous:=position.x
 elapsed+=delta
 position=future_position(0.0)
 var available:=is_available()
 if available!=_active:_set_active(available)
 direction=signf(position.x-previous)
 if not _active:return
 # One-way support: jumping from underneath must not trap the actor's head.
 # Cutting Areas remain active and independent of this floor collision.
 var actors:=get_tree().get_nodes_in_group("player")
 actors.append_array(get_tree().get_nodes_in_group("enemies"))
 for actor: Node in actors:
  if not actor is PhysicsBody3D:continue
  var id:=actor.get_instance_id()
  var ignored:=bool(_pass_through.get(id,false))
  if not ignored and actor.global_position.y<global_position.y-0.08:
   add_collision_exception_with(actor);_pass_through[id]=true
  elif ignored and actor.global_position.y>global_position.y+0.05:
   remove_collision_exception_with(actor);_pass_through[id]=false
