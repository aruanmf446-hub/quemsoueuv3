extends VBoxContainer
## Only exists inside the pause/settings overlay; never attached to the gameplay HUD.
var phase: Node
var _status: Label
var _stock: Label
var _buttons: Dictionary={}
var _cards: Dictionary={}
var _service: AbilityRefillService
var _back: Button
func _ready() -> void:
 PlayerUI.apply_theme(self)
 add_theme_constant_override("separation",10)
 var header := PlayerUI.row(self)
 header.add_child(PlayerUI.label("Recargas de habilidades",30,PlayerUI.TEXT))
 _stock=PlayerUI.label("Recargas guardadas: —",22,PlayerUI.GOLD);_stock.name="StoredRefills";_stock.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;_stock.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(_stock)
 var grid := GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);add_child(grid)
 for kind: String in AbilityRefillService.KINDS:
  var art: Texture2D=load("res://assets/portraits/el_fuego.png") if kind=="attack" else load("res://assets/desert/tutorial/"+kind+".res")
  var emblem: Texture2D=preload("res://scripts/desert/t15d/resource_icons.gd").medallion(kind,128,true,true)
  var card := PlayerUI.ability_refill_card(grid,kind,AbilityRefillService.KINDS[kind],art,emblem,_use.bind(kind))
  var use: Button=card.button;use.name="UseRefill_"+kind
  _buttons[kind]=use;_cards[kind]=card
 _status=PlayerUI.label("",20,PlayerUI.MUTED);_status.name="RefillFeedback";add_child(_status)
 _back=PlayerUI.button("Voltar à pausa",func()->void:phase._session.show_pause());add_child(_back)
 _back.grab_focus.call_deferred()
 if PlayerServices.current==null:
  _status.text="Entre na conta para acessar suas recargas."
 else:
  _service=PlayerServices.current.ability_refills
 _refresh_buttons()
 if _service!=null: _load.call_deferred()
func _load() -> void:
 var result := await _service.refresh()
 if not is_inside_tree(): return
 if not result.ok: _status.text=AbilityRefillService.message(result.code)
 _refresh_buttons()
func _refresh_buttons() -> void:
 var n: Variant=_service.count() if _service!=null else null
 _stock.text=tr("Recargas guardadas: %s") % ("—" if n==null else str(n))
 for kind: String in _buttons:
  var reason := str(phase._player.refill_status(kind,phase._order))
  var count := int(phase._player.charges(kind))
  var button: Button=_buttons[kind]
  button.tooltip_text=AbilityRefillService.message(reason,kind) if not reason.is_empty() else "Uma recarga completa até 3/3"
  var usable: bool=not phase._session.operation_busy and reason.is_empty() and _service!=null and _service.has_for(kind)
  PlayerUI.update_refill_card(_cards[kind],count,reason,usable)
 _back.disabled=phase._session.operation_busy
 if n!=null and int(n)==0 and _status.text.is_empty(): _status.text="Você não tem recargas guardadas. Elas ficam disponíveis na loja."
 phase._session._layout.call_deferred()
func _use(kind: String) -> void:
 if _service==null: return
 var player: Node=phase._player
 var owner := str(PlayerServices.current.session.user.get("id",""))
 phase._session.operation_busy=true;_refresh_buttons()
 _status.text="Aplicando recarga…"
 var current := func()->bool:return is_inside_tree() and is_instance_valid(phase) and phase._paused and phase._player==player and PlayerServices.current!=null and str(PlayerServices.current.session.user.get("id",""))==owner
 var result := await _service.use_full(player,kind,phase._order,current)
 if not is_inside_tree(): return
 phase._session.operation_busy=false
 if result.ok:
  phase._sync_resources()
  _status.text=str(TranslationServer.translate("%s recarregada: 3/3.")) % tr(AbilityRefillService.KINDS[kind])
  PlayerUI.refill_feedback(_status,true)
 else:
  _status.text=AbilityRefillService.message(result.code,kind)
  PlayerUI.refill_feedback(_status,false)
 _refresh_buttons()
