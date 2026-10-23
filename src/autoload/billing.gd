extends Node
## Autoload "Billing": compra de diamantes com dinheiro real (Google Play Billing, produtos consumíveis).
## Fluxo: compra na Play Store → o servidor valida o token e credita os diamantes → o app consome a compra.
## Sem o plugin (editor/desktop/APK sem gradle) usa compra SIMULADA, aceita só pelo servidor mock
## (a Edge Function recusa tokens simulados). Ver PENDENCIAS.md para publicar.

signal purchase_finished(ok: bool, result: Dictionary)
signal prices_updated

const PLUGIN := "GodotGooglePlayBilling"

var simulated := true
var plugin: Object = null
var connected := false
var prices := {}       # product_id -> preço localizado da Play Store
var _overlay: Node = null
var _pending_product := ""


func _ready() -> void:
	DataDB.ensure_loaded()
	if Engine.has_singleton(PLUGIN):
		simulated = false
		plugin = Engine.get_singleton(PLUGIN)
		_connect_plugin()


func set_overlay(o: Node) -> void:
	_overlay = o


func products() -> Array:
	return DataDB.iap.get("products", [])


func price_text(pr: Dictionary) -> String:
	return prices.get(pr.id, pr.get("price", "?"))


## Compra um pacote de diamantes. Retorna o resultado do servidor ({ok, diamonds_gained, wallet...}).
func buy(product_id: String) -> Dictionary:
	var pr := DataDB.iap_product(product_id)
	if pr.is_empty():
		return {"ok": false, "error": Loc.t("Produto inválido")}
	if simulated:
		var go: bool = await UIDialog.confirm(_overlay, Loc.t("Compra de teste"),
			Loc.t("%d diamantes por %s.") % [int(pr.diamonds) + int(pr.get("bonus", 0)), price_text(pr)] + "\n\n" + Loc.t("[Modo simulado: sem Google Play Billing nenhuma cobrança é feita]"),
			Loc.t("Comprar"), Loc.t("Cancelar"))
		if not go:
			return {"ok": false, "error": "", "cancelled": true}
		return await Game.credit_purchase(product_id, "sim_%d_%d" % [Time.get_ticks_usec(), randi()])
	if not connected:
		return {"ok": false, "error": Loc.t("Loja do Google indisponível. Tente de novo.")}
	_pending_product = product_id
	plugin.purchase(product_id)
	var res: Array = await purchase_finished
	return res[1]


# ------------------------------------------------------------------ plugin (API GodotGooglePlayBilling)

func _connect_plugin() -> void:
	plugin.connected.connect(_on_connected)
	plugin.disconnected.connect(func(): connected = false)
	plugin.purchases_updated.connect(_on_purchases_updated)
	plugin.purchase_error.connect(func(_code, msg): purchase_finished.emit(false, {"ok": false, "error": str(msg)}))
	if plugin.has_signal("sku_details_query_completed"):
		plugin.sku_details_query_completed.connect(_on_details)
	if plugin.has_signal("query_purchases_response"):
		plugin.query_purchases_response.connect(func(r): _on_purchases_updated(r.get("purchases", [])))
	plugin.startConnection()


func _on_connected() -> void:
	connected = true
	var ids: Array = []
	for pr in products():
		ids.append(pr.id)
	plugin.querySkuDetails(ids, "inapp")
	# compras pagas que não chegaram a ser creditadas (app fechou no meio)
	if plugin.has_method("queryPurchases"):
		plugin.queryPurchases("inapp")


func _on_details(details: Array) -> void:
	for d in details:
		prices[d.get("sku", d.get("product_id", ""))] = d.get("price", "")
	prices_updated.emit()


func _on_purchases_updated(purchases: Array) -> void:
	for pu in purchases:
		if int(pu.get("purchase_state", 1)) != 1:
			continue  # pendente (ex.: boleto) — credita quando concluir
		var skus: Array = pu.get("skus", [pu.get("sku", _pending_product)])
		var token: String = pu.get("purchase_token", "")
		var r: Dictionary = await Game.credit_purchase(skus[0], token)
		if r.get("ok", false) or r.get("error", "") == "Compra já creditada":
			plugin.consumePurchase(token)
		purchase_finished.emit(r.get("ok", false), r)
