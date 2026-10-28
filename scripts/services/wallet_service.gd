class_name WalletService
extends RemoteDataService

var transactions: Array = []
var next_cursor: Variant = null
var _history_loading := false
var _page_epoch := 0


func clear() -> void:
	_page_epoch += 1
	_history_loading = false
	transactions.clear()
	next_cursor = null
	super.clear()


func refresh() -> Dictionary:
	_page_epoch += 1
	var result := await load_rpc("qse_wallet")
	if result.ok:
		transactions = data.get("transactions", [])
		next_cursor = data.get("next_cursor")
		changed.emit()
	return result


func load_more() -> Dictionary:
	if _history_loading:
		return ServiceResult.failure("rate_limit")
	if next_cursor == null:
		return ServiceResult.success({})
	_history_loading = true
	var epoch := _page_epoch
	var result := await client.call_rpc("qse_wallet_history", {"p_before": str(next_cursor)})
	_history_loading = false
	if epoch != _page_epoch:
		return ServiceResult.failure("session_changed", "unauthorized")
	if result.ok and not PlayerContracts.valid_wallet(result.data, true):
		return ServiceResult.failure("invalid_contract")
	if result.ok:
		transactions.append_array(result.data.get("transactions", []))
		next_cursor = result.data.get("next_cursor")
		changed.emit()
	return result


func balance(currency: String) -> Variant:
	# Nenhuma API de crédito ou escrita de saldo existe no cliente.
	return data.get(currency) if state == "success" else null


func valid_data(value: Variant) -> bool:
	return PlayerContracts.valid_wallet(value)
