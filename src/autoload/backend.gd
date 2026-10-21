extends Node
## Autoload "Backend": escolhe a implementação (Supabase real ou mock local) e expõe request().

signal status_changed(online: bool, message: String)

var impl: BackendService


func _ready() -> void:
	DataDB.ensure_loaded()
	var cfg: Dictionary = DataDB.backend_cfg
	var mode: String = cfg.get("mode", "auto")
	var url: String = cfg.get("supabase_url", "")
	var key: String = cfg.get("supabase_anon_key", "")
	if mode == "supabase" or (mode == "auto" and url != "" and key != ""):
		impl = SupabaseBackend.new(url, key)
	else:
		impl = MockBackend.new()
	impl.name = "Impl"
	add_child(impl)
	impl.status_changed.connect(func(o, m): status_changed.emit(o, m))


func request(action: String, args: Dictionary = {}) -> Dictionary:
	var r = await impl.request(action, args)
	if r == null or not (r is Dictionary):
		return {"ok": false, "error": "resposta vazia"}
	return r


func is_mock() -> bool:
	return impl != null and impl.is_mock()


func is_online() -> bool:
	return impl != null and impl.online


func mode_name() -> String:
	return impl.mode_name if impl else "?"


func server_now() -> float:
	return impl.server_now() if impl else GameClock.now()


func persist() -> void:
	if impl is MockBackend:
		(impl as MockBackend).persist()
