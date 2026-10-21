class_name LootTable
extends RefCounted
## Sorteio de raridade e base de item por abate.
## O cliente sorteia apenas raridades com "server": false (Comum/Incomum, vinculadas).
## Raro ou superior é sorteado pelo servidor (ServerLogic / Edge Function).


## Sorteia uma raridade entre as permitidas. Retorna "" se não houver drop.
## server_side=true considera apenas raridades "server"; false apenas as locais.
static func roll_rarity(rng: RandomNumberGenerator, server_side: bool, rarity_mult := 1.0) -> String:
	var rs := DataDB.rarities
	for i in range(rs.size() - 1, -1, -1):
		var r: Dictionary = rs[i]
		if bool(r.server) != server_side:
			continue
		var ch := float(r.chance) * (rarity_mult if server_side else 1.0)
		if rng.randf() < ch:
			return r.id
	return ""


## Probabilidade de drop por abate para cada raridade (para relatórios e testes).
static func chance(rarity_id: String, rarity_mult := 1.0) -> float:
	var r := DataDB.rarity(rarity_id)
	return float(r.chance) * (rarity_mult if r.server else 1.0)


static func pick_base(hunt: Dictionary, rng: RandomNumberGenerator) -> String:
	var drops: Array = hunt.get("drops", [])
	if drops.is_empty():
		return ""
	var total := 0.0
	for d in drops:
		total += float(d.weight)
	var r := rng.randf() * total
	for d in drops:
		r -= float(d.weight)
		if r <= 0.0:
			return d.base
	return drops[drops.size() - 1].base


## Quantos sorteios "binomiais" saem em n tentativas com chance p (aproximação para offline).
static func binomial(n: int, p: float, rng: RandomNumberGenerator) -> int:
	if n <= 0 or p <= 0.0:
		return 0
	if n < 200:
		var k := 0
		for i in n:
			if rng.randf() < p:
				k += 1
		return k
	var mean := n * p
	if mean < 30.0:
		# Poisson por inversão
		var l := exp(-mean)
		var k2 := 0
		var prod := rng.randf()
		while prod > l and k2 < n:
			k2 += 1
			prod *= rng.randf()
		return k2
	var sd := sqrt(mean * (1.0 - p))
	return clampi(int(round(rng.randfn(mean, sd))), 0, n)
