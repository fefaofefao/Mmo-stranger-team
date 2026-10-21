class_name PartyLogic
extends RefCounted
## Regras do grupo: quantos monstros lutam no mapa e divisão de XP.


## Quantos monstros do grupo lutam no mapa, de acordo com o nível do monstro principal.
static func fighting_count(main_level: int, party_size: int) -> int:
	var p: Dictionary = DataDB.config.party
	var n := 1
	if main_level >= int(p.unlock_3):
		n = 3
	elif main_level >= int(p.unlock_2):
		n = 2
	return clampi(n, 1, max(1, party_size))


## Fração de XP que cada posição do grupo recebe em um abate.
## Retorna um Array de floats com o mesmo tamanho do grupo.
static func xp_shares(main_level: int, party_size: int) -> Array:
	var p: Dictionary = DataDB.config.party
	var fighting := fighting_count(main_level, party_size)
	var out: Array = []
	for i in party_size:
		out.append(float(p.fighting_xp_share) if i < fighting else float(p.bench_xp_share))
	return out


## Distribui XP de um abate entre os membros. base_xp = XP do abate para quem está lutando.
## party: Array de monstros. Retorna Array de XP concedida a cada um.
static func split_xp(party: Array, base_xp: float, enemy_level: int, xp_bonus_pct := 0.0) -> Array:
	if party.is_empty():
		return []
	var shares := xp_shares(int(party[0].level), party.size())
	var out: Array = []
	for i in party.size():
		var m: Dictionary = party[i]
		var f := Formulas.xp_level_factor(int(m.level), enemy_level)
		out.append(base_xp * float(shares[i]) * f * (1.0 + xp_bonus_pct / 100.0))
	return out
