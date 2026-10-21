class_name SupabaseBackend
extends BackendService
## Implementação real usando Supabase:
##  - Auth anônima (POST /auth/v1/signup sem email) + refresh token salvo em user://auth.json
##  - Todas as ações passam pela Edge Function "game" (supabase/functions/game), que aplica as
##    regras autoritativas e usa funções Postgres atômicas para o market.
##  - Vincular Google: abre o fluxo OAuth do Supabase (linkIdentity) no navegador.

const AUTH_PATH := "user://auth.json"

var url := ""
var anon_key := ""
var access_token := ""
var refresh_token := ""
var token_expires_at := 0.0
var user_id := ""
var _server_offset := 0.0


func _init(p_url: String, p_key: String) -> void:
	mode_name = "supabase"
	url = p_url.trim_suffix("/")
	anon_key = p_key


func _ready() -> void:
	if FileAccess.file_exists(AUTH_PATH):
		var f := FileAccess.open(AUTH_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			refresh_token = d.get("refresh_token", "")
			user_id = d.get("user_id", "")


func server_now() -> float:
	return Time.get_unix_time_from_system() + _server_offset


func _save_auth() -> void:
	var f := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"refresh_token": refresh_token, "user_id": user_id}))


func _http(method: int, path: String, body: Variant, auth := true, extra_headers: Array = []) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	var headers := ["Content-Type: application/json", "apikey: " + anon_key]
	if auth and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	else:
		headers.append("Authorization: Bearer " + anon_key)
	headers.append_array(extra_headers)
	var payload := "" if body == null else JSON.stringify(body)
	var err := req.request(url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "falha de rede (%d)" % err, "status": 0}
	var result: Array = await req.request_completed
	req.queue_free()
	var status: int = result[1]
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else {}
	if data == null:
		data = {"raw": text}
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "sem conexão", "status": 0}
	if status >= 400:
		var msg := "erro %d" % status
		if data is Dictionary:
			msg = str(data.get("error", data.get("msg", data.get("message", msg))))
		return {"ok": false, "error": msg, "status": status}
	return {"ok": true, "data": data, "status": status}


func _ensure_session() -> bool:
	var now := Time.get_unix_time_from_system()
	if access_token != "" and now < token_expires_at - 60.0:
		return true
	if refresh_token != "":
		var r := await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false)
		if r.ok:
			_apply_session(r.data)
			return true
	# login anônimo
	var r2 := await _http(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {}}, false)
	if r2.ok:
		_apply_session(r2.data)
		return true
	online = false
	status_changed.emit(false, "Falha no login: " + str(r2.get("error", "")))
	return false


func _apply_session(d: Dictionary) -> void:
	access_token = d.get("access_token", "")
	refresh_token = d.get("refresh_token", refresh_token)
	token_expires_at = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	user_id = d.get("user", {}).get("id", user_id)
	_save_auth()


func request(action: String, args: Dictionary = {}) -> Dictionary:
	if action.begins_with("debug_"):
		return {"ok": false, "error": "debug indisponível no Supabase"}
	if not await _ensure_session():
		return {"ok": false, "error": "offline"}
	if action == "link_google":
		return await _link_google()
	var r := await _http(HTTPClient.METHOD_POST, "/functions/v1/game", {"action": action, "args": args})
	if not r.ok:
		if int(r.get("status", 0)) == 0:
			online = false
			status_changed.emit(false, "Sem conexão")
		return {"ok": false, "error": r.error}
	if not online:
		online = true
		status_changed.emit(true, "Online (Supabase)")
	var data: Dictionary = r.data if r.data is Dictionary else {"ok": false, "error": "resposta inválida"}
	if data.has("server_time"):
		_server_offset = float(data.server_time) - Time.get_unix_time_from_system()
	return data


func _link_google() -> Dictionary:
	var redirect: String = DataDB.backend_cfg.get("google_redirect_url", "")
	var path := "/auth/v1/user/identities/authorize?provider=google&skip_http_redirect=true"
	if redirect != "":
		path += "&redirect_to=" + redirect.uri_encode()
	var r := await _http(HTTPClient.METHOD_GET, path, null)
	if not r.ok:
		return {"ok": false, "error": r.error}
	var link: String = r.data.get("url", "") if r.data is Dictionary else ""
	if link == "":
		return {"ok": false, "error": "URL de login indisponível"}
	OS.shell_open(link)
	return {"ok": true, "pending": true, "message": "Conclua o login do Google no navegador."}
