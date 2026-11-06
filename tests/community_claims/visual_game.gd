extends "res://tests/community_t27/fake_game.gd"
var claims := preload("res://tests/community_claims/fake_game.gd").new()
func _ready() -> void:
	super._ready()
	add_child(claims)
func call_rpc(name: String,params: Dictionary={}) -> Dictionary:
	if name=="qse_community_inventory": return await claims.call_rpc(name,params)
	return await super.call_rpc(name,params)
func send(path: String,method: HTTPClient.Method,body: Variant=null,headers:=PackedStringArray(),raw:=PackedByteArray(),type:="",timeout:=30.0) -> Dictionary:
	if path==CommunityDecksService.PATH: return await claims.send(path,method,body,headers,raw,type,timeout)
	return await super.send(path,method,body,headers,raw,type,timeout)
func gallery() -> Dictionary:
	var item := {"id":claims.DECK,"name":"[TESTE] Deck da Comunidade","creator":"Criador de teste","category":"Personagens","description":"Fixture visual local. Resgate e partidas usam serviços simulados.","official":false,"community":true,"tags":[],"age_rating":"","content_warnings":[],"cards":[],"count":5}
	for i in 5:
		item.cards.append({"id":str(claims.manifest().cards[i].id),"name":"Carta "+str(i+1),"description":"","image":"res://assets/duel/decks/oficial/lendas_urbanas/momo.png"})
	return item
