class_name ServerLogic
extends RefCounted
## Regras AUTORITATIVAS do servidor. No modo mock roda localmente (MockBackend) com estado
## separado do save do jogador. A Edge Function do Supabase (supabase/functions/game) replica
## exatamente estas regras em TypeScript.
##
## Tudo que tem valor de troca é decidido aqui: ouro, Essência, itens Raro+ (negociáveis),
## shinies (tickets de spawn), recrutamentos, estrelas, recompensas de desafio e o market.

const FAKE_NAMES := ["Ana_Caçadora", "Bruno99", "CaioTamer", "Duda_Shiny", "EduardoRK", "Fê_Monstros", "Gabi_Lv", "HugoBR",
	"Iara_Mar", "JoãoFarm", "Kika", "LeoTibiano", "Mari_Pro", "Nina_Idle", "OtávioX", "PedroLobo", "Quel", "Rafa_Hunter",
	"Sofia_Luz", "Téo_Sombra", "Ulisses", "Vivi_Gelo", "Wesley_Raio", "Xandão", "Yara", "Zeca_Terra", "Lumi_Fan",
	"BrasaBR", "Gotelino", "MestreDasHunts", "NoobPro", "CapivaraTamer", "Tia_Coleção", "Shinyzeira", "Raio_Veloz",
	"Pé_de_Pano", "Corvo_Noturno", "Vento_Sul", "Pedra_Bruta", "Flor_de_Lis"]

var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var now_func: Callable
## Forçar resultados (somente build debug + mock): {shiny:int, drop:"raridade", recruit:int}
var debug_force: Dictionary = {}


func _init(initial_state: Dictionary = {}, clock: Callable = Callable()) -> void:
	DataDB.ensure_loaded()
	state = initial_state
	now_func = clock
	rng.randomize()
	if state.is_empty():
		state = {"version": 1, "player": {}, "listings": {}, "fake_players": [], "next_id": 1, "sales_log": []}


func now() -> float:
	if now_func.is_valid():
		return float(now_func.call())
	return GameClock.now()


func _id(prefix: String) -> String:
	state.next_id = int(state.get("next_id", 1)) + 1
	return "%s%d_%x" % [prefix, int(state.next_id), rng.randi() & 0xffff]


func p() -> Dictionary:
	return state.player


func _ok(extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true}
	d.merge(extra)
	return d


func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}


func wallet() -> Dictionary:
	return {"gold": int(p().gold), "essences": p().essences.duplicate(), "diamonds": int(p().get("diamonds", 0))}


static func week_id(t: float) -> int:
	# semanas começando na segunda-feira (epoch foi quinta-feira => +3 dias)
	return int(floor((t + 3.0 * 86400.0) / 604800.0))


# ------------------------------------------------------------------ conta

func login(device_id: String) -> Dictionary:
	if p().is_empty() or p().get("device_id", "") != device_id:
		if p().is_empty():
			var t := now()
			state.player = {
				"id": _id("u"), "device_id": device_id, "name": "Jogador%d" % (rng.randi() % 9000 + 1000),
				"created_at": t, "last_claim_at": t, "last_seen_at": t, "gold": 0, "essences": {},
				"npc_budget": 0.0, "validated_level": 1, "validated_at": t, "monsters": {}, "tickets": {},
				"challenges": {}, "items": {}, "stats": {"kills": 0}, "weekly": {}, "google_linked": false,
				"last_offline": {}, "mastery": {},
			}
			for tid in DataDB.type_ids:
				p().essences[tid] = 0
		else:
			p().device_id = device_id
	_seed_fake_world()
	return _ok({"player_id": p().id, "name": p().name, "wallet": wallet(), "google_linked": p().google_linked})


func link_google(email: String) -> Dictionary:
	p().google_linked = true
	p().google_email = email
	return _ok({"google_linked": true})


func set_name(name: String) -> Dictionary:
	name = name.strip_edges().substr(0, 20)
	if name.length() < 3:
		return _err("Nome muito curto")
	p().name = name
	return _ok({"name": name})


func get_profile() -> Dictionary:
	_simulate_fake_buyers()
	var sales: Array = state.get("sales_log", [])
	state.sales_log = []
	return _ok({"player_id": p().id, "name": p().name, "wallet": wallet(), "items": p().items.values(),
		"monsters": p().monsters, "sales": sales, "server_time": now(), "google_linked": p().google_linked,
		"mastery": p().get("mastery", {})})


func touch() -> void:
	p().last_seen_at = now()


# ------------------------------------------------------------------ monstros

func register_starter(family_id: String) -> Dictionary:
	var fam: Dictionary = DataDB.families.get(family_id, {})
	if fam.is_empty() or not fam.get("starter", false):
		return _err("Inicial inválido")
	for m in p().monsters.values():
		if m.get("starter", false):
			return _ok({"monster": m})
	var sid := _id("m")
	var rec := {"server_id": sid, "family": family_id, "form": fam.stages[0].form_id, "shiny": false, "stars": 0,
		"converted": false, "starter": true, "quality": int(DataDB.config.get("quality", {}).get("starter", 50))}
	p().monsters[sid] = rec
	return _ok({"monster": rec})


func _party_upper_stats(party: Array) -> Array:
	# stats máximos plausíveis para o grupo (nível validado + folga, equipamento generoso)
	var ac: Dictionary = DataDB.config.anti_cheat
	var allowance := float(ac.get("gear_allowance", 1.8))
	var out: Array = []
	for pm in party:
		var lvl := mini(int(pm.get("level", 1)), int(p().validated_level) + 10)
		var rec: Dictionary = p().monsters.get(pm.get("server_id", ""), {})
		var fam_id: String = rec.get("family", pm.get("family", ""))
		if not DataDB.families.has(fam_id):
			continue
		var m := MonsterLogic.create(fam_id, lvl, bool(rec.get("shiny", false)), "tmp", "", int(rec.get("quality", 100)))
		m.stage = maxi(int(m.stage), int(pm.get("stage", 1)))
		m.stars = int(rec.get("stars", 0))
		m.train = int(rec.get("train", 0))
		var s := MonsterLogic.compute_stats(m, {}, _mastery())
		s.hp *= allowance
		s.atk *= allowance
		s.def *= allowance
		s.spd *= 1.25
		s.crit += 0.1
		out.append(s)
	return out


## Usa os stats enviados pelo cliente, limitados ao máximo plausível.
func _party_capped_stats(party: Array, client_stats: Array) -> Array:
	var upper := _party_upper_stats(party)
	var out: Array = []
	for i in upper.size():
		var u: Dictionary = upper[i]
		var s: Dictionary = u.duplicate(true)
		if i < client_stats.size():
			var cs: Dictionary = client_stats[i]
			for k in ["hp", "atk", "def", "spd", "crit"]:
				if cs.has(k):
					s[k] = minf(float(cs[k]), float(u[k]))
		out.append(s)
	return out


func _fighters(party: Array, stats: Array) -> Array:
	if party.is_empty():
		return []
	var n := PartyLogic.fighting_count(int(party[0].get("level", 1)), party.size())
	return stats.slice(0, n)


func request_spawn_tickets(hunt_id: String, n: int) -> Dictionary:
	if not DataDB.hunts.has(hunt_id) and not hunt_id.begins_with("c"):
		return _err("Hunt inválida")
	n = clampi(n, 1, 100)
	# limpa tickets antigos
	var t := now()
	for k in p().tickets.keys():
		if t - float(p().tickets[k].t) > 3600.0 * 6:
			p().tickets.erase(k)
	var out: Array = []
	var shiny_ch := float(DataDB.config.shiny_chance) * boost_mult("shiny")
	for i in n:
		var shiny := rng.randf() < shiny_ch
		if int(debug_force.get("shiny", 0)) > 0:
			shiny = true
			debug_force.shiny = int(debug_force.shiny) - 1
		var id := _id("t")
		p().tickets[id] = {"hunt": hunt_id, "shiny": shiny, "used": false, "t": t}
		out.append({"id": id, "shiny": shiny})
	return _ok({"tickets": out})


func _roll_recruit(hunt: Dictionary, form_id: String, shiny: bool) -> Dictionary:
	if int(hunt.get("world", 1)) != 1 or not hunt.get("recruit", true):
		return {}
	var ch := float(DataDB.config.recruit_chance) * float(hunt.get("recruit_mult", 1.0)) * (1.0 + float(_mastery().recruit_pct) / 100.0) * boost_mult("recruit")
	if shiny:
		ch *= float(DataDB.config.get("shiny_recruit_mult", 10.0))
	var forced := int(debug_force.get("recruit", 0)) > 0
	if forced:
		debug_force.recruit = int(debug_force.recruit) - 1
	if not forced and rng.randf() >= ch:
		return {}
	var f := DataDB.form(form_id)
	var sid := _id("m")
	var rec := {"server_id": sid, "family": f.family, "form": form_id, "shiny": shiny, "stars": 0, "converted": false,
		"quality": MonsterLogic.roll_quality(rng, shiny)}
	p().monsters[sid] = rec
	return rec


func _roll_server_drop(hunt: Dictionary, luck := 1.0) -> Dictionary:
	var rar := LootTable.roll_rarity(rng, true, float(hunt.get("rarity_mult", 1.0)), luck)
	var forced: String = debug_force.get("drop", "")
	if forced != "":
		rar = forced
		debug_force.drop = ""
	if rar == "":
		return {}
	var base_id := LootTable.pick_base(hunt, rng)
	if base_id == "":
		return {}
	var it := ItemLogic.create(base_id, rar, rng, false, _id("s"))
	p().items[it.uid] = it
	return it


## Ouro: bônus do equipamento informado pelo cliente (limitado) + Marcos validados pelo servidor.
func _gold_mult(gold_pct: float, boost := -1.0) -> float:
	var b := boost_mult("gold") if boost < 0.0 else boost
	return (1.0 + clampf(gold_pct, 0.0, 100.0) / 100.0 + float(_mastery().gold_pct) / 100.0) * b


## Bônus dos Marcos de Caça a partir dos abates aceitos pelo servidor.
func _mastery() -> Dictionary:
	return Mastery.bonuses(p().get("mastery", {}))


func _add_mastery(form_id: String, n: int) -> void:
	if not p().has("mastery"):
		p().mastery = {}
	p().mastery[form_id] = int(p().mastery.get(form_id, 0)) + n


## Abates em tempo real (enviados em lote pelo cliente).
## kills: [{form, level, ticket}] ; party: [{server_id, family, stage, level}] ; stats: stats do cliente
func claim_kills(hunt_id: String, kills: Array, party: Array, client_stats: Array, gold_pct := 0.0) -> Dictionary:
	var hunt: Dictionary = DataDB.hunts.get(hunt_id, {})
	if hunt.is_empty():
		return _err("Hunt inválida")
	var ac: Dictionary = DataDB.config.anti_cheat
	var t := now()
	var elapsed := clampf(t - float(p().last_claim_at), 0.0, float(ac.claim_max_seconds))
	p().last_claim_at = t
	p().last_seen_at = t
	var fighters := _fighters(party, _party_upper_stats(party))
	var est := KillRate.estimate(fighters, hunt)
	var allowed := int(est.kills_per_hour * elapsed / 3600.0 * float(ac.kill_rate_tolerance)) + 3
	var accepted := mini(kills.size(), allowed)
	var gold := 0
	var items: Array = []
	var recruits: Array = []
	var shinies := 0
	var valid_forms := {}
	for m in hunt.monsters:
		valid_forms[m.form] = true
	var lvl_min := int(hunt.level) - int(DataDB.config.enemy_level_spread) - 1
	var lvl_max := int(hunt.level) + int(DataDB.config.enemy_level_spread) + 1
	var npc_budget_per := float(ac.npc_sell_budget_per_kill)
	var mb := _mastery()
	var luck := (1.0 + float(mb.drop_pct) / 100.0) * boost_mult("drop")
	var gm := _gold_mult(gold_pct)
	var by_form := {}
	for i in accepted:
		var k: Dictionary = kills[i]
		var form_id: String = k.get("form", "")
		if not valid_forms.has(form_id):
			continue
		var lvl := clampi(int(k.get("level", hunt.level)), lvl_min, lvl_max)
		gold += int(Formulas.gold_for_kill(lvl) * float(hunt.get("gold_mult", 1.0)) * gm)
		p().npc_budget = float(p().npc_budget) + npc_budget_per * (1.0 + 0.15 * lvl)
		var shiny := false
		var tk: String = k.get("ticket", "")
		if tk != "" and p().tickets.has(tk):
			var ticket: Dictionary = p().tickets[tk]
			if not ticket.used and ticket.hunt == hunt_id:
				ticket.used = true
				shiny = bool(ticket.shiny)
		if shiny:
			shinies += 1
		by_form[form_id] = int(by_form.get(form_id, 0)) + 1
		var it := _roll_server_drop(hunt, luck)
		if not it.is_empty():
			items.append(it)
		var rec := _roll_recruit(hunt, form_id, shiny)
		if not rec.is_empty():
			recruits.append(rec)
	for fid in by_form:
		_add_mastery(fid, int(by_form[fid]))
	p().gold = int(p().gold) + gold
	p().stats.kills = int(p().stats.get("kills", 0)) + accepted
	return _ok({"accepted": accepted, "rejected": kills.size() - accepted, "gold_gained": gold, "wallet": wallet(),
		"items": items, "recruits": recruits, "shinies": shinies})


## Progresso offline: o servidor calcula o tempo real decorrido e a quantidade de abates.
func claim_offline(hunt_id: String, party: Array, client_stats: Array, gold_pct := 0.0) -> Dictionary:
	var hunt: Dictionary = DataDB.hunts.get(hunt_id, {})
	var t := now()
	var off: Dictionary = DataDB.config.offline
	var elapsed := clampf(t - float(p().last_seen_at), 0.0, float(off.max_hours) * 3600.0)
	p().last_seen_at = t
	p().last_claim_at = t
	if hunt.is_empty() or elapsed < float(off.min_seconds) or party.is_empty():
		return _ok({"seconds": elapsed, "kills": 0, "kills_by_form": {}, "gold_gained": 0, "items": [],
			"recruits": [], "shinies": 0, "wallet": wallet()})
	var fighters := _fighters(party, _party_capped_stats(party, client_stats))
	var est := KillRate.estimate(fighters, hunt)
	var kills := int(floor(est.kills_per_hour * elapsed / 3600.0 * float(off.efficiency)))
	var res := _grant_bulk_kills(hunt, kills, gold_pct, t - elapsed)
	res["seconds"] = elapsed
	p().last_offline = {"hunt": hunt_id, "kills": kills, "doubled": false, "t": t, "gold_pct": gold_pct, "seconds": elapsed}
	return res


## Recompensa em dobro do offline (após anúncio premiado). Só pode ser usada uma vez por resumo.
func double_offline() -> Dictionary:
	var lo: Dictionary = p().get("last_offline", {})
	if lo.is_empty() or lo.get("doubled", true) or now() - float(lo.t) > 1800.0:
		return _err("Nada para dobrar")
	lo.doubled = true
	var hunt: Dictionary = DataDB.hunts.get(lo.hunt, {})
	return _grant_bulk_kills(hunt, int(lo.kills), float(lo.get("gold_pct", 0.0)), float(lo.t) - float(lo.get("seconds", 0.0)))


func _grant_bulk_kills(hunt: Dictionary, kills: int, gold_pct: float, window_start := -1.0) -> Dictionary:
	# bônus valem na proporção do tempo offline em que estavam ativos
	var t1 := now()
	var t0 := window_start if window_start >= 0.0 else t1
	var bm := func(kind: String) -> float:
		var m := float(DataDB.config.boosts.kinds[kind].mult)
		var until := float(p().get("boosts", {}).get(kind, 0.0))
		if t1 - t0 < 1.0:
			return m if until > t1 else 1.0
		var cover := clampf((minf(until, t1) - t0) / (t1 - t0), 0.0, 1.0)
		return 1.0 + (m - 1.0) * cover
	var kills_by_form := {}
	var total_w := 0.0
	for m in hunt.monsters:
		total_w += float(m.weight)
	var assigned := 0
	for i in hunt.monsters.size():
		var m: Dictionary = hunt.monsters[i]
		var n := int(round(kills * float(m.weight) / total_w)) if i < hunt.monsters.size() - 1 else kills - assigned
		n = maxi(0, n)
		kills_by_form[m.form] = int(kills_by_form.get(m.form, 0)) + n
		assigned += n
	var mb := _mastery()
	var lvl := int(hunt.level)
	var gold := int(kills * Formulas.gold_for_kill(lvl) * float(hunt.get("gold_mult", 1.0)) * _gold_mult(gold_pct, float(bm.call("gold"))))
	for fid in kills_by_form:
		_add_mastery(fid, int(kills_by_form[fid]))
	p().gold = int(p().gold) + gold
	p().npc_budget = float(p().npc_budget) + kills * float(DataDB.config.anti_cheat.npc_sell_budget_per_kill) * (1.0 + 0.15 * lvl)
	p().stats.kills = int(p().stats.get("kills", 0)) + kills
	var items: Array = []
	for r in DataDB.rarities:
		if not r.server:
			continue
		var n := LootTable.binomial(kills, LootTable.chance(r.id, float(hunt.get("rarity_mult", 1.0))) * (1.0 + float(mb.drop_pct) / 100.0) * float(bm.call("drop")), rng)
		for i in mini(n, 50):
			var base_id := LootTable.pick_base(hunt, rng)
			var it := ItemLogic.create(base_id, r.id, rng, false, _id("s"))
			p().items[it.uid] = it
			items.append(it)
	var shinies := LootTable.binomial(kills, float(DataDB.config.shiny_chance) * float(bm.call("shiny")), rng)
	var recruits: Array = []
	if int(hunt.get("world", 1)) == 1 and hunt.get("recruit", true):
		var ch := float(DataDB.config.recruit_chance) * float(hunt.get("recruit_mult", 1.0)) * (1.0 + float(mb.recruit_pct) / 100.0) * float(bm.call("recruit"))
		var shiny_rec := LootTable.binomial(shinies, minf(1.0, ch * float(DataDB.config.get("shiny_recruit_mult", 10.0))), rng)
		var normal_rec := LootTable.binomial(kills - shinies, ch, rng)
		for i in mini(normal_rec + shiny_rec, 30):
			var forms := kills_by_form.keys()
			var fid: String = forms[rng.randi_range(0, forms.size() - 1)]
			var f := DataDB.form(fid)
			var sid := _id("m")
			var rec := {"server_id": sid, "family": f.family, "form": fid, "shiny": i < shiny_rec, "stars": 0, "converted": false,
				"quality": MonsterLogic.roll_quality(rng, i < shiny_rec)}
			p().monsters[sid] = rec
			recruits.append(rec)
	return _ok({"kills": kills, "kills_by_form": kills_by_form, "gold_gained": gold, "items": items,
		"recruits": recruits, "shinies": shinies, "wallet": wallet()})


# ------------------------------------------------------------------ desafios

func claim_challenge(challenge_id: String, won: bool, seconds: float, party: Array) -> Dictionary:
	var c: Dictionary = DataDB.challenge_by_id.get(challenge_id, {})
	if c.is_empty():
		return _err("Desafio inválido")
	var rec: Dictionary = p().challenges.get(challenge_id, {"cleared": false, "best": 0.0, "last_fail": 0.0, "week": 0, "week_best": 0.0})
	p().challenges[challenge_id] = rec
	var t := now()
	if not won:
		rec.last_fail = t
		return _ok({"won": false, "cooldown": DataDB.challenge_fail_cooldown})
	if seconds < float(DataDB.config.anti_cheat.challenge_min_seconds):
		return _err("Tempo de vitória implausível")
	var main_level := int(party[0].get("level", 1)) if not party.is_empty() else 1
	if main_level > int(p().validated_level) + 10:
		return _err("Nível não validado")
	var first := not bool(rec.cleared)
	rec.cleared = true
	if float(rec.best) <= 0.0 or seconds < float(rec.best):
		rec.best = seconds
	var wk := week_id(t)
	if int(rec.get("week", 0)) != wk or float(rec.get("week_best", 0.0)) <= 0.0 or seconds < float(rec.week_best):
		rec.week = wk
		rec.week_best = seconds
	var rw: Dictionary = c.rewards
	var mult := 1.0 if first else 0.25
	var gold := int(float(rw.gold) * mult)
	p().gold = int(p().gold) + gold
	var ess := {}
	for et in rw.essence:
		var amount := int(float(rw.essence[et]) * mult)
		p().essences[et] = int(p().essences.get(et, 0)) + amount
		ess[et] = amount
	var items: Array = []
	if first:
		var hunt_like := {"drops": DataDB.world2_drops([c.type], int(c.level))}
		var base_id := LootTable.pick_base(hunt_like, rng)
		var it := ItemLogic.create(base_id, rw.item_rarity, rng, false, _id("s"))
		p().items[it.uid] = it
		items.append(it)
	return _ok({"won": true, "first": first, "gold_gained": gold, "essence_gained": ess, "items": items,
		"best": rec.best, "wallet": wallet(), "unlocks": c.get("unlocks", "")})


func challenge_status() -> Dictionary:
	return _ok({"challenges": p().challenges, "server_time": now()})


# ------------------------------------------------------------------ chefe diário

static func day_id(t: float) -> int:
	return int(floor(t / 86400.0))


## Chefe do dia: rotação determinística entre as formas adultas; nível acompanha o jogador.
static func daily_boss_def(day: int, level: int) -> Dictionary:
	var adults: Array = []
	for f in DataDB.form_list:
		if int(f.stage) == 3:
			adults.append(f.form_id)
	var form_id: String = adults[(day * 7 + 3) % adults.size()]
	var cfg: Dictionary = DataDB.config.daily_boss
	var lvl := clampi(level, 5, int(DataDB.config.max_level))
	var st := Formulas.enemy_stats(form_id, lvl, 1)
	return {"form": form_id, "type": DataDB.form(form_id).type, "level": lvl, "day": day,
		"hp": float(st.hp) * float(cfg.hp_mult), "def": float(st.def) * float(cfg.def_mult)}


func _daily_state() -> Dictionary:
	var d: Dictionary = p().get("daily", {})
	var today := day_id(now())
	if int(d.get("day", -1)) != today:
		d = {"day": today, "used": 0, "tokens": {}}
		p().daily = d
	return d


func daily_boss_status(main_level: int) -> Dictionary:
	var d := _daily_state()
	var lvl := mini(main_level, int(p().validated_level) + 10)
	return _ok({"boss": daily_boss_def(int(d.day), lvl), "used": int(d.used), "entries": int(DataDB.config.daily_boss.entries),
		"resets_in": (int(d.day) + 1) * 86400.0 - now()})


func daily_boss_start(main_level: int) -> Dictionary:
	var d := _daily_state()
	if int(d.used) >= int(DataDB.config.daily_boss.entries):
		return _err("Sem entradas hoje. Volte amanhã!")
	var lvl := mini(main_level, int(p().validated_level) + 10)
	d.used = int(d.used) + 1
	var token := _id("db")
	d.tokens[token] = {"level": lvl, "t": now(), "done": false}
	return _ok({"token": token, "boss": daily_boss_def(int(d.day), lvl), "used": int(d.used)})


## Recompensa proporcional ao dano causado (limitada ao dano plausível do grupo no tempo informado).
func daily_boss_claim(token: String, damage_fraction: float, seconds: float, won: bool, party: Array) -> Dictionary:
	var d := _daily_state()
	var tk: Dictionary = d.tokens.get(token, {})
	if tk.is_empty() or tk.done:
		return _err("Entrada inválida")
	tk.done = true
	var cfg: Dictionary = DataDB.config.daily_boss
	var boss := daily_boss_def(int(d.day), int(tk.level))
	seconds = clampf(seconds, 0.0, minf(now() - float(tk.t) + 5.0, float(cfg.time_limit) + 5.0))
	var fighters := _fighters(party, _party_upper_stats(party))
	var dps := 0.0
	for f in fighters:
		var tm := TypeChart.multiplier(f.type, boss.type)
		dps += Formulas.expected_damage(f.atk, boss.def, 1.0, tm, f.crit) / Formulas.attack_interval(f.spd) * 1.6
	var max_frac := clampf(dps * seconds * 1.5 / maxf(1.0, boss.hp), 0.0, 1.0)
	var frac := clampf(damage_fraction, 0.0, max_frac)
	if won and (max_frac < 0.95 or seconds < float(cfg.min_seconds)):
		won = false
	if won:
		frac = 1.0
	var mn := float(cfg.min_reward_fraction)
	var rf := mn + (1.0 - mn) * frac
	var lvl := int(boss.level)
	var gold := int(float(cfg.gold_kills) * Formulas.gold_for_kill(lvl) * rf)
	var ess := int((float(cfg.essence_base) + float(cfg.essence_per_level) * lvl) * rf)
	p().gold = int(p().gold) + gold
	p().essences[boss.type] = int(p().essences.get(boss.type, 0)) + ess
	var items: Array = []
	if won:
		var rar := "raro"
		var r := rng.randf()
		var acc := 0.0
		for pair in cfg.item_rarity_roll:
			acc += float(pair[1])
			if r < acc:
				rar = pair[0]
				break
		var base_id := LootTable.pick_base({"drops": DataDB.world2_drops([boss.type], lvl)}, rng)
		var it := ItemLogic.create(base_id, rar, rng, false, _id("s"))
		p().items[it.uid] = it
		items.append(it)
	return _ok({"won": won, "fraction": frac, "gold_gained": gold, "essence_type": boss.type, "essence_gained": ess,
		"items": items, "wallet": wallet()})


# ------------------------------------------------------------------ essência / estrelas / gastos

func convert_monster(server_id: String, level: int, stage: int, stars_client: int) -> Dictionary:
	var rec: Dictionary = p().monsters.get(server_id, {})
	if rec.is_empty() or rec.converted:
		return _err("Monstro inválido")
	if rec.get("starter", false):
		return _err("O inicial não pode ser trocado")
	level = mini(level, int(p().validated_level) + 10)
	var m := MonsterLogic.create(rec.family, level, bool(rec.shiny), "tmp", "", int(rec.get("quality", 0)))
	m.stage = clampi(maxi(stage, DataDB.form(rec.form).get("stage", 1)), 1, MonsterLogic.stage_for_level(rec.family, 300))
	m.stars = int(rec.get("stars", 0))
	var amount := EssenceLogic.essence_value(m)
	var t: String = DataDB.families[rec.family].type
	p().essences[t] = int(p().essences.get(t, 0)) + amount
	rec.converted = true
	return _ok({"essence_type": t, "amount": amount, "wallet": wallet()})


## Troca em lote (até 50 por pedido). Cada item: {server_id, level, stage, stars}.
func convert_monsters(list: Array) -> Dictionary:
	var results: Array = []
	var totals := {}
	for e in list.slice(0, 50):
		var r := convert_monster(str(e.get("server_id", "")), int(e.get("level", 1)), int(e.get("stage", 1)), int(e.get("stars", 0)))
		r.erase("wallet")
		r["server_id"] = str(e.get("server_id", ""))
		results.append(r)
		if r.get("ok", false):
			totals[r.essence_type] = int(totals.get(r.essence_type, 0)) + int(r.amount)
	return _ok({"results": results, "totals": totals, "wallet": wallet()})


func buy_star(server_id: String) -> Dictionary:
	var rec: Dictionary = p().monsters.get(server_id, {})
	if rec.is_empty() or rec.converted:
		return _err("Monstro inválido")
	var cost := EssenceLogic.star_cost({"stars": int(rec.get("stars", 0))})
	if cost < 0:
		return _err("Estrelas no máximo")
	var t: String = DataDB.families[rec.family].type
	if int(p().essences.get(t, 0)) < cost:
		return _err("Essência insuficiente")
	p().essences[t] = int(p().essences[t]) - cost
	rec.stars = int(rec.get("stars", 0)) + 1
	return _ok({"stars": rec.stars, "wallet": wallet()})


## Gasto genérico (expansão de inventário, aprimorar item vinculado, etc).
func spend(gold: int, essences: Dictionary, reason: String) -> Dictionary:
	if gold < 0:
		return _err("Valor inválido")
	if int(p().gold) < gold:
		return _err("Ouro insuficiente")
	for t in essences:
		if int(essences[t]) < 0 or int(p().essences.get(t, 0)) < int(essences[t]):
			return _err("Essência insuficiente")
	p().gold = int(p().gold) - gold
	for t in essences:
		p().essences[t] = int(p().essences[t]) - int(essences[t])
	return _ok({"wallet": wallet(), "reason": reason})


func npc_sell(item: Dictionary) -> Dictionary:
	if item.get("locked", false):
		return _err("Item travado")
	var price := ItemLogic.sell_price(item)
	if not item.get("bound", true):
		var srv: Dictionary = p().items.get(item.get("uid", ""), {})
		if srv.is_empty():
			return _err("Item não encontrado no servidor")
		price = ItemLogic.sell_price(srv)
		p().items.erase(srv.uid)
	else:
		# itens vinculados foram criados pelo cliente: limita pelo orçamento acumulado em abates
		price = mini(price, int(p().npc_budget))
		p().npc_budget = float(p().npc_budget) - price
	p().gold = int(p().gold) + price
	return _ok({"gold_gained": price, "wallet": wallet()})


## Venda em lote ao NPC (até 100 itens por pedido).
func npc_sell_many(items: Array) -> Dictionary:
	var sold: Array = []
	var gold := 0
	for it in items.slice(0, 100):
		var r := npc_sell(it)
		if r.get("ok", false):
			sold.append(str(it.get("uid", "")))
			gold += int(r.gold_gained)
	return _ok({"sold": sold, "gold_gained": gold, "wallet": wallet()})


# ------------------------------------------------------------------ diamantes (dinheiro real) e bônus

## Compra com dinheiro real. No mock aceita tokens "sim_" (compra simulada); a Edge Function
## valida o token na API do Google Play e impede reuso.
func iap_purchase(product_id: String, token: String) -> Dictionary:
	var pr := DataDB.iap_product(product_id)
	if pr.is_empty():
		return _err("Produto inválido")
	if token == "" or not token.begins_with("sim_"):
		return _err("Compra não confirmada")
	if not p().has("iap_tokens"):
		p().iap_tokens = {}
	if p().iap_tokens.has(token):
		return _err("Compra já creditada")
	p().iap_tokens[token] = true
	var amount := int(pr.diamonds) + int(pr.get("bonus", 0))
	var first := int(p().get("purchases", 0)) == 0
	if first:
		amount += int(round(float(pr.diamonds) * float(DataDB.iap.get("first_purchase_bonus", 0.0))))
	p().purchases = int(p().get("purchases", 0)) + 1
	p().diamonds = int(p().get("diamonds", 0)) + amount
	return _ok({"diamonds_gained": amount, "first_bonus": first, "wallet": wallet()})


func boost_mult(kind: String) -> float:
	var until := float(p().get("boosts", {}).get(kind, 0.0))
	return float(DataDB.config.boosts.kinds[kind].mult) if until > now() else 1.0


func boost_status() -> Dictionary:
	return _ok({"boosts": p().get("boosts", {}).duplicate(), "server_time": now(), "wallet": wallet()})


func _extend_boost(kind: String, seconds: float) -> void:
	if not p().has("boosts"):
		p().boosts = {}
	var start := maxf(now(), float(p().boosts.get(kind, 0.0)))
	p().boosts[kind] = start + seconds


## Bônus de 8 h por diamantes. kind = "all" compra o pacote com todos.
func boost_buy(kind: String) -> Dictionary:
	var cfg: Dictionary = DataDB.config.boosts
	var kinds: Array = cfg.kinds.keys() if kind == "all" else [kind]
	if kind != "all" and not cfg.kinds.has(kind):
		return _err("Bônus inválido")
	var price := int(cfg.bundle_price) if kind == "all" else int(cfg.kinds[kind].price)
	if int(p().get("diamonds", 0)) < price:
		return _err("Diamantes insuficientes")
	p().diamonds = int(p().diamonds) - price
	for k in kinds:
		_extend_boost(k, float(cfg.diamond_hours) * 3600.0)
	return boost_status()


## Bônus de 15 min por anúncio premiado (acumula até ad_max_minutes restantes).
func boost_ad(kind: String) -> Dictionary:
	var cfg: Dictionary = DataDB.config.boosts
	if not cfg.kinds.has(kind):
		return _err("Bônus inválido")
	var left := float(p().get("boosts", {}).get(kind, 0.0)) - now()
	if left > float(cfg.ad_max_minutes) * 60.0:
		return _err("Esse bônus já está ativo por bastante tempo")
	_extend_boost(kind, float(cfg.ad_minutes) * 60.0)
	return boost_status()


# ------------------------------------------------------------------ treino de monstros (ouro)

func train_monster(server_id: String) -> Dictionary:
	var rec: Dictionary = p().monsters.get(server_id, {})
	if rec.is_empty() or rec.get("converted", false):
		return _err("Monstro inválido")
	var cur := int(rec.get("train", 0))
	if cur >= int(DataDB.config.train.max):
		return _err("Treino no máximo")
	var cost := Formulas.train_cost(cur, int(p().validated_level))
	if int(p().gold) < cost:
		return _err("Ouro insuficiente")
	p().gold = int(p().gold) - cost
	rec.train = cur + 1
	return _ok({"train": cur + 1, "cost": cost, "wallet": wallet()})


# ------------------------------------------------------------------ loja rotativa

func shop_period(t: float) -> int:
	return int(floor(t / (float(DataDB.config.shop.rotation_hours) * 3600.0)))


func _shop_state() -> Dictionary:
	var per := shop_period(now())
	var st: Dictionary = p().get("shop", {})
	if int(st.get("period", -1)) != per:
		st = {"period": per, "refreshes": 0, "slots": _roll_shop()}
		p().shop = st
	return st


## Sorteia os itens da loja perto do nível validado do jogador (raridade por peso).
func _roll_shop() -> Array:
	var cfg: Dictionary = DataDB.config.shop
	var lvl := int(p().validated_level)
	var pool: Array = []
	for bid in DataDB.item_bases:
		var b: Dictionary = DataDB.item_bases[bid]
		if b.get("world2_only", false):
			continue
		if int(b.level) <= lvl + 5 and int(b.level) >= lvl - int(cfg.level_window):
			pool.append(bid)
	if pool.is_empty():
		for bid in DataDB.item_bases:
			if int(DataDB.item_bases[bid].level) <= 10 and not DataDB.item_bases[bid].get("world2_only", false):
				pool.append(bid)
	var total := 0.0
	for w in cfg.rarity_weights:
		total += float(w[1])
	var out: Array = []
	for i in int(cfg.slots):
		var r := rng.randf() * total
		var rar := "comum"
		for w in cfg.rarity_weights:
			r -= float(w[1])
			if r <= 0.0:
				rar = w[0]
				break
		var bid: String = pool[rng.randi_range(0, pool.size() - 1)]
		var it := ItemLogic.create(bid, rar, rng, true, _id("l"))
		out.append({"item": it, "price": Formulas.shop_item_price(int(DataDB.item_bases[bid].level), rar), "sold": false})
	return out


func shop_status() -> Dictionary:
	var st := _shop_state()
	var hours := float(DataDB.config.shop.rotation_hours) * 3600.0
	return _ok({"slots": st.slots, "ends_at": (int(st.period) + 1) * hours, "server_time": now(),
		"refresh_cost": Formulas.shop_refresh_cost(int(p().validated_level), int(st.refreshes)), "wallet": wallet()})


func shop_buy(slot: int) -> Dictionary:
	var st := _shop_state()
	if slot < 0 or slot >= st.slots.size():
		return _err("Item inválido")
	var s: Dictionary = st.slots[slot]
	if s.sold:
		return _err("Já vendido")
	if int(p().gold) < int(s.price):
		return _err("Ouro insuficiente")
	p().gold = int(p().gold) - int(s.price)
	s.sold = true
	return _ok({"item": s.item, "wallet": wallet()})


func shop_refresh() -> Dictionary:
	var st := _shop_state()
	var cost := Formulas.shop_refresh_cost(int(p().validated_level), int(st.refreshes))
	if int(p().gold) < cost:
		return _err("Ouro insuficiente")
	p().gold = int(p().gold) - cost
	st.refreshes = int(st.refreshes) + 1
	st.slots = _roll_shop()
	return shop_status()


func npc_buy(base_id: String) -> Dictionary:
	if not DataDB.item_bases.has(base_id):
		return _err("Item inválido")
	if DataDB.item_bases[base_id].get("world2_only", false):
		return _err("Item indisponível na loja")
	var price := ItemLogic.shop_price(base_id)
	if int(p().gold) < price:
		return _err("Ouro insuficiente")
	p().gold = int(p().gold) - price
	var it := ItemLogic.create(base_id, "comum", rng, true)
	return _ok({"item": it, "wallet": wallet()})


## Aprimoramento de item negociável (sorteio no servidor).
func enhance_item(uid: String) -> Dictionary:
	var it: Dictionary = p().items.get(uid, {})
	if it.is_empty():
		return _err("Item não encontrado")
	if int(it.enh) >= int(DataDB.config.enhance.max):
		return _err("Aprimoramento máximo")
	var cost := EssenceLogic.enhance_cost(it)
	var r := spend(int(cost.gold), {cost.essence_type: int(cost.essence)}, "enhance")
	if not r.ok:
		return r
	var success := EssenceLogic.try_enhance(it, rng)
	return _ok({"success": success, "item": it, "wallet": wallet()})


# ------------------------------------------------------------------ save / validação / ranking

## Valida o progresso enviado pelo cliente contra o tempo real decorrido.
func sync_save(summary: Dictionary) -> Dictionary:
	var t := now()
	var claimed := int(summary.get("main_level", 1))
	var allowed := max_reachable_level(int(p().validated_level), t - float(p().validated_at))
	var corrected := false
	var lvl := claimed
	if claimed > allowed:
		lvl = allowed
		corrected = true
	if lvl > int(p().validated_level):
		p().validated_level = lvl
		p().validated_at = t
	elif claimed <= int(p().validated_level):
		p().validated_at = t
	p().last_seen_at = t
	_update_stats(summary)
	return _ok({"validated_level": p().validated_level, "corrected": corrected, "allowed_level": allowed})


## Maior nível alcançável a partir de 'from' em 'seconds' com uma taxa de XP generosa.
static func max_reachable_level(from: int, seconds: float) -> int:
	var ac: Dictionary = DataDB.config.anti_cheat
	var lvl := from
	var remaining := seconds
	var max_level := int(DataDB.config.max_level)
	var boost := float(DataDB.config.ads.xp_boost_mult)
	while lvl < max_level:
		var xph := Formulas.xp_for_kill(lvl + 10) * 1500.0 * float(ac.xp_rate_tolerance) * boost * 1.6
		var need := Formulas.xp_to_next(lvl) / xph * 3600.0
		if need > remaining:
			break
		remaining -= need
		lvl += 1
	return lvl


func _update_stats(summary: Dictionary) -> void:
	var st: Dictionary = p().stats
	st.level = int(p().validated_level)
	st.collection = clampi(int(summary.get("collection", 0)), 0, DataDB.form_list.size())
	var shinies := 0
	var stars := 0
	for m in p().monsters.values():
		if m.shiny:
			shinies += 1
		if not m.converted:
			stars += int(m.get("stars", 0))
	st.shinies = shinies
	st.stars = stars
	var wk := week_id(now())
	var w: Dictionary = p().weekly
	if int(w.get("week", -1)) != wk:
		p().weekly = {"week": wk, "base": {"level": st.level, "collection": st.collection, "shinies": shinies, "stars": stars}}


func ranking_categories() -> Array:
	var cats := ["level", "collection", "shinies", "stars"]
	for c in DataDB.challenges:
		cats.append("challenge_" + c.id)
	return cats


func rankings(category: String, period: String) -> Dictionary:
	_update_stats({"collection": p().stats.get("collection", 0)})
	var entries: Array = []
	var is_time := category.begins_with("challenge_")
	for fp in state.fake_players:
		var v := _fake_value(fp, category, period)
		if v > 0:
			entries.append({"name": fp.name, "value": v, "me": false})
	var mine := _my_value(category, period)
	if mine > 0:
		entries.append({"name": p().name, "value": mine, "me": true})
	if is_time:
		entries.sort_custom(func(a, b): return a.value < b.value)
	else:
		entries.sort_custom(func(a, b): return a.value > b.value)
	var my_rank := -1
	for i in entries.size():
		entries[i]["rank"] = i + 1
		if entries[i].me:
			my_rank = i + 1
	return _ok({"entries": entries.slice(0, 50), "my_rank": my_rank, "my_value": mine, "is_time": is_time})


func _my_value(category: String, period: String) -> float:
	var st: Dictionary = p().stats
	if category.begins_with("challenge_"):
		var rec: Dictionary = p().challenges.get(category.substr(10), {})
		if rec.is_empty() or not rec.get("cleared", false):
			return 0.0
		if period == "weekly":
			return float(rec.get("week_best", 0.0)) if int(rec.get("week", -1)) == week_id(now()) else 0.0
		return float(rec.best)
	var v := float(st.get(category, 0))
	if period == "weekly":
		v -= float(p().weekly.get("base", {}).get(category, 0))
	return v


func _fake_value(fp: Dictionary, category: String, period: String) -> float:
	if category.begins_with("challenge_"):
		var cid := category.substr(10)
		var c: Dictionary = DataDB.challenge_by_id.get(cid, {})
		if c.is_empty() or int(fp.level) < int(c.level):
			return 0.0
		var base := 40.0 + float(c.level) * 0.8
		var v := base * (0.6 + float(fp.skill) * 0.9)
		if period == "weekly":
			return v * 1.1 if fp.active else 0.0
		return snappedf(v, 0.1)
	var vals := {"level": float(fp.level), "collection": float(fp.collection), "shinies": float(fp.shinies), "stars": float(fp.stars)}
	if period == "weekly":
		if not fp.active:
			return 0.0
		var wk := {"level": float(fp.level) * 0.03 + 1.0, "collection": 2.0 + float(fp.skill) * 6.0, "shinies": 1.0 if fp.skill > 0.85 else 0.0, "stars": 1.0 + float(fp.skill) * 3.0}
		return floorf(wk[category])
	return vals[category]


# ------------------------------------------------------------------ market

func _seed_fake_world() -> void:
	if state.fake_players.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 777
		for i in FAKE_NAMES.size():
			var lvl := int(clampf(r.randfn(70.0, 50.0), 3.0, 260.0))
			state.fake_players.append({
				"id": "fake_%d" % i, "name": FAKE_NAMES[i], "level": lvl, "skill": r.randf(),
				"collection": clampi(int(lvl * 1.1 + r.randi_range(-10, 20)), 3, 135),
				"shinies": int(r.randf() * r.randf() * 4.0), "stars": int(lvl / 12.0 + r.randi_range(0, 8)),
				"active": r.randf() < 0.7,
			})
	_refill_market()


func _refill_market() -> void:
	var count := 0
	for l in state.listings.values():
		if l.seller_id.begins_with("fake_"):
			count += 1
	var bases := DataDB.item_bases.keys()
	var mons := 0
	for l in state.listings.values():
		if l.seller_id.begins_with("fake_") and l.kind == "monster":
			mons += 1
	while mons < 18:
		var fpm: Dictionary = state.fake_players[rng.randi_range(0, state.fake_players.size() - 1)]
		var ml := _fake_monster_listing(fpm)
		state.listings[ml.id] = ml
		mons += 1
		count += 1
	while count < 78:
		var fp: Dictionary = state.fake_players[rng.randi_range(0, state.fake_players.size() - 1)]
		var id := _id("L")
		var listing := {"id": id, "seller_id": fp.id, "seller_name": fp.name, "created_at": now()}
		if rng.randf() < 0.8:
			var base_id: String = bases[rng.randi_range(0, bases.size() - 1)]
			var roll := rng.randf()
			var rar := "raro" if roll < 0.65 else ("epico" if roll < 0.92 else ("lendario" if roll < 0.99 else "mitico"))
			var it := ItemLogic.create(base_id, rar, rng, false, _id("s"))
			if rng.randf() < 0.3:
				it.enh = rng.randi_range(1, 7)
			listing.kind = "item"
			listing.item = it
			listing.price = int(ItemLogic.sell_price(it) * rng.randf_range(1.5, 4.0))
		else:
			var t: String = DataDB.type_ids[rng.randi_range(0, DataDB.type_ids.size() - 1)]
			var amount := rng.randi_range(10, 300)
			listing.kind = "essence"
			listing.essence_type = t
			listing.amount = amount
			listing.price = int(amount * rng.randf_range(8.0, 20.0))
		state.listings[id] = listing
		count += 1


func _fake_monster_listing(fp: Dictionary) -> Dictionary:
	var fams := DataDB.families.keys()
	var fam: String = fams[rng.randi_range(0, fams.size() - 1)]
	var shiny := rng.randf() < 0.08
	var lvl := rng.randi_range(5, 120)
	var stage := MonsterLogic.stage_for_level(fam, lvl)
	var q := MonsterLogic.roll_quality(rng, shiny)
	var mon := {"server_id": _id("m"), "family": fam, "form": DataDB.form_for_stage(fam, stage), "shiny": shiny, "quality": q,
		"stars": rng.randi_range(0, 2) if lvl > 40 else 0, "train": rng.randi_range(0, 6) if lvl > 30 else 0, "level": lvl, "stage": stage}
	var price := int((20 + q * 1.2 + lvl * 0.6) * (12.0 if shiny else 1.0) * rng.randf_range(0.8, 1.6))
	return {"id": _id("L"), "seller_id": fp.id, "seller_name": fp.name, "created_at": now(), "kind": "monster",
		"currency": "diamonds", "monster": mon, "price": price}


func _simulate_fake_buyers() -> void:
	var t := now()
	for l in state.listings.values().duplicate():
		if l.seller_id != p().get("id", "") or t - float(l.created_at) < 45.0:
			continue
		if rng.randf() < 0.35:
			if l.kind == "monster":
				var dnet := int(floor(float(l.price) * (1.0 - float(DataDB.config.market.monster_fee))))
				p().diamonds = int(p().get("diamonds", 0)) + dnet
				state.listings.erase(l.id)
				state.sales_log.append({"listing": l, "net": dnet, "currency": "diamonds", "buyer": FAKE_NAMES[rng.randi_range(0, FAKE_NAMES.size() - 1)]})
				continue
			var net := int(floor(float(l.price) * (1.0 - float(DataDB.config.market.fee))))
			p().gold = int(p().gold) + net
			state.listings.erase(l.id)
			state.sales_log.append({"listing": l, "net": net, "buyer": FAKE_NAMES[rng.randi_range(0, FAKE_NAMES.size() - 1)]})


func market_search(filters: Dictionary) -> Dictionary:
	_simulate_fake_buyers()
	_refill_market()
	var out: Array = []
	for l in state.listings.values():
		if l.seller_id == p().id:
			continue
		if not _match(l, filters):
			continue
		out.append(l)
	var sort: String = filters.get("sort", "price_asc")
	if sort == "price_desc":
		out.sort_custom(func(a, b): return a.price > b.price)
	elif sort == "newest":
		out.sort_custom(func(a, b): return a.created_at > b.created_at)
	else:
		out.sort_custom(func(a, b): return a.price < b.price)
	return _ok({"listings": out.slice(0, 100)})


static func _match(l: Dictionary, f: Dictionary) -> bool:
	var kind: String = f.get("kind", "")
	if kind != "" and l.kind != kind:
		return false
	if kind == "" and l.kind == "monster":
		return false
	if l.kind == "monster":
		var mt: String = f.get("monster_type", "")
		if mt != "" and DataDB.families.get(l.monster.family, {}).get("type", "") != mt:
			return false
		if f.get("shiny_only", false) and not l.monster.shiny:
			return false
		return int(l.monster.get("quality", 0)) >= int(f.get("min_quality", 0))
	if l.kind == "essence":
		var et: String = f.get("essence_type", "")
		return et == "" or et == l.essence_type
	var it: Dictionary = l.item
	var b := ItemLogic.base(it)
	if f.get("slot", "") != "" and b.slot != f.slot:
		return false
	if f.get("rarity", "") != "" and it.rarity != f.rarity:
		return false
	if int(f.get("min_enh", 0)) > int(it.enh):
		return false
	if f.get("item_type", "") != "" and b.type != f.item_type:
		return false
	var stat: String = f.get("stat", "")
	if stat != "":
		var st := ItemLogic.stats(it)
		if not st.has(stat):
			return false
	return true


func market_list_item(uid: String, price: int) -> Dictionary:
	var it: Dictionary = p().items.get(uid, {})
	if it.is_empty():
		return _err("Item não encontrado ou não negociável")
	var chk := _check_listing(price)
	if not chk.ok:
		return chk
	p().items.erase(uid)
	var id := _id("L")
	state.listings[id] = {"id": id, "seller_id": p().id, "seller_name": p().name, "kind": "item", "item": it,
		"price": price, "created_at": now()}
	return _ok({"listing": state.listings[id], "wallet": wallet()})


func market_list_essence(type_id: String, amount: int, price: int) -> Dictionary:
	if amount <= 0 or int(p().essences.get(type_id, 0)) < amount:
		return _err("Essência insuficiente")
	var chk := _check_listing(price)
	if not chk.ok:
		return chk
	p().essences[type_id] = int(p().essences[type_id]) - amount
	var id := _id("L")
	state.listings[id] = {"id": id, "seller_id": p().id, "seller_name": p().name, "kind": "essence",
		"essence_type": type_id, "amount": amount, "price": price, "created_at": now()}
	return _ok({"listing": state.listings[id], "wallet": wallet()})


func _check_listing(price: int) -> Dictionary:
	var m: Dictionary = DataDB.config.market
	if price < int(m.min_price) or price > int(m.max_price):
		return _err("Preço inválido")
	var mine := 0
	for l in state.listings.values():
		if l.seller_id == p().id:
			mine += 1
	if mine >= int(m.max_listings):
		return _err("Limite de listagens atingido")
	return _ok()


## Monstros no Market: só por diamantes. O monstro sai do jogador até ser vendido ou cancelado.
func market_list_monster(server_id: String, level: int, stage: int, price: int) -> Dictionary:
	var rec: Dictionary = p().monsters.get(server_id, {})
	if rec.is_empty() or rec.get("converted", false):
		return _err("Monstro inválido")
	if rec.get("starter", false):
		return _err("O inicial não pode ser vendido")
	var m: Dictionary = DataDB.config.market
	if price < int(m.monster_min_price) or price > int(m.monster_max_price):
		return _err("Preço inválido")
	var chk := _check_listing(1)
	if not chk.ok:
		return chk
	var lvl := clampi(level, 1, int(p().validated_level) + 10)
	var st := clampi(maxi(stage, int(DataDB.form(rec.form).get("stage", 1))), 1, MonsterLogic.stage_for_level(rec.family, lvl))
	var mon := rec.duplicate()
	mon.level = lvl
	mon.stage = st
	mon.form = DataDB.form_for_stage(rec.family, st)
	p().monsters.erase(server_id)
	var id := _id("L")
	state.listings[id] = {"id": id, "seller_id": p().id, "seller_name": p().name, "kind": "monster", "currency": "diamonds",
		"monster": mon, "price": price, "created_at": now()}
	return _ok({"listing": state.listings[id], "wallet": wallet()})


func market_buy(listing_id: String) -> Dictionary:
	var l: Dictionary = state.listings.get(listing_id, {})
	if l.is_empty():
		return _err("Listagem não existe mais")
	if l.seller_id == p().id:
		return _err("Você não pode comprar sua própria listagem")
	if l.kind == "monster":
		if int(p().get("diamonds", 0)) < int(l.price):
			return _err("Diamantes insuficientes")
		p().diamonds = int(p().diamonds) - int(l.price)
		state.listings.erase(listing_id)
		var rec: Dictionary = l.monster.duplicate()
		rec.starter = false
		rec.converted = false
		p().monsters[rec.server_id] = rec
		return _ok({"monster": rec, "item": {}, "essence_type": "", "amount": 0, "wallet": wallet()})
	if int(p().gold) < int(l.price):
		return _err("Ouro insuficiente")
	# transação atômica: tudo ou nada
	p().gold = int(p().gold) - int(l.price)
	state.listings.erase(listing_id)
	var res := {"wallet": {}, "item": {}, "essence_type": "", "amount": 0}
	if l.kind == "item":
		p().items[l.item.uid] = l.item
		res.item = l.item
	else:
		p().essences[l.essence_type] = int(p().essences.get(l.essence_type, 0)) + int(l.amount)
		res.essence_type = l.essence_type
		res.amount = int(l.amount)
	res.wallet = wallet()
	return _ok(res)


func market_cancel(listing_id: String) -> Dictionary:
	var l: Dictionary = state.listings.get(listing_id, {})
	if l.is_empty() or l.seller_id != p().id:
		return _err("Listagem inválida")
	state.listings.erase(listing_id)
	var res := {"item": {}, "essence_type": "", "amount": 0, "monster": {}}
	if l.kind == "monster":
		p().monsters[l.monster.server_id] = l.monster
		res.monster = l.monster
	elif l.kind == "item":
		p().items[l.item.uid] = l.item
		res.item = l.item
	else:
		p().essences[l.essence_type] = int(p().essences.get(l.essence_type, 0)) + int(l.amount)
		res.essence_type = l.essence_type
		res.amount = int(l.amount)
	res.wallet = wallet()
	return _ok(res)


func market_my() -> Dictionary:
	_simulate_fake_buyers()
	var out: Array = []
	for l in state.listings.values():
		if l.seller_id == p().id:
			out.append(l)
	var sales: Array = state.get("sales_log", [])
	state.sales_log = []
	return _ok({"listings": out, "sales": sales, "wallet": wallet()})


# ------------------------------------------------------------------ debug

func debug_grant(gold: int, essences: Dictionary, diamonds := 0) -> Dictionary:
	p().gold = int(p().gold) + gold
	p().diamonds = int(p().get("diamonds", 0)) + diamonds
	for t in essences:
		p().essences[t] = int(p().essences.get(t, 0)) + int(essences[t])
	return _ok({"wallet": wallet()})


func debug_set_validated_level(lvl: int) -> void:
	p().validated_level = maxi(int(p().validated_level), lvl)
	p().validated_at = now()
