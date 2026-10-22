class_name EssenceLogic
extends RefCounted
## Altar de Essências: conversão de monstros, custo de estrelas e aprimoramento de itens.


## Quantidade de Essência (do tipo do monstro) obtida ao trocar um monstro no Altar.
static func essence_value(m: Dictionary) -> int:
	var e: Dictionary = DataDB.config.essence
	var fam: Dictionary = DataDB.families.get(m.family, {})
	var stage := clampi(int(m.stage), 1, 3)
	var v := float(e.stage_base[stage - 1]) * (1.0 + float(m.level) / float(e.level_div))
	v *= float(fam.get("essence_mult", 1.0))
	v *= 1.0 + 0.2 * int(m.get("stars", 0))
	v *= 1.0 + int(m.get("quality", 0)) / 100.0
	if m.get("shiny", false):
		v *= float(e.shiny_mult)
	return int(round(v))


## Custo em Essência para a próxima estrela. -1 se já está no máximo.
static func star_cost(m: Dictionary) -> int:
	var s: Dictionary = DataDB.config.stars
	var cur := int(m.get("stars", 0))
	if cur >= int(s.max):
		return -1
	return int(s.cost[cur])


static func enhance_cost(item: Dictionary) -> Dictionary:
	var e: Dictionary = DataDB.config.enhance
	var b := ItemLogic.base(item)
	var tier := int(b.get("tier", 1))
	var enh := int(item.get("enh", 0))
	return {
		"essence_type": b.get("type", "agua"),
		"essence": int(float(e.essence_cost_per_tier) * tier * (enh + 1)),
		"gold": int(float(e.gold_cost_per_tier) * tier * pow(enh + 1, 1.5)),
	}


## Chance de sucesso para ir de enh -> enh+1.
static func enhance_chance(enh: int) -> float:
	var e: Dictionary = DataDB.config.enhance
	if enh >= int(e.max):
		return 0.0
	return float(e.success[enh])


## Tenta aprimorar (o item NUNCA é destruído). Retorna true em caso de sucesso.
static func try_enhance(item: Dictionary, rng: RandomNumberGenerator) -> bool:
	var enh := int(item.get("enh", 0))
	if enh >= int(DataDB.config.enhance.max):
		return false
	if rng.randf() < enhance_chance(enh):
		item.enh = enh + 1
		return true
	return false
