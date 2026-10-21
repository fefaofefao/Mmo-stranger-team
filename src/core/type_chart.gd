class_name TypeChart
extends RefCounted
## Tabela de tipos cíclica: cada tipo é forte contra o próximo e fraco contra o anterior.


static func multiplier(attacker: String, defender: String) -> float:
	DataDB.ensure_loaded()
	var n := DataDB.type_ids.size()
	if n == 0 or not DataDB.type_index.has(attacker) or not DataDB.type_index.has(defender):
		return DataDB.neutral_mult
	var a: int = DataDB.type_index[attacker]
	var d: int = DataDB.type_index[defender]
	if d == (a + 1) % n:
		return DataDB.strong_mult
	if d == (a - 1 + n) % n:
		return DataDB.weak_mult
	return DataDB.neutral_mult


static func strong_against(type_id: String) -> String:
	var n := DataDB.type_ids.size()
	return DataDB.type_ids[(int(DataDB.type_index[type_id]) + 1) % n]


static func weak_against(type_id: String) -> String:
	var n := DataDB.type_ids.size()
	return DataDB.type_ids[(int(DataDB.type_index[type_id]) - 1 + n) % n]
