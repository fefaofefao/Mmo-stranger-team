class_name BackendService
extends Node
## Interface única da camada de serviço online. Implementações:
##  - MockBackend: servidor simulado localmente (ServerLogic), com ranking e market fictícios.
##  - SupabaseBackend: Supabase real (Auth anônima, Edge Function "game", Postgres + RLS).
##
## Toda chamada é `await backend.request(acao, args)` e retorna um Dictionary
## {ok: bool, error?: String, ...dados}.
##
## Ações: login, link_google, set_name, get_profile, touch, register_starter, spawn_tickets,
## claim_kills, claim_offline, double_offline, claim_challenge, challenge_status, convert_monster,
## buy_star, spend, npc_sell, npc_buy, enhance_item, sync_save, cloud_save_put, cloud_save_get,
## rankings, market_search, market_list_item, market_list_essence, market_buy, market_cancel,
## market_my, debug_* (somente mock em build debug).

signal status_changed(online: bool, message: String)

var online := false
var mode_name := "base"


func request(_action: String, _args: Dictionary = {}) -> Dictionary:
	return {"ok": false, "error": "não implementado"}


func is_mock() -> bool:
	return false


func server_now() -> float:
	return Time.get_unix_time_from_system()
