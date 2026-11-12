extends Node3D
## Cidadãos originais humanos/cactos. Sem imagens de heróis, soldados de combate ou física.
const HUMAN=preload("res://assets/desert/npc_citizens/human_citizens.png")
const CACTUS=preload("res://assets/desert/npc_citizens/cactus_citizens.png")
const MODULES: Array=[48,120,56,48,48,56,48,56,48,48]
static var _feet: Dictionary={}
var _members: Array[Dictionary]=[]
var _player: Node3D
var context:="alone"
static func populated(order: int,slot: int) -> bool:
 if order<1 or order>10:return false
 # Entrada reconhecível, sem esperar vários módulos para mostrar um cidadão.
 if slot==0:return true
 var modules: int=MODULES[order-1]
 # Operários ficam na entrada da mina; a arena de Malagueta continua livre.
 if order==10 and slot>=modules-2:return false
 var sector:=modules/8
 # Telhados: só o vigia na entrada de cada trecho; ninguém passeando de laje em laje.
 if order==2:return slot%sector==0
 var district:=mini(7,slot/sector)
 var offsets: Array=[1,3,2,4,1,4,2,3] if order!=2 else [2,7,4,10,3,9,5,11]
 var original:=clampi(int(offsets[(district+order)%8]),1,sector-2)
 # Preserva os grupos existentes e povoa também as entradas dos distritos/checkpoints.
 return slot%sector in [original,0]
func configure(order: int,slot: int,left: float,right: float,top: float) -> void:
 add_to_group("campaign_background_people")
 set_meta("surface_span",Vector2(left,right))
 var rng:=RandomNumberGenerator.new()
 rng.seed=order*7919+slot*193
 var anchors: Array[Node3D]=[]
 for node in get_parent().get_children():
  if node is Sprite3D and node.get_meta("asset_id","") in ["capital_merchant","capital_market_stall","capital_palm_garden"]:anchors.append(node)
 var anchor: Node3D
 for candidate in anchors:
  if candidate.position.x>left+2 and candidate.position.x<right-2:
   if anchor==null or absf(candidate.position.x-(left+right)*0.5)<absf(anchor.position.x-(left+right)*0.5):anchor=candidate
 var asset:=str(anchor.get_meta("asset_id","")) if anchor!=null else ""
 var ids: Array=[]
 var entry: bool=slot%(int(MODULES[order-1])/8)==0
 if entry:
  # Entradas de distrito: grupos diferentes a cada trecho, conforme o lugar. Antes era
  # sempre o mesmo par (homem de avental + cacto de gorro) em todas as fases.
  if order==2:
   # Telhados: só um vigia com lanterna; moradores não ficam passeando nas lajes.
   context="watch"
   ids=[3]
  elif order in [6,8]:
   context="watch"
   ids=[3] if rng.randf()<0.6 else [3,2]
  elif order in [7,9,10]:
   context="workers"
   ids=[2] if rng.randf()<0.5 else [2,3]
  else:
   context="conversation"
   var locals: Array=[0,1,2,3,4,5,7]
   var first: int=locals[rng.randi_range(0,locals.size()-1)]
   ids=[first]
   if rng.randf()<0.7:ids.append(locals[(locals.find(first)+1+rng.randi_range(0,4))%locals.size()])
 elif order in [1,3] and asset in ["capital_merchant","capital_market_stall"]:
  context="market"
  ids=[0,1,2,3] if slot%3==0 else [0,1,5]
 elif order in [1,5] and asset=="capital_palm_garden" and slot%3!=0:
  context="family"
  ids=[4,5,6,7] if slot%2==0 else [4,5,6]
 elif order in [2,4,6,7,8,9,10]:
  context="watch" if order==8 else "workers"
  ids=[3] if order==8 else [2]
  if rng.randf()<0.35:ids.append(3 if order!=8 else 2)
 else:
  context="conversation" if rng.randf()<0.35 else "alone"
  var adults: Array=[0,1,2,3,4,5,7]
  ids=[adults[rng.randi_range(0,adults.size()-1)]]
  if context=="conversation":ids.append(1 if ids[0]!=1 else 5)
 set_meta("context",context)
 var half:=float(ids.size()-1)*0.55+0.65
 var x:=clampf(anchor.position.x if anchor!=null else lerpf(left,right,rng.randf_range(0.38,0.68)),left+half+0.5,right-half-0.5)
 if entry:x=clampf(lerpf(left,right,0.33) if slot==0 else left+3.0,left+half+0.5,right-half-0.5)
 var family_human:=rng.randf()<0.6
 for i in ids.size():
  var human: bool=(order==2 or rng.randf()<0.5) if entry else (family_human if context=="family" else rng.randf()<0.55)
  var spacing: float=1.05 if context!="family" else 0.88
  var px:=x+(i-float(ids.size()-1)*0.5)*spacing+rng.randf_range(-0.09,0.09)
  # Pista 2,5D: fachadas/telhados pintados são planos opacos, não volumes.
  # Atrás desses planos (z -2/-5) o figurante existia, mas sumia na imagem.
  # Fica na borda próxima do cenário, ainda atrás do jogador em z=0.
  var z:=-0.18-rng.randf_range(0,0.06)
  _citizen(human,int(ids[i]),Vector3(px,top,z),rng.randf_range(1.32,1.50),i>=maxi(1,ids.size()/2),rng.randf()<0.45)
 _clear_items.call_deferred()
 var ancestor:=get_parent()
 while ancestor!=null:
  if ancestor.has_method("_stream_world"):
   _player=ancestor._player
   break
  ancestor=ancestor.get_parent()
## Cidadão não fica em cima de recarga, checkpoint, Task nem do ponto de entrada do jogador:
## o grupo desliza para o trecho livre mais próximo da laje, ou sai de cena se não couber.
func _clear_items() -> void:
 if _members.is_empty() or not is_inside_tree():return
 var span: Vector2=get_meta("surface_span",Vector2.ZERO)
 var blockers: Array[float]=[]
 var nearby: Array=get_parent().get_children()
 if get_parent().get_parent()!=null:nearby.append_array(get_parent().get_parent().get_children())
 for node in nearby:
  if node is Area3D or node.has_meta("pedestal"):blockers.append((node as Node3D).global_position.x)
 if is_instance_valid(_player):blockers.append(_player.global_position.x)
 # Mecanismos de Task (portão, guincho, alavanca) também ficam livres de figurantes.
 var stage: Variant=_player.get_parent().get("_phase") if is_instance_valid(_player) and _player.get_parent()!=null else null
 if stage is Dictionary:
  for task: Dictionary in stage.get("tasks",[]):
   for x: float in [float(task.start)-4.0,float(task.start)-2.0,float(task.start),(float(task.start)+float(task.end))*0.5,float(task.end)]:
    if x>span.x-3.0 and x<span.y+3.0:blockers.append(x)
 if blockers.is_empty():return
 var low:=INF
 var high:=-INF
 for member: Dictionary in _members:
  low=minf(low,member.sprite.global_position.x)
  high=maxf(high,member.sprite.global_position.x)
 var clear:=func(shift: float) -> bool:
  if low+shift<span.x+1.0 or high+shift>span.y-1.0:return false
  for x: float in blockers:
   if x>low+shift-2.0 and x<high+shift+2.0:return false
  return true
 if clear.call(0.0):return
 for shift: float in [2.5,-2.5,4.5,-4.5,6.5,-6.5,9.0,-9.0]:
  if clear.call(shift):
   for member: Dictionary in _members:member.sprite.position.x+=shift
   return
 for member: Dictionary in _members:member.sprite.queue_free()
 _members.clear()
func _citizen(human: bool,id: int,at: Vector3,height: float,flip: bool,reacts: bool) -> void:
 if _feet.is_empty():_feet=JSON.parse_string(FileAccess.get_file_as_string("res://assets/desert/npc_citizens/frames.json"))
 var sprite:=Sprite3D.new()
 sprite.texture=HUMAN if human else CACTUS
 sprite.hframes=4
 sprite.vframes=4
 sprite.pixel_size=height/(float(sprite.texture.get_height())/4.0)
 sprite.position=at
 sprite.flip_h=flip
 sprite.shaded=false
 sprite.modulate=Color(0.82,0.84,0.92)
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 sprite.set_meta("civilian",true)
 sprite.set_meta("species","human" if human else "cactus")
 add_child(sprite)
 var member: Dictionary={"sprite":sprite,"id":id,"neutral":(id/4)*8+id%4,"human":human,"ground":at.y,"height":height,"reacts":reacts,"flip":flip,"startled":0.0,"armed":true}
 _members.append(member)
 _pose(member,false)
func _pose(member: Dictionary,startled: bool) -> void:
 var sprite: Sprite3D=member.sprite
 var frame: int=member.neutral+(4 if startled else 0)
 sprite.frame=frame
 sprite.flip_h=(_player.global_position.x<sprite.global_position.x) if startled and is_instance_valid(_player) else bool(member.flip)
 var key: String="human_citizens" if member.human else "cactus_citizens"
 var foot: float=_feet[key].cells[frame].foot
 sprite.position.y=float(member.ground)+float(member.height)*(foot-0.5)
func _process(delta: float) -> void:
 if not is_instance_valid(_player):return
 for member: Dictionary in _members:
  var distance:=absf(member.sprite.global_position.x-_player.global_position.x)
  if distance>9.0:member.armed=true
  if float(member.startled)>0.0:
   member.startled=maxf(0.0,float(member.startled)-delta)
   if member.startled<=0.0:_pose(member,false)
  elif member.reacts and member.armed and distance<4.5 and absf(_player.velocity.x)>3.0:
   member.armed=false
   member.startled=1.8
   _pose(member,true)
