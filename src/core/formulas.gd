class_name Formulas
extends RefCounted
## Fórmulas centrais de balanceamento. Usadas pelo combate em tempo real, pelo cálculo offline,
## pelo servidor mock e pela simulação. A Edge Function do Supabase replica estas fórmulas.


static func c() -> Dictionary:
	DataDB.ensure_loaded()
	return DataDB.config


static func level_mult(level: int) -> float:
	return 1.0 + float(c().stat_growth_per_level) * float(max(level, 1) - 1)


## Atributos "crus" de uma forma em um nível (sem itens, estrelas ou bônus).
static func quality_mult(quality: int) -> float:
	return 1.0 + float(c().get("quality", {}).get("max_bonus", 0.3)) * clampf(quality / 100.0, 0.0, 1.0)


static func raw_stats(form_id: String, level: int, shiny := false, quality := 0) -> Dictionary:
	var f := DataDB.form(form_id)
	var fam: Dictionary = DataDB.families.get(f.get("family", ""), {})
	if fam.is_empty():
		return {"hp": 1.0, "atk": 1.0, "def": 1.0, "spd": 100.0, "rng": 1}
	var stage: int = f.stage
	var lm := level_mult(level)
	var sm := float(c().stage_mult[stage - 1])
	var ssm := float(c().stage_spd_mult[stage - 1])
	var sh := (1.0 + (float(c().shiny_stat_bonus) if shiny else 0.0)) * quality_mult(quality)
	var b: Dictionary = fam.base
	return {
		"hp": float(b.hp) * lm * sm * sh,
		"atk": float(b.atk) * lm * sm * sh,
		"def": float(b.def) * lm * sm * sh,
		"spd": float(b.spd) * ssm * sh,
		"rng": int(b.rng),
	}


## Atributos de um monstro selvagem (inimigo) em uma hunt.
static func enemy_stats(form_id: String, level: int, world := 1, shiny := false) -> Dictionary:
	var s := raw_stats(form_id, level, shiny)
	var m1: Dictionary = c().enemy_mods
	var t := 0.0
	var m2: Dictionary = m1
	if world == 2:
		# o Mundo 2 endurece aos poucos (rampa), para não virar um muro entre 90 e 110
		var w2: Dictionary = c().world2
		m2 = w2.get("enemy_mods", m1)
		t = clampf(float(level - int(w2.start)) / float(w2.get("mods_ramp_levels", 30)), 0.0, 1.0)
	for k in ["hp", "atk", "def"]:
		s[k] *= lerpf(float(m1[k]), float(m2[k]), t)
	return s


# ---------------------------------------------------------------- XP

## Quantidade de abates (de inimigos do mesmo nível) necessária para subir do nível L para L+1.
static func kills_for_level(level: int) -> float:
	var x: Dictionary = c().xp
	var k := float(x.kills_min) + float(x.kills_a) * pow(float(level), float(x.kills_p))
	var late := float(level - int(x.late_start))
	if late > 0:
		k *= 1.0 + float(x.late_slope) * late
	# início acelerado: os primeiros níveis passam rápido para fisgar o jogador
	var early := int(x.get("early_levels", 0))
	if level < early:
		k *= lerpf(float(x.get("early_mult_start", 1.0)), 1.0, float(level - 1) / float(early - 1))
	return k


static func xp_for_kill(enemy_level: int) -> float:
	var x: Dictionary = c().xp
	return floor(float(x.kill_base) * pow(float(max(enemy_level, 1)), float(x.kill_q)))


static func xp_to_next(level: int) -> int:
	if level >= int(c().max_level):
		return 0
	return int(ceil(kills_for_level(level) * xp_for_kill(level)))


## Penalidade por caçar monstros muito abaixo do nível.
static func xp_level_factor(monster_level: int, enemy_level: int) -> float:
	var x: Dictionary = c().xp
	var diff := monster_level - enemy_level - int(x.low_level_penalty_start)
	if diff <= 0:
		return 1.0
	return max(float(x.low_level_penalty_min), 1.0 - diff * float(x.low_level_penalty_per_level))


static func total_xp_for_level(level: int) -> float:
	var t := 0.0
	for l in range(1, level):
		t += xp_to_next(l)
	return t


static func gold_for_kill(enemy_level: int) -> int:
	var g: Dictionary = c().gold
	return int(floor(float(g.kill_base) * pow(float(max(enemy_level, 1)), float(g.kill_q)))) + 1


# ---------------------------------------------------------------- dano

static func damage_raw(atk: float, def: float, power: float) -> float:
	if atk <= 0.0:
		return 0.0
	return atk * power * atk / (atk + max(def, 0.0))


static func roll_damage(atk: float, def: float, power: float, type_mult: float, rng: RandomNumberGenerator,
		crit_chance: float) -> Dictionary:
	var cb: Dictionary = c().combat
	var v := float(cb.damage_variance)
	var dmg := damage_raw(atk, def, power) * type_mult * rng.randf_range(1.0 - v, 1.0 + v)
	var crit := rng.randf() < crit_chance
	if crit:
		dmg *= float(cb.crit_mult)
	return {"dmg": max(1.0, round(dmg)), "crit": crit}


static func expected_damage(atk: float, def: float, power: float, type_mult: float, crit_chance: float) -> float:
	var cm := float(c().combat.crit_mult)
	return max(1.0, damage_raw(atk, def, power) * type_mult) * (1.0 + crit_chance * (cm - 1.0))


static func attack_interval(spd: float) -> float:
	return float(c().combat.base_attack_interval) * 100.0 / max(spd, 10.0)


static func enemy_attack_interval(spd: float) -> float:
	return float(c().combat.enemy_attack_interval) * 100.0 / max(spd, 10.0)


static func move_speed(spd: float) -> float:
	return float(c().combat.base_move_speed) * max(spd, 10.0) / 100.0


static func enemy_move_speed(spd: float) -> float:
	return float(c().combat.enemy_move_speed) * max(spd, 10.0) / 100.0
