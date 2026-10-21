class_name KillRate
extends RefCounted
## Modelo analítico de abates por hora, coerente com o combate em tempo real.
## Usado no progresso offline, na validação anti-trapaça do servidor e na simulação de balanceamento.


## Perfil médio dos inimigos de uma hunt.
static func enemy_profile(hunt: Dictionary) -> Dictionary:
	var lvl := int(hunt.level)
	var world := int(hunt.get("world", 1))
	var total_w := 0.0
	var acc := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	var types := {}
	for m in hunt.monsters:
		var w := float(m.get("weight", 1))
		var s := Formulas.enemy_stats(m.form, lvl, world)
		for k in acc:
			acc[k] += float(s[k]) * w
		var t: String = DataDB.form(m.form).type
		types[t] = float(types.get(t, 0.0)) + w
		total_w += w
	if total_w <= 0.0:
		total_w = 1.0
	for k in acc:
		acc[k] /= total_w
	for t in types:
		types[t] /= total_w
	acc["types"] = types
	acc["level"] = lvl
	return acc


## fighters: Array de stats (MonsterLogic.compute_stats) dos monstros que lutam no mapa.
## Retorna {kills_per_hour, ttk, cycle, deaths_per_hour, dps}
static func estimate(fighters: Array, hunt: Dictionary) -> Dictionary:
	var kr: Dictionary = DataDB.config.killrate
	var cb: Dictionary = DataDB.config.combat
	var e := enemy_profile(hunt)
	if fighters.is_empty():
		return {"kills_per_hour": 0.0, "ttk": INF, "cycle": INF, "deaths_per_hour": 0.0, "dps": 0.0}
	var dps := 0.0
	var party_hp := 0.0
	var party_def := 0.0
	var incoming_type := 0.0
	for f in fighters:
		var per_hit := 0.0
		for t in e.types:
			var tm := TypeChart.multiplier(f.type, t) * (1.0 + float(f.get("type_dmg", {}).get(t, 0.0)) / 100.0)
			per_hit += Formulas.expected_damage(f.atk, e.def, 1.0, tm, f.crit) * float(e.types[t])
			incoming_type += TypeChart.multiplier(t, f.type) * float(e.types[t]) / fighters.size()
		var ab = 1.0 + float(kr.ability_dps_bonus) * float(f.get("ability_power_mult", 1.0)) / max(0.3, float(f.get("ability_cd_mult", 1.0)))
		dps += per_hit / Formulas.attack_interval(f.spd) * ab
		party_hp += f.hp
		party_def += f.def / fighters.size()
	var ttk = e.hp / max(dps, 0.001)
	var density := float(hunt.get("density", 16))
	var travel := float(kr.travel_seconds) * sqrt(16.0 / max(4.0, density))
	travel *= pow(float(kr.extra_fighter_travel_mult), fighters.size() - 1)
	var cycle = ttk + travel
	# dano recebido por ciclo vs regeneração
	var enemy_dps := Formulas.expected_damage(e.atk, party_def, 1.0, incoming_type, float(cb.crit_chance)) / Formulas.enemy_attack_interval(e.spd)
	var engaged := float(kr.engaged_enemies) * (1.0 + 0.15 * (fighters.size() - 1))
	var dmg_per_cycle = enemy_dps * engaged * ttk
	var heal_per_cycle = party_hp * float(cb.regen_pct_per_sec) * cycle
	for f in fighters:
		heal_per_cycle += dmg_per_cycle / fighters.size() * float(f.get("lifesteal", 0.0))
	var net = dmg_per_cycle - heal_per_cycle
	var deaths_per_kill := 0.0
	if dmg_per_cycle > party_hp:
		# o grupo morre antes de completar um abate: progresso quase nulo
		deaths_per_kill = dmg_per_cycle / party_hp
	elif net > 0.0:
		deaths_per_kill = net / party_hp
	cycle += deaths_per_kill * (float(cb.revive_seconds) + ttk)
	var kph = 3600.0 / max(cycle, 0.5)
	if dmg_per_cycle > party_hp:
		kph *= party_hp / dmg_per_cycle * 0.25
	kph = min(kph, float(kr.max_kills_per_hour))
	return {"kills_per_hour": kph, "ttk": ttk, "cycle": cycle, "deaths_per_hour": deaths_per_kill * kph, "dps": dps}


## XP por hora para o monstro principal (lutando) nessa hunt.
static func xp_per_hour(fighters: Array, hunt: Dictionary, main_level: int, xp_bonus_pct := 0.0) -> float:
	var est := estimate(fighters, hunt)
	var lvl := int(hunt.level)
	var xp := Formulas.xp_for_kill(lvl) * Formulas.xp_level_factor(main_level, lvl) * float(hunt.get("xp_mult", 1.0))
	return est.kills_per_hour * xp * (1.0 + xp_bonus_pct / 100.0)
