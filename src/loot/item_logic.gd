class_name ItemLogic
extends RefCounted
## Criação, atributos e descrição de itens.
## Formato de item: {uid, base, rarity, enh, affixes:[{id,v,t?}], bound, locked}
## bound=true => item criado pelo cliente (Comum/Incomum), não negociável no market.

const STAT_NAMES := {
	"hp": "HP", "atk": "Ataque", "def": "Defesa", "spd_pct": "Velocidade", "crit": "Crítico",
	"hp_pct": "HP", "atk_pct": "Ataque", "def_pct": "Defesa", "lifesteal": "Roubo de vida",
	"cdr": "Recarga", "xp_pct": "XP", "gold_pct": "Ouro",
}


static func stat_name(k: String) -> String:
	var n: String = STAT_NAMES.get(k, k)
	return Loc.t(n) if n != "HP" and n != "XP" else n


static func new_uid(prefix: String, rng: RandomNumberGenerator) -> String:
	return "%s%x%06x" % [prefix, int(Time.get_unix_time_from_system()) & 0xffffff, rng.randi() & 0xffffff]


static func base(item: Dictionary) -> Dictionary:
	return DataDB.item_bases.get(item.get("base", ""), {})


static func create(base_id: String, rarity_id: String, rng: RandomNumberGenerator, bound: bool, uid := "") -> Dictionary:
	var b: Dictionary = DataDB.item_bases.get(base_id, {})
	if b.is_empty():
		return {}
	var it := {
		"uid": uid if uid != "" else new_uid("l" if bound else "s", rng),
		"base": base_id, "rarity": rarity_id, "enh": 0, "affixes": roll_affixes(rarity_id, rng),
		"bound": bound, "locked": false,
	}
	return it


static func roll_affixes(rarity_id: String, rng: RandomNumberGenerator) -> Array:
	var n := int(DataDB.rarity(rarity_id).get("affixes", 0))
	var out: Array = []
	var pool := DataDB.affixes.duplicate()
	var ri := float(DataDB.rarity_index.get(rarity_id, 0))
	for i in n:
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		var a: Dictionary = pool[idx]
		pool.remove_at(idx)
		# raridades maiores puxam o valor para cima
		var t := clampf(rng.randf() * 0.7 + (ri - 3.0) * 0.15, 0.0, 1.0)
		var v := int(round(lerpf(float(a.min), float(a.max), t)))
		var aff := {"id": a.id, "v": v}
		if a.get("per_type", false):
			aff["t"] = DataDB.type_ids[rng.randi_range(0, DataDB.type_ids.size() - 1)]
		out.append(aff)
	return out


static func affix_def(id: String) -> Dictionary:
	for a in DataDB.affixes:
		if a.id == id:
			return a
	return {}


static func main_value(item: Dictionary) -> float:
	var b := base(item)
	if b.is_empty():
		return 0.0
	var cfg: Dictionary = DataDB.config.items
	var rm := float(DataDB.rarity(item.rarity).stat_mult)
	var em := 1.0 + float(DataDB.config.enhance.stat_per_level) * int(item.get("enh", 0))
	if b.slot == "reliquia":
		var r: Dictionary = cfg.reliquia
		return (float(r.spd_pct_base) + float(r.spd_pct_per_tier) * int(b.tier)) * rm * em
	return float(cfg.base_stats[b.main_stat]) * Formulas.level_mult(int(b.level)) * rm * em


## Atributos que o item concede. wearer_type ativa o bônus de tipo combinando.
static func stats(item: Dictionary, wearer_type := "") -> Dictionary:
	var out := {}
	var b := base(item)
	if b.is_empty():
		return out
	var cfg: Dictionary = DataDB.config.items
	var match_mult := 1.0 + (float(cfg.type_match_bonus) if wearer_type == b.type else 0.0)
	var v := main_value(item) * match_mult
	if b.slot == "reliquia":
		var r: Dictionary = cfg.reliquia
		var rm := float(DataDB.rarity(item.rarity).stat_mult)
		var em := 1.0 + float(DataDB.config.enhance.stat_per_level) * int(item.get("enh", 0))
		out["spd_pct"] = v
		out["crit"] = (float(r.crit_base) + float(r.crit_per_tier) * int(b.tier)) * rm * em * match_mult
	else:
		out[b.main_stat] = v
	for a in item.get("affixes", []):
		if a.id == "type_dmg":
			if not out.has("type_dmg"):
				out["type_dmg"] = {}
			out.type_dmg[a.t] = float(out.type_dmg.get(a.t, 0.0)) + float(a.v)
		else:
			out[a.id] = float(out.get(a.id, 0.0)) + float(a.v)
	return out


static func display_name(item: Dictionary) -> String:
	var b := base(item)
	var n: String = Loc.tx(b.get("name", "?"))
	if int(item.get("enh", 0)) > 0:
		n += " +%d" % int(item.enh)
	return n


static func describe(item: Dictionary, wearer_type := "") -> Array:
	var lines: Array = []
	var b := base(item)
	if b.is_empty():
		return lines
	lines.append("%s · %s · %s" % [DataDB.rarity_name(item.rarity), _slot_name(b.slot), Loc.t("Nv %d") % int(b.level)])
	var st := stats(item, wearer_type)
	for k in st:
		if k == "type_dmg":
			for t in st.type_dmg:
				lines.append(Loc.t("+%d%% dano contra %s") % [int(st.type_dmg[t]), DataDB.type_name(t)])
		elif k in ["hp", "atk", "def"]:
			lines.append("+%d %s" % [int(round(st[k])), stat_name(k)])
		elif k == "cdr":
			lines.append("-%.1f%% %s" % [st[k], stat_name(k)])
		else:
			lines.append("+%.1f%% %s" % [st[k], stat_name(k)])
	lines.append(Loc.t("Tema %s (+%d%% no tipo)") % [DataDB.type_name(b.type), int(float(DataDB.config.items.type_match_bonus) * 100)])
	if item.get("bound", false):
		lines.append(Loc.t("Vinculado"))
	return lines


static func _slot_name(slot: String) -> String:
	for s in DataDB.item_slots:
		if s.id == slot:
			return Loc.tx(s.name)
	return slot


static func slot_name(slot: String) -> String:
	return _slot_name(slot)


static func sell_price(item: Dictionary) -> int:
	var b := base(item)
	if b.is_empty():
		return 0
	var cfg: Dictionary = DataDB.config.items
	var p := float(cfg.sell_base) * (1.0 + float(cfg.sell_per_level) * int(b.level)) * float(DataDB.rarity(item.rarity).sell_mult)
	p *= 1.0 + 0.25 * int(item.get("enh", 0))
	return int(round(p))


static func shop_price(base_id: String) -> int:
	var it := {"base": base_id, "rarity": "comum", "enh": 0}
	return int(sell_price(it) * float(DataDB.config.shop.price_mult))


static func power_score(item: Dictionary) -> float:
	return main_value(item) + 3.0 * item.get("affixes", []).size()
