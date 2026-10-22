class_name Mastery
extends RefCounted
## Marcos de Caça: cada forma tem 6 marcos de abates (Bronze → Lenda). Cada marco dá pontos
## no atributo ligado ao TIPO da forma (água = Vida, fogo = Ataque, gelo = Defesa, planta = XP,
## terra = Ouro, elétrico = Velocidade, vento = Sorte de drop, luz = Recrutamento, sombra = Crítico).
## Os bônus somam na conta inteira e valem para todos os monstros.
## O mesmo cálculo existe no servidor (supabase/functions/_shared/logic.ts: masteryBonuses).

const STATS := ["hp_pct", "atk_pct", "def_pct", "xp_pct", "gold_pct", "spd_pct", "drop_pct", "recruit_pct", "crit"]


static func cfg() -> Dictionary:
	return DataDB.config.mastery


static func tiers() -> Array:
	return cfg().tiers


## Quantos marcos a forma já atingiu (0..6).
static func tier_of(kills: int) -> int:
	var t := 0
	for need in tiers():
		if kills >= int(need):
			t += 1
	return t


## Pontos acumulados ao atingir `tier` marcos.
static func points_at(tier: int) -> int:
	var p := 0
	var pts: Array = cfg().points
	for i in mini(tier, pts.size()):
		p += int(pts[i])
	return p


static func stat_of_type(type_id: String) -> Dictionary:
	return cfg().by_type.get(type_id, {"stat": "atk_pct", "per_point": 0.0})


static func stat_of_form(form_id: String) -> Dictionary:
	return stat_of_type(DataDB.form(form_id).get("type", "agua"))


## Situação de uma forma: marco atual, próximo, bônus já conquistado e bônus do próximo marco.
static func form_info(form_id: String, kills: int) -> Dictionary:
	var st := stat_of_form(form_id)
	var tier := tier_of(kills)
	var ts := tiers()
	var per := float(st.per_point)
	var info := {
		"stat": st.stat, "tier": tier, "kills": kills, "max": tier >= ts.size(),
		"earned": points_at(tier) * per,
		"prev_at": int(ts[tier - 1]) if tier > 0 else 0,
		"next_at": int(ts[tier]) if tier < ts.size() else int(ts[ts.size() - 1]),
		"next_gain": float(cfg().points[tier]) * per if tier < ts.size() else 0.0,
	}
	var span := maxf(1.0, float(info.next_at - info.prev_at))
	info["progress"] = 1.0 if info.max else clampf(float(kills - int(info.prev_at)) / span, 0.0, 1.0)
	return info


## Bônus da conta a partir de {form_id: abates}.
static func bonuses(kills_by_form: Dictionary) -> Dictionary:
	var out := {"points": 0, "tiers": 0}
	for s in STATS:
		out[s] = 0.0
	for fid in kills_by_form:
		var k := int(kills_by_form[fid])
		if k < int(tiers()[0]) or not DataDB.forms.has(fid):
			continue
		var tier := tier_of(k)
		var pts := points_at(tier)
		var st := stat_of_form(fid)
		out[st.stat] = float(out[st.stat]) + pts * float(st.per_point)
		out.points = int(out.points) + pts
		out.tiers = int(out.tiers) + tier
	return out


static func tier_name(tier: int) -> String:
	if tier <= 0:
		return Loc.t("Sem marco")
	return Loc.tx(cfg().tier_names[mini(tier, 6) - 1])


static func tier_color(tier: int) -> Color:
	if tier <= 0:
		return UI.C_MUTED
	return Color(cfg().tier_colors[mini(tier, 6) - 1])


static func stat_name(stat: String) -> String:
	return Loc.tx(cfg().stat_info.get(stat, {}).get("name", stat))


static func stat_icon(stat: String) -> String:
	return cfg().stat_info.get(stat, {}).get("icon", "star")


## "+1,25% Vida" / "+0,40% Crítico"
static func fmt_bonus(stat: String, value: float) -> String:
	var txt := ("%.2f" % value).rstrip("0").rstrip(".")
	if Loc.locale != "en":
		txt = txt.replace(".", ",")
	return "+%s%% %s" % [txt, stat_name(stat)]
