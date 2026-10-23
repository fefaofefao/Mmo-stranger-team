class_name MonsterLogic
extends RefCounted
## Monstro do jogador (formato salvo):
## {uid, server_id, family, stage, level, xp, shiny, quality(0-100), stars, equip:{slot:item_uid}, caught_at}
## A qualidade é sorteada pelo servidor ao recrutar e dá até +30% de atributos.


static func create(family_id: String, level: int, shiny: bool, uid: String, server_id := "", quality := 0) -> Dictionary:
	var m := {
		"uid": uid, "server_id": server_id if server_id != "" else uid, "family": family_id, "stage": 1,
		"level": max(1, level), "xp": 0.0, "shiny": shiny, "quality": clampi(quality, 0, 100), "stars": 0, "equip": {},
		"caught_at": int(Time.get_unix_time_from_system()),
	}
	m.stage = stage_for_level(family_id, m.level)
	return m


static func create_from_form(form_id: String, level: int, shiny: bool, uid: String, server_id := "", quality := 0) -> Dictionary:
	var f := DataDB.form(form_id)
	var m := create(f.family, level, shiny, uid, server_id, quality)
	# um recrutado de forma adolescente/adulta mantém pelo menos o estágio da forma
	m.stage = max(int(m.stage), int(f.stage))
	return m


static func form_id(m: Dictionary) -> String:
	return "%s_%d" % [m.family, int(m.stage)]


static func form(m: Dictionary) -> Dictionary:
	return DataDB.form(form_id(m))


static func type_of(m: Dictionary) -> String:
	return DataDB.families[m.family].type


## Sorteio de qualidade (usado pelo servidor). Maioria baixa; shiny sempre entre shiny_min e 100.
static func roll_quality(rng: RandomNumberGenerator, shiny: bool) -> int:
	var q: Dictionary = DataDB.config.get("quality", {})
	if shiny:
		var mn := int(q.get("shiny_min", 50))
		return mn + int(round((100 - mn) * pow(rng.randf(), 1.3)))
	return int(round(100.0 * pow(rng.randf(), float(q.get("exponent", 1.8)))))


static func quality_text(m: Dictionary) -> String:
	var q := int(m.get("quality", 0))
	return "%d%% %s" % [q, Loc.tx(DataDB.quality_grade(q).get("name", ""))]


static func quality_color(m: Dictionary) -> Color:
	return Color(DataDB.quality_grade(int(m.get("quality", 0))).get("color", "#ffffff"))


static func display_name(m: Dictionary) -> String:
	var n: String = form(m).get("name", "?")
	if m.get("shiny", false):
		n = "✦ " + n
	return n


static func evo_levels(family_id: String) -> Array:
	var fam: Dictionary = DataDB.families.get(family_id, {})
	return fam.get("evo_levels", DataDB.config.get("evolution_levels", [16, 35]))


static func stage_for_level(family_id: String, level: int) -> int:
	var ev := evo_levels(family_id)
	if level >= int(ev[1]):
		return 3
	if level >= int(ev[0]):
		return 2
	return 1


static func ability_upgrades(m: Dictionary) -> int:
	var n := 0
	for s in DataDB.config.stars.ability_upgrade_stars:
		if int(m.get("stars", 0)) >= int(s):
			n += 1
	return n


## Soma os atributos dos itens equipados. items_by_uid: uid -> item
static func equipment_stats(m: Dictionary, items_by_uid: Dictionary) -> Dictionary:
	var acc := {"type_dmg": {}}
	var t := type_of(m)
	for slot in m.get("equip", {}):
		var it: Dictionary = items_by_uid.get(m.equip[slot], {})
		if it.is_empty():
			continue
		var st := ItemLogic.stats(it, t)
		for k in st:
			if k == "type_dmg":
				for tt in st.type_dmg:
					acc.type_dmg[tt] = float(acc.type_dmg.get(tt, 0.0)) + float(st.type_dmg[tt])
			else:
				acc[k] = float(acc.get(k, 0.0)) + float(st[k])
	return acc


## Atributos finais para combate. bonuses: bônus da conta (Marcos de Caça, ver Mastery.bonuses):
## {hp_pct, atk_pct, def_pct, xp_pct, gold_pct, spd_pct, crit} — drop/recrutamento ficam no servidor.
static func compute_stats(m: Dictionary, items_by_uid: Dictionary = {}, bonuses: Dictionary = {}) -> Dictionary:
	var fid := form_id(m)
	var raw := Formulas.raw_stats(fid, int(m.level), bool(m.get("shiny", false)), int(m.get("quality", 0)))
	var stars := int(m.get("stars", 0))
	var star_mult := 1.0 + float(DataDB.config.stars.stat_bonus_per_star) * stars
	var eq := equipment_stats(m, items_by_uid)
	var up := ability_upgrades(m)
	var cb: Dictionary = DataDB.config.combat
	var tr := int(m.get("train", 0))
	var tc: Dictionary = DataDB.config.train
	var t_ad := 1.0 + float(tc.atk_def_per_level) * tr
	var t_hp := 1.0 + float(tc.hp_per_level) * tr
	var atk_pct := float(eq.get("atk_pct", 0.0)) + float(bonuses.get("atk_pct", 0.0))
	var s := {
		"form_id": fid,
		"type": type_of(m),
		"level": int(m.level),
		"hp": (raw.hp * star_mult * t_hp + float(eq.get("hp", 0.0))) * (1.0 + (float(eq.get("hp_pct", 0.0)) + float(bonuses.get("hp_pct", 0.0))) / 100.0),
		"atk": (raw.atk * star_mult * t_ad + float(eq.get("atk", 0.0))) * (1.0 + atk_pct / 100.0),
		"def": (raw.def * star_mult * t_ad + float(eq.get("def", 0.0))) * (1.0 + (float(eq.get("def_pct", 0.0)) + float(bonuses.get("def_pct", 0.0))) / 100.0),
		"spd": raw.spd * (1.0 + 0.02 * stars) * (1.0 + (float(eq.get("spd_pct", 0.0)) + float(bonuses.get("spd_pct", 0.0))) / 100.0),
		"rng": raw.rng,
		"crit": float(cb.crit_chance) + (float(eq.get("crit", 0.0)) + float(bonuses.get("crit", 0.0))) / 100.0,
		"lifesteal": float(eq.get("lifesteal", 0.0)) / 100.0,
		"xp_pct": float(eq.get("xp_pct", 0.0)) + float(bonuses.get("xp_pct", 0.0)),
		"gold_pct": float(eq.get("gold_pct", 0.0)) + float(bonuses.get("gold_pct", 0.0)),
		"type_dmg": eq.type_dmg,
		"ability_power_mult": 1.0 + float(DataDB.config.stars.ability_power_per_upgrade) * up,
		"ability_cd_mult": (1.0 - float(DataDB.config.stars.ability_cd_per_upgrade) * up) * (1.0 - float(eq.get("cdr", 0.0)) / 100.0),
		"abilities": form(m).get("abilities", []),
		"style": form(m).get("style", "melee"),
		"train": tr,
	}
	return s


## "Poder" exibido na UI (aproximação de DPS x sobrevivência).
static func power(stats: Dictionary) -> int:
	var dps: float = stats.atk * 100.0 / Formulas.attack_interval(stats.spd) / 100.0
	return int(round(sqrt(max(1.0, dps * (stats.hp + stats.def * 4.0))) * 2.0))


## Adiciona XP e trata subida de nível e evolução. Retorna eventos {levels, evolved_to}.
static func add_xp(m: Dictionary, amount: float) -> Dictionary:
	var ev := {"levels": 0, "evolved": false, "from_form": form_id(m)}
	var max_level := int(DataDB.config.max_level)
	if int(m.level) >= max_level:
		m.xp = 0.0
		return ev
	m.xp = float(m.get("xp", 0.0)) + amount
	while int(m.level) < max_level:
		var need := Formulas.xp_to_next(int(m.level))
		if float(m.xp) < need:
			break
		m.xp = float(m.xp) - need
		m.level = int(m.level) + 1
		ev.levels += 1
	if int(m.level) >= max_level:
		m.xp = 0.0
	var new_stage := max(int(m.stage), stage_for_level(m.family, int(m.level)))
	if new_stage != int(m.stage):
		m.stage = new_stage
		ev.evolved = true
	ev["to_form"] = form_id(m)
	return ev


static func set_level(m: Dictionary, level: int) -> void:
	m.level = clampi(level, 1, int(DataDB.config.max_level))
	m.xp = 0.0
	m.stage = max(int(m.stage), stage_for_level(m.family, int(m.level)))


## Brilho do treino: 0 = nenhum, 1 = brilho (+5), 2 = intenso (+10), 3 = radiante (+15).
static func glow_tier(m: Dictionary) -> int:
	var t := int(m.get("train", 0))
	var g := 0
	for lv in DataDB.config.train.glow_levels:
		if t >= int(lv):
			g += 1
	return g
