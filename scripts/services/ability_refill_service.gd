class_name AbilityRefillService
extends RemoteDataService
## Account-owned consumables; gameplay charges remain local to the current run.
var session: SessionService
var _owner := ""
var busy := false
const FILE := "user://ability_refill_receipts.cfg"
const KINDS := {"attack":"Ataque","defense":"Defesa","amber":"Congelamento","dash":"Corrida elétrica","rupture":"Quebra de chão"}

func clear() -> void:
 _owner=""
 super.clear()

func _config() -> ConfigFile:
 var cfg := ConfigFile.new();cfg.load(FILE);return cfg

func refresh() -> Dictionary:
 if not session.authenticated(): return ServiceResult.failure("not_authenticated")
 var owner := str(session.user.get("id",""));var epoch := client.generation
 var result := await load_rpc("qse_ability_refills")
 if owner!=str(session.user.get("id","")) or epoch!=client.generation: return ServiceResult.failure("session_changed")
 if result.ok:
  _owner=owner
  # An applied receipt must never refill a second time just because acknowledgement failed.
  var cfg := _config()
  for receipt: Dictionary in data.pending.duplicate():
   if cfg.get_value(owner,"applied_"+str(receipt.id),false):
    await _ack(receipt,owner,epoch)
  cfg=_config()
  if cfg.has_section(owner):
   var changed_cfg := false
   for key: String in cfg.get_section_keys(owner):
    if key.begins_with("applied_"):
     var id := key.trim_prefix("applied_")
     if not data.pending.any(func(r:Dictionary)->bool:return r.id==id):
      _forget(cfg,owner,id);changed_cfg=true
   if changed_cfg:cfg.save(FILE)
  changed.emit()
 return result

func count() -> Variant:
 if not session.authenticated() or _owner!=str(session.user.get("id","")) or data.is_empty(): return null
 var n := str(data.get("quantity","0")).to_int();var cfg := _config()
 for receipt: Dictionary in data.get("pending",[]):
  if not cfg.get_value(_owner,"applied_"+str(receipt.id),false): n+=1
 return n

func has_for(kind: String) -> bool:
 if count()==null: return false
 if str(data.get("quantity","0")).to_int()>0: return true
 var cfg := _config()
 return data.get("pending",[]).any(func(r:Dictionary)->bool:return r.ability==kind and not cfg.get_value(_owner,"applied_"+str(r.id),false))

func buy(price: int) -> Dictionary:
 if not session.authenticated(): return ServiceResult.failure("not_authenticated")
 if busy: return ServiceResult.failure("request_in_progress")
 if not data.get("available",false) or _owner!=str(session.user.get("id","")): return ServiceResult.failure("sales_disabled")
 var owner := _owner;var epoch := client.generation;var cfg := _config()
 var key := "buy_"+str(price)
 var request := str(cfg.get_value(owner,key,PlayerContracts.uuid()))
 cfg.set_value(owner,key,request)
 if cfg.save(FILE)!=OK: return ServiceResult.failure("local_storage_unavailable")
 busy=true
 var result := await client.call_rpc("qse_ability_refill_buy",{"p_request":request,"p_expected_price":price})
 busy=false
 if epoch!=client.generation or owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
 if result.ok and (not result.data is Dictionary or result.data.get("purchased")!=true or result.data.get("request_id")!=request): return ServiceResult.failure("invalid_contract")
 if result.ok:
  cfg=_config();cfg.erase_section_key(owner,key);cfg.save(FILE)
  await refresh()
 return result

func use_full(player: Node,kind: String,phase: int,current: Callable) -> Dictionary:
 if busy: return ServiceResult.failure("request_in_progress")
 if not session.authenticated(): return ServiceResult.failure("not_authenticated")
 if not current.is_valid() or not current.call(): return ServiceResult.failure("refill_context_changed")
 var reason := str(player.refill_status(kind,phase)) if is_instance_valid(player) else "refill_context_changed"
 if not reason.is_empty(): return ServiceResult.failure(reason)
 var owner := str(session.user.get("id",""));var epoch := client.generation
 busy=true
 var loaded := await refresh()
 if not loaded.ok:
  busy=false;return loaded
 if epoch!=client.generation or owner!=str(session.user.get("id","")) or not is_instance_valid(player) or not current.is_valid() or not current.call():
  busy=false;return ServiceResult.failure("refill_context_changed")
 reason=str(player.refill_status(kind,phase))
 if not reason.is_empty():
  busy=false;return ServiceResult.failure(reason)
 var receipt: Dictionary={};var cfg := _config();var newly_reserved:=false
 for pending: Dictionary in data.pending:
  if pending.ability==kind: receipt=pending;break
 if receipt.is_empty():
  var request := str(cfg.get_value(owner,"use_"+kind,PlayerContracts.uuid()))
  cfg.set_value(owner,"use_"+kind,request)
  if cfg.save(FILE)!=OK:
   busy=false;return ServiceResult.failure("local_storage_unavailable")
  var reserved := await client.call_rpc("qse_ability_refill_reserve",{"p_request":request,"p_ability":kind})
  if not reserved.ok:
   busy=false;return reserved
  if not reserved.data is Dictionary or reserved.data.get("id")!=request or reserved.data.get("ability")!=kind or reserved.data.get("status") not in ["pending","used"]:
   busy=false;return ServiceResult.failure("invalid_contract")
  receipt=reserved.data
  newly_reserved=true
  if receipt.status=="used":
   cfg=_config();cfg.erase_section_key(owner,"use_"+kind);cfg.save(FILE)
   busy=false;return ServiceResult.failure("refill_already_used")
 if epoch!=client.generation or owner!=str(session.user.get("id","")) or not is_instance_valid(player) or not current.is_valid() or not current.call():
  busy=false;return ServiceResult.failure("refill_context_changed")
 reason=str(player.refill_status(kind,phase))
 if not reason.is_empty():
  busy=false;return ServiceResult.failure(reason)
 if newly_reserved:
  data.quantity=str(maxi(0,str(data.quantity).to_int()-1))
  data.pending.append(receipt)
 cfg=_config()
 if cfg.get_value(owner,"applied_"+str(receipt.id),false):
  busy=false;return ServiceResult.failure("refill_already_used")
 # Persist the local delivery marker before changing the run. No await between marker and fill.
 cfg.set_value(owner,"applied_"+str(receipt.id),true)
 if cfg.save(FILE)!=OK:
  busy=false;return ServiceResult.failure("local_storage_unavailable")
 player.fill_ability(kind)
 await _ack(receipt,owner,epoch)
 if epoch==client.generation and owner==str(session.user.get("id","")): changed.emit()
 busy=false
 return ServiceResult.success({"ability":kind,"charges":3})

func _ack(receipt: Dictionary,owner: String,epoch: int) -> void:
 var result := await client.call_rpc("qse_ability_refill_ack",{"p_receipt":receipt.id})
 if epoch!=client.generation or owner!=str(session.user.get("id","")): return
 if result.ok and result.data is Dictionary and result.data.get("id")==receipt.id and result.data.get("used")==true:
  var cfg := _config();_forget(cfg,owner,str(receipt.id));cfg.save(FILE)
  data.pending=data.get("pending",[]).filter(func(r:Dictionary)->bool:return r.id!=receipt.id)

func _forget(cfg: ConfigFile,owner: String,id: String) -> void:
 cfg.erase_section_key(owner,"applied_"+id)
 for kind: String in KINDS:
  if str(cfg.get_value(owner,"use_"+kind,""))==id:cfg.erase_section_key(owner,"use_"+kind)

func valid_data(value: Variant) -> bool:
 if not value is Dictionary or not value.get("quantity") is String or not str(value.quantity).is_valid_int() or str(value.quantity).to_int()<0: return false
 if not value.get("price_coins") is String or not str(value.price_coins).is_valid_int() or str(value.price_coins).to_int()<1 or not value.get("available") is bool or not value.get("pending") is Array: return false
 for receipt: Variant in value.pending:
  if not receipt is Dictionary or not CoinStoreService.uuid_valid(str(receipt.get("id",""))) or not KINDS.has(receipt.get("ability")): return false
 return true

static func message(code: String,kind := "") -> String:
 if code=="ability_full": return "Sua habilidade %s está cheia (3/3). Nenhuma recarga foi gasta." % KINDS.get(kind,kind)
 if code=="ability_locked": return "Esta habilidade ainda não foi liberada nesta fase."
 if code=="no_refills": return "Você não tem recargas guardadas para usar."
 if code=="refill_already_used": return "Esta recarga já foi aplicada. Atualize o inventário."
 if code=="refill_context_changed": return "A fase ou a conta mudou. A entrega pendente continua guardada."
 return EmoteShopService.message(code)
