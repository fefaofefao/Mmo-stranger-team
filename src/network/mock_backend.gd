class_name MockBackend
extends BackendService
## Servidor simulado localmente. Mantém o estado "do servidor" em user://mock_server.json,
## separado do save do jogador, aplicando as mesmas regras da Edge Function (ServerLogic).

const STATE_PATH := "user://mock_server.json"

var logic: ServerLogic
var clock: Callable
var _dirty := false
var _save_timer := 0.0


func _init(p_clock: Callable = Callable()) -> void:
	mode_name = "mock"
	clock = p_clock


func _ready() -> void:
	var st := {}
	if FileAccess.file_exists(STATE_PATH):
		var f := FileAccess.open(STATE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			st = parsed
	logic = ServerLogic.new(st, clock)
	online = true
	status_changed.emit(true, "Servidor local (mock)")


func is_mock() -> bool:
	return true


func server_now() -> float:
	return logic.now() if logic else super.server_now()


func _process(delta: float) -> void:
	if _dirty:
		_save_timer += delta
		if _save_timer > 2.0:
			persist()


func persist() -> void:
	_dirty = false
	_save_timer = 0.0
	if logic == null:
		return
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(logic.state))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		if _dirty:
			persist()


func request(action: String, args: Dictionary = {}) -> Dictionary:
	if logic == null:
		_ready()
	# JSON ida e volta: garante que o cliente nunca compartilhe referências com o "servidor"
	args = JSON.parse_string(JSON.stringify(args))
	var res := _dispatch(action, args)
	_dirty = true
	return JSON.parse_string(JSON.stringify(res))


func _dispatch(action: String, a: Dictionary) -> Dictionary:
	var L := logic
	if action != "login" and L.p().is_empty():
		return {"ok": false, "error": "não autenticado"}
	match action:
		"login":
			return L.login(a.get("device_id", "local"))
		"link_google":
			return L.link_google(a.get("email", "conta-google@exemplo.com"))
		"set_name":
			return L.set_name(a.get("name", ""))
		"get_profile":
			return L.get_profile()
		"touch":
			L.touch()
			return {"ok": true}
		"register_starter":
			return L.register_starter(a.get("family", ""))
		"spawn_tickets":
			return L.request_spawn_tickets(a.get("hunt", ""), int(a.get("n", 20)))
		"claim_kills":
			return L.claim_kills(a.get("hunt", ""), a.get("kills", []), a.get("party", []), a.get("stats", []), float(a.get("gold_pct", 0)))
		"claim_offline":
			return L.claim_offline(a.get("hunt", ""), a.get("party", []), a.get("stats", []), float(a.get("gold_pct", 0)))
		"double_offline":
			return L.double_offline()
		"claim_challenge":
			return L.claim_challenge(a.get("challenge", ""), bool(a.get("won", false)), float(a.get("seconds", 0)), a.get("party", []))
		"daily_boss_status":
			return L.daily_boss_status(int(a.get("level", 1)))
		"daily_boss_start":
			return L.daily_boss_start(int(a.get("level", 1)))
		"daily_boss_claim":
			return L.daily_boss_claim(a.get("token", ""), float(a.get("fraction", 0)), float(a.get("seconds", 0)), bool(a.get("won", false)), a.get("party", []))
		"challenge_status":
			return L.challenge_status()
		"convert_monster":
			return L.convert_monster(a.get("server_id", ""), int(a.get("level", 1)), int(a.get("stage", 1)), int(a.get("stars", 0)))
		"buy_star":
			return L.buy_star(a.get("server_id", ""))
		"spend":
			return L.spend(int(a.get("gold", 0)), a.get("essences", {}), a.get("reason", ""))
		"npc_sell":
			return L.npc_sell(a.get("item", {}))
		"iap_purchase":
			return L.iap_purchase(a.get("product", ""), a.get("token", ""))
		"boost_status":
			return L.boost_status()
		"boost_buy":
			return L.boost_buy(a.get("kind", ""))
		"boost_ad":
			return L.boost_ad(a.get("kind", ""))
		"market_list_monster":
			return L.market_list_monster(a.get("server_id", ""), int(a.get("level", 1)), int(a.get("stage", 1)), int(a.get("price", 0)))
		"train_monster":
			return L.train_monster(a.get("server_id", ""))
		"shop_status":
			return L.shop_status()
		"shop_buy":
			return L.shop_buy(int(a.get("slot", -1)))
		"shop_refresh":
			return L.shop_refresh()
		"npc_sell_many":
			return L.npc_sell_many(a.get("items", []))
		"convert_monsters":
			return L.convert_monsters(a.get("list", []))
		"npc_buy":
			return L.npc_buy(a.get("base", ""))
		"enhance_item":
			return L.enhance_item(a.get("uid", ""))
		"sync_save":
			return L.sync_save(a.get("summary", {}))
		"cloud_save_put":
			L.state["cloud_save"] = {"save": a.get("save", {}), "t": L.now()}
			return {"ok": true, "t": L.now()}
		"cloud_save_get":
			var cs: Dictionary = L.state.get("cloud_save", {})
			return {"ok": true, "save": cs.get("save", {}), "t": cs.get("t", 0)}
		"rankings":
			return L.rankings(a.get("category", "level"), a.get("period", "global"))
		"ranking_categories":
			return {"ok": true, "categories": L.ranking_categories()}
		"market_search":
			return L.market_search(a.get("filters", {}))
		"market_list_item":
			return L.market_list_item(a.get("uid", ""), int(a.get("price", 0)))
		"market_list_essence":
			return L.market_list_essence(a.get("type", ""), int(a.get("amount", 0)), int(a.get("price", 0)))
		"market_buy":
			return L.market_buy(a.get("listing", ""))
		"market_cancel":
			return L.market_cancel(a.get("listing", ""))
		"market_my":
			return L.market_my()
	if OS.is_debug_build():
		match action:
			"debug_grant":
				return L.debug_grant(int(a.get("gold", 0)), a.get("essences", {}), int(a.get("diamonds", 0)))
			"debug_force":
				for k in a:
					L.debug_force[k] = a[k]
				return {"ok": true}
			"debug_set_validated_level":
				L.debug_set_validated_level(int(a.get("level", 1)))
				return {"ok": true}
			"debug_reset":
				L.state = {}
				L._init({}, clock)
				return {"ok": true}
	return {"ok": false, "error": "ação desconhecida: " + action}
