extends SceneTree
## Uses real HTTPRequest parsing against a local fixture, not a mocked call_rpc().
class LoopbackClient:
	extends SupabaseClient
	func configured() -> bool: return endpoint=="http://127.0.0.1:18856"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _run() -> void:
	var client := LoopbackClient.new()
	root.add_child(client)
	client.endpoint="http://127.0.0.1:18856"
	client.publishable_key="fixture-not-real"
	client.set_session("fixture-not-real")
	var cases := {"own":"cannot_report_own","repeat":"already_reported","reason":"invalid_reason","forbidden_rpc":"forbidden","forbidden_http":"forbidden","unauthorized":"not_authenticated","missing":"PGRST202"}
	for value: String in cases:
		var result: Dictionary=await client.call_rpc("qse_deck_report",{"case":value})
		check(not result.ok and result.code==cases[value],"HTTP/RPC preserva "+value+" como "+str(cases[value])+" (recebido: "+str(result.get("code","ok"))+")")
	var auth: Dictionary=await client.request("/auth/v1/token?grant_type=password",HTTPClient.METHOD_POST,{},false)
	check(not auth.ok and auth.code=="invalid_credentials","erro de login mantém o contrato de autenticação")
	var sent: Dictionary=await client.call_rpc("qse_deck_report",{"case":"ok"})
	check(sent.ok and sent.data.reported==true,"sucesso exige resposta confirmada pelo servidor")
	client.queue_free()
	await process_frame
	print("DECK_RPC_HTTP checks=",checks," failures=",failures)
	quit(1 if failures else 0)
