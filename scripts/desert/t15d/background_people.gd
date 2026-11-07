extends Node3D
## Figurantes sem física: sprites dos modelos oficiais, criados e removidos com o trecho.
const GUARD=preload("res://assets/desert/city_people/cactus.png")
const PEOPLE=[preload("res://assets/desert/city_people/lana.png"),preload("res://assets/desert/city_people/rodrigo.png"),preload("res://assets/desert/city_people/michelly.png")]
var _guard: Sprite3D
var _left:=0.0
var _right:=0.0
var _direction:=1.0
var _clock:=0.0
func configure(order: int,slot: int,left: float,right: float,top: float) -> void:
 add_to_group("campaign_background_people")
 set_meta("surface_span",Vector2(left,right))
 var river:=order in [4,5]
 var x:=lerpf(left,right,0.43)
 var z:=-1.7
 var y:=top
 if river:
  z=-5.10+preload("res://scripts/desert/t15d/regional_context.gd")._river_bend(x) if order==5 else -5.5
  y=top
 if order==2:
  z=-2.0
  y=top
 var civilian:=_sprite(PEOPLE[(slot+order)%PEOPLE.size()],Vector3(x,y,z),0.64)
 civilian.flip_h=slot%2==0
 if slot%3==1:
  var companion:=_sprite(PEOPLE[(slot+order+1)%PEOPLE.size()],Vector3(x+1.1,y,z-0.1),0.60)
  companion.flip_h=not civilian.flip_h
 _guard=_sprite(GUARD,Vector3(lerpf(left,right,0.70),y,z-0.3),0.66)
 _guard.hframes=4
 _left=maxf(left+1.0,_guard.position.x-1.8)
 _right=minf(right-1.0,_guard.position.x+1.8)
 _clock=float(slot)*0.31
func _sprite(texture: Texture2D,at: Vector3,size_scale: float) -> Sprite3D:
 var sprite:=Sprite3D.new()
 sprite.texture=texture
 sprite.pixel_size=2.15/384.0*size_scale
 sprite.position=at+Vector3.UP*(0.98*size_scale)
 sprite.modulate=Color(0.67,0.72,0.84,1)
 sprite.shaded=false
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(sprite)
 return sprite
func _process(delta: float) -> void:
 if _guard==null:return
 _clock+=delta
 _guard.position.x=clampf(_guard.position.x+_direction*0.55*delta,_left,_right)
 if _guard.position.x>=_right:_direction=-1.0
 elif _guard.position.x<=_left:_direction=1.0
 _guard.flip_h=_direction<0.0
 _guard.frame=int(_clock*5.0)%4
