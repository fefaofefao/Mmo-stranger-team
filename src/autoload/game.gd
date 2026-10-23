extends Node
## Autoload "Game": estado do jogador (save), progressão, inventário, grupo e integração com o servidor.

signal wallet_changed
signal inventory_changed
signal monsters_changed
signal party_changed
signal monster_progress(uid: String, event: Dictionary)
signal feed(text: String, color: Color)
signal recruited(monster: Dictionary)
signal collection_changed
signal boosts_changed
signal sales_received(sales: Array)
signal session_ready
signal fighting_changed
signal mastery_reached(form_id: String, tier: int)
signal mastery_progress(form_id: String)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var save: Dictionary = {}
var rng := RandomNumberGenerator.new()
var session_started := false
var pending_kills: Array = []
var pending_gold := 0
var claiming := false
var tickets: Dictionary = {}
var _requesting_tickets := {}
var time_scale := 1.0
var debug_force_local_drop := ""
var last_offline_summary: Dictionary = {}

var _claim_timer := 0.0
var _cloud_timer := 0.0
var _autosave_timer := 0.0
var _touch_timer := 0.0


func _ready() -> void:
	rng.randomize()
	DataDB.ensure_loaded()
	load_local()
	if str(save.settings.get("locale", "")) == "":
		save.settings.locale = Loc.detect()
	Loc.set_locale(save.settings.locale)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if time_scale > 1.0:
		GameClock.offset += delta * (time_scale - 1.0)
	if not session_started:
		return
	var sync: Dictionary = DataDB.config.sync
	_claim_timer += delta
	if _claim_timer >= float(sync.claim_interval_seconds) / max(1.0, time_scale):
		_claim_timer = 0.0
		flush_claims()
	_cloud_timer += delta
	if _cloud_timer >= float(sync.cloud_interval_seconds):
		_cloud_timer = 0.0
		cloud_sync()
	_autosave_timer += delta
	if _autosave_timer >= 20.0:
		_autosave_timer = 0.0
		save_local()
	_touch_timer += delta
	if _touch_timer >= 60.0:
		_touch_timer = 0.0
		Backend.request("touch")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if session_started:
			save_local()
			Backend.request("touch")
			Backend.persist()


# ================================================================ save local

func new_save() -> Dictionary:
	var s := {
		"version": SAVE_VERSION, "device_id": "dev_%x%x" % [rng.randi(), rng.randi()], "created_at": GameClock.now(),
		"saved_at": 0.0, "playtime": 0.0, "player_name": "", "gold": 0, "essences": {},
		"monsters": {}, "party": [], "items": {}, "inventory_cap": int(DataDB.config.inventory.base_cap),
		"collection": {}, "challenges": {}, "current_hunt": "", "ai_behavior": "focus",
		"boosts": {"xp_until": 0.0}, "settings": {"auto_sell_comum": false, "auto_sell_incomum": false, "zoom": 2.0,
		"show_damage": true, "locale": ""}, "stats": {"kills": 0, "deaths": 0, "wipes": 0},
		"debug_unlock_all": false, "last_interstitial": 0.0,
	}
	for t in DataDB.type_ids:
		s.essences[t] = 0
	return s


func load_local() -> void:
	save = new_save()
	_bonus_cache = {}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary and parsed.has("version"):
			_merge_defaults(parsed, save)
			save = parsed
			_bonus_cache = {}
	_fix_types()


func _merge_defaults(target: Dictionary, defaults: Dictionary) -> void:
	for k in defaults:
		if not target.has(k):
			target[k] = defaults[k]
		elif defaults[k] is Dictionary and target[k] is Dictionary and k in ["settings", "boosts", "stats"]:
			_merge_defaults(target[k], defaults[k])


func _fix_types() -> void:
	# JSON devolve números como float; normaliza inteiros importantes
	for m in save.monsters.values():
		m.level = int(m.level)
		m.stage = int(m.stage)
		m.stars = int(m.get("stars", 0))
		if m.equip is Array:
			m.equip = {}
	for it in save.items.values():
		it.enh = int(it.get("enh", 0))
	save.gold = int(save.gold)
	save.inventory_cap = int(save.inventory_cap)


func save_local() -> void:
	save.saved_at = GameClock.now()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func has_starter() -> bool:
	return not save.party.is_empty()


func reset_all() -> void:
	save = new_save()
	_bonus_cache = {}
	save_local()
	session_started = false


# ================================================================ sessão / servidor

## Login + reconciliação com o servidor + progresso offline. Retorna o resumo offline (ou {}).
func start_session() -> Dictionary:
	var r := await Backend.request("login", {"device_id": save.device_id})
	if not r.get("ok", false):
		feed.emit(Loc.t("Sem conexão: jogando offline (sincroniza depois)."), Color.ORANGE)
	else:
		_apply_wallet(r.get("wallet", {}))
		if save.player_name == "":
			save.player_name = r.get("name", "Jogador")
		# restaura save da nuvem se o local estiver vazio (reinstalação)
		if not has_starter():
			var cs := await Backend.request("cloud_save_get")
			if cs.get("ok", false) and cs.get("save", {}) is Dictionary and not cs.save.is_empty() and not cs.save.get("party", []).is_empty():
				var restored: Dictionary = cs.save
				_merge_defaults(restored, new_save())
				save = restored
				_bonus_cache = {}
				_fix_types()
				feed.emit(Loc.t("Progresso restaurado da nuvem."), Color.LIGHT_GREEN)
		await refresh_profile()
	var summary := {}
	if has_starter() and save.current_hunt != "":
		summary = await claim_offline()
	session_started = true
	session_ready.emit()
	cloud_sync()
	return summary


func refresh_profile() -> void:
	var r := await Backend.request("get_profile")
	if not r.get("ok", false):
		return
	_apply_wallet(r.get("wallet", {}))
	# itens negociáveis: o servidor é a fonte da verdade
	var server_items := {}
	for it in r.get("items", []):
		server_items[it.uid] = it
	for uid in save.items.keys():
		var it: Dictionary = save.items[uid]
		if not it.get("bound", false) and not server_items.has(uid):
			_unequip_everywhere(uid)
			save.items.erase(uid)
	for uid in server_items:
		var sit: Dictionary = server_items[uid]
		if save.items.has(uid):
			var loc: String = save.items[uid].get("loc", "inv")
			var locked: bool = save.items[uid].get("locked", false)
			save.items[uid] = sit
			sit["loc"] = loc
			sit["locked"] = locked
		else:
			sit["loc"] = "inv"
			save.items[uid] = sit
	# estrelas e monstros trocados: registro do servidor
	var srv_mons: Dictionary = r.get("monsters", {})
	for m in save.monsters.values():
		var rec: Dictionary = srv_mons.get(m.server_id, {})
		if not rec.is_empty():
			m.stars = int(rec.get("stars", 0))
			m.quality = int(rec.get("quality", m.get("quality", 0)))
			m.train = int(rec.get("train", m.get("train", 0)))
	# Marcos: o servidor guarda os abates validados (recupera progresso após reinstalar sem nuvem)
	var srv_mastery: Dictionary = r.get("mastery", {})
	for fid in srv_mastery:
		if DataDB.forms.has(fid) and int(srv_mastery[fid]) > form_kills(fid):
			var c := _coll(fid)
			c.seen = true
			c.kills = int(srv_mastery[fid])
			_bonus_cache = {}
	var sales: Array = r.get("sales", [])
	if not sales.is_empty():
		_apply_sales(sales)
	# inicial criado sem conexão: registra no servidor agora
	if save.monsters.has("local_starter"):
		var m: Dictionary = save.monsters["local_starter"]
		var rs := await Backend.request("register_starter", {"family": m.family})
		if rs.get("ok", false):
			var sid: String = rs.monster.server_id
			save.monsters.erase("local_starter")
			m.uid = sid
			m.server_id = sid
			save.monsters[sid] = m
			var idx: int = save.party.find("local_starter")
			if idx >= 0:
				save.party[idx] = sid
			party_changed.emit()
	inventory_changed.emit()
	monsters_changed.emit()


func _apply_sales(sales: Array) -> void:
	for s in sales:
		var l: Dictionary = s.listing
		var what := ItemLogic.display_name(l.item) if l.kind == "item" else Loc.t("%d Essência de %s") % [int(l.amount), DataDB.type_name(l.essence_type)]
		feed.emit(Loc.t("Market: %s vendido por %d de ouro.") % [what, int(s.net)], Color.GOLD)
	sales_received.emit(sales)


func _apply_wallet(w: Dictionary) -> void:
	if w.is_empty():
		return
	save.gold = int(w.get("gold", save.gold))
	var es: Dictionary = w.get("essences", {})
	for t in es:
		save.essences[t] = int(es[t])
	wallet_changed.emit()


func party_snapshot() -> Array:
	var out: Array = []
	for m in party_monsters():
		out.append({"server_id": m.server_id, "family": m.family, "stage": m.stage, "level": m.level})
	return out


func party_stats_snapshot() -> Array:
	var out: Array = []
	for m in party_monsters():
		var s := monster_stats(m)
		out.append({"hp": s.hp, "atk": s.atk, "def": s.def, "spd": s.spd, "crit": s.crit})
	return out


## Bônus de ouro do EQUIPAMENTO do principal (enviado ao servidor, que soma o bônus de Marcos dele).
func gold_bonus_pct() -> float:
	var main := main_monster()
	if main.is_empty():
		return 0.0
	return MonsterLogic.compute_stats(main, save.items).gold_pct


func flush_claims() -> void:
	if claiming or pending_kills.is_empty() or save.current_hunt == "":
		return
	claiming = true
	var batch := pending_kills
	pending_kills = []
	var hunt_id: String = batch[0].hunt
	var kills: Array = []
	var rest: Array = []
	for k in batch:
		if k.hunt == hunt_id:
			kills.append(k)
		else:
			rest.append(k)
	var r := await Backend.request("claim_kills", {"hunt": hunt_id, "kills": kills, "party": party_snapshot(),
		"stats": party_stats_snapshot(), "gold_pct": gold_bonus_pct()})
	claiming = false
	pending_kills = rest + pending_kills
	if not r.get("ok", false):
		# sem conexão: guarda para reenviar (limitado)
		pending_kills = (kills + pending_kills).slice(0, 600)
		return
	pending_gold = maxi(0, pending_gold - int(r.get("gold_gained", 0)))
	if int(r.get("rejected", 0)) > 0:
		pending_gold = 0
	_apply_wallet(r.get("wallet", {}))
	for it in r.get("items", []):
		add_item(it)
		feed.emit("%s: %s" % [DataDB.rarity_name(it.rarity), ItemLogic.display_name(it)], DataDB.rarity_color(it.rarity))
	for rec in r.get("recruits", []):
		add_recruit(rec)


func claim_offline() -> Dictionary:
	var hunt: Dictionary = DataDB.hunts.get(save.current_hunt, {})
	if hunt.is_empty():
		return {}
	var r := await Backend.request("claim_offline", {"hunt": hunt.id, "party": party_snapshot(),
		"stats": party_stats_snapshot(), "gold_pct": gold_bonus_pct()})
	if not r.get("ok", false) or int(r.get("kills", 0)) <= 0:
		return {}
	var summary := apply_bulk_kills(hunt, r)
	summary["seconds"] = float(r.get("seconds", 0))
	last_offline_summary = summary
	return summary


## Aplica XP, coleção e drops locais de um lote de abates calculado pelo servidor (offline / dobrar).
func apply_bulk_kills(hunt: Dictionary, r: Dictionary) -> Dictionary:
	var kills := int(r.get("kills", 0))
	var party := party_monsters()
	var levels_before: Array = []
	for m in party:
		levels_before.append(int(m.level))
	var xp_total: Array = []
	for i in party.size():
		xp_total.append(0.0)
	var boost := xp_boost_mult()
	var bonus: float = monster_stats(party[0]).xp_pct if not party.is_empty() else float(account_bonuses().xp_pct)
	var kbf: Dictionary = r.get("kills_by_form", {})
	for fid in kbf:
		var n := int(kbf[fid])
		if n <= 0:
			continue
		_add_form_kills(fid, n, false)
		var base := Formulas.xp_for_kill(int(hunt.level)) * float(hunt.get("xp_mult", 1.0)) * boost * n
		var shares := PartyLogic.split_xp(party, base, int(hunt.level), bonus)
		for i in party.size():
			xp_total[i] += shares[i]
	for i in party.size():
		var ev := MonsterLogic.add_xp(party[i], xp_total[i])
		_handle_progress(party[i], ev)
	# drops locais (Comum/Incomum, vinculados)
	var local_items := 0
	var local_lost := 0
	for rr in DataDB.rarities:
		if rr.server:
			continue
		var n := LootTable.binomial(kills, float(rr.chance) * (1.0 + float(account_bonuses().drop_pct) / 100.0), rng)
		for j in mini(n, 200):
			var it := ItemLogic.create(LootTable.pick_base(hunt, rng), rr.id, rng, true)
			if add_item(it, false):
				local_items += 1
			else:
				local_lost += 1
	_apply_wallet(r.get("wallet", {}))
	for it in r.get("items", []):
		add_item(it, false)
	for rec in r.get("recruits", []):
		add_recruit(rec, false)
	save.stats.kills = int(save.stats.kills) + kills
	var levels_gained: Array = []
	for i in party.size():
		levels_gained.append(int(party[i].level) - int(levels_before[i]))
	collection_changed.emit()
	inventory_changed.emit()
	return {"hunt": hunt.id, "kills": kills, "xp": xp_total, "levels": levels_gained, "gold": int(r.get("gold_gained", 0)),
		"items": r.get("items", []), "local_items": local_items, "local_lost": local_lost, "recruits": r.get("recruits", []),
		"shinies": int(r.get("shinies", 0))}


func double_offline_reward() -> Dictionary:
	var r := await Backend.request("double_offline")
	if not r.get("ok", false):
		return {}
	var hunt: Dictionary = DataDB.hunts.get(last_offline_summary.get("hunt", ""), {})
	if hunt.is_empty():
		return {}
	return apply_bulk_kills(hunt, r)


func cloud_sync() -> void:
	if not has_starter():
		return
	var summary := {"main_level": main_level(), "collection": collection_count(), "playtime": save.playtime}
	var r := await Backend.request("sync_save", {"summary": summary})
	if r.get("ok", false) and r.get("corrected", false):
		# progresso implausível: limita ao nível validado pelo servidor
		var allowed := int(r.get("allowed_level", main_level()))
		for m in save.monsters.values():
			if int(m.level) > allowed:
				MonsterLogic.set_level(m, allowed)
		feed.emit(Loc.t("Progresso ajustado pelo servidor (validação de tempo)."), Color.ORANGE)
		monsters_changed.emit()
	save_local()
	Backend.request("cloud_save_put", {"save": save})


# ================================================================ monstros e grupo

func monster(uid: String) -> Dictionary:
	return save.monsters.get(uid, {})


func party_monsters() -> Array:
	var out: Array = []
	for uid in save.party:
		if save.monsters.has(uid):
			out.append(save.monsters[uid])
	return out


func main_monster() -> Dictionary:
	var p := party_monsters()
	return p[0] if not p.is_empty() else {}


func main_level() -> int:
	var m := main_monster()
	return int(m.level) if not m.is_empty() else 1


func fighting_monsters() -> Array:
	var p := party_monsters()
	return p.slice(0, PartyLogic.fighting_count(main_level(), p.size()))


func depot_monsters() -> Array:
	var out: Array = []
	for m in save.monsters.values():
		if not save.party.has(m.uid):
			out.append(m)
	out.sort_custom(func(a, b): return int(a.level) > int(b.level))
	return out


func items_dict() -> Dictionary:
	return save.items


var _bonus_cache: Dictionary = {}


## Bônus permanentes da conta (Marcos de Caça), a partir dos abates por forma da Coleção.
func account_bonuses() -> Dictionary:
	if _bonus_cache.is_empty():
		var kbf := {}
		for fid in save.collection:
			kbf[fid] = int(save.collection[fid].get("kills", 0))
		_bonus_cache = Mastery.bonuses(kbf)
	return _bonus_cache


func invalidate_bonuses() -> void:
	_bonus_cache = {}


func form_kills(form_id: String) -> int:
	return int(save.collection.get(form_id, {}).get("kills", 0))


## Soma abates numa forma e avisa quando um marco é atingido.
func _add_form_kills(form_id: String, n: int, notify := true) -> void:
	var c := _coll(form_id)
	c.seen = true
	var before := int(c.kills)
	c.kills = before + n
	var t0 := Mastery.tier_of(before)
	var t1 := Mastery.tier_of(int(c.kills))
	if t1 > t0:
		invalidate_bonuses()
		if notify:
			var info := Mastery.form_info(form_id, int(c.kills))
			feed.emit(Loc.t("Marco %s: %s · %s") % [Mastery.tier_name(t1), DataDB.form_name(form_id), Mastery.fmt_bonus(info.stat, float(Mastery.points_at(t1) - Mastery.points_at(t1 - 1)) * float(Mastery.stat_of_form(form_id).per_point))], Color.GOLD)
			mastery_reached.emit(form_id, t1)
	mastery_progress.emit(form_id)


func monster_stats(m: Dictionary) -> Dictionary:
	return MonsterLogic.compute_stats(m, save.items, account_bonuses())


func fighter_stats() -> Array:
	var out: Array = []
	for m in fighting_monsters():
		out.append(monster_stats(m))
	return out


func choose_starter(family_id: String) -> bool:
	var r := await Backend.request("register_starter", {"family": family_id})
	var sid := ""
	var q := int(DataDB.config.get("quality", {}).get("starter", 50))
	if r.get("ok", false):
		sid = r.monster.server_id
		q = int(r.monster.get("quality", q))
	else:
		sid = "local_starter"
	var m := MonsterLogic.create(family_id, int(DataDB.config.starting_level), false, sid, sid, q)
	save.monsters[m.uid] = m
	save.party = [m.uid]
	_mark_obtained(MonsterLogic.form_id(m), false)
	# primeira hunt recomendada: a de nível 1 do mesmo grupo inicial
	for h in DataDB.hunt_list:
		if int(h.level) == 1:
			save.current_hunt = h.id
			break
	save_local()
	party_changed.emit()
	monsters_changed.emit()
	return true


func add_recruit(rec: Dictionary, notify := true) -> Dictionary:
	if save.monsters.has(rec.server_id):
		return save.monsters[rec.server_id]
	var m := MonsterLogic.create_from_form(rec.form, int(DataDB.config.recruit_level), bool(rec.shiny), rec.server_id, rec.server_id, int(rec.get("quality", 0)))
	m.stars = int(rec.get("stars", 0))
	save.monsters[m.uid] = m
	_mark_obtained(rec.form, bool(rec.shiny))
	if save.party.size() < int(DataDB.config.party.max_size):
		save.party.append(m.uid)
		party_changed.emit()
	if notify:
		var txt := Loc.t("Recrutado: %s (qualidade %s)!") % [MonsterLogic.display_name(m), MonsterLogic.quality_text(m)]
		feed.emit(txt, Color(1, 0.85, 0.3) if m.shiny else Color(0.6, 1, 0.6))
	recruited.emit(m)
	monsters_changed.emit()
	return m


func set_party_slot(index: int, uid: String) -> void:
	var p: Array = save.party
	if index < 0 or index >= int(DataDB.config.party.max_size):
		return
	var cur := p.find(uid)
	if index < p.size():
		if cur >= 0:
			p[cur] = p[index]
		p[index] = uid
	else:
		if cur >= 0:
			return
		p.append(uid)
	party_changed.emit()


func remove_from_party(uid: String) -> void:
	if save.party.size() <= 1:
		return
	save.party.erase(uid)
	party_changed.emit()


func move_party(uid: String, dir: int) -> void:
	var i: int = save.party.find(uid)
	var j := i + dir
	if i < 0 or j < 0 or j >= save.party.size():
		return
	var tmp = save.party[j]
	save.party[j] = uid
	save.party[i] = tmp
	party_changed.emit()


func set_ai_behavior(b: String) -> void:
	save.ai_behavior = b
	party_changed.emit()


func convert_monster(uid: String) -> Dictionary:
	var m := monster(uid)
	if m.is_empty() or save.party.has(uid):
		return {"ok": false, "error": Loc.t("Retire o monstro do grupo antes.")}
	var r := await Backend.request("convert_monster", {"server_id": m.server_id, "level": m.level, "stage": m.stage, "stars": m.stars})
	if not r.get("ok", false):
		return r
	for slot in m.equip.keys():
		var iu: String = m.equip[slot]
		if save.items.has(iu):
			save.items[iu].loc = "inv"
	save.monsters.erase(uid)
	_mark_obtained(MonsterLogic.form_id(m), bool(m.shiny))
	_apply_wallet(r.wallet)
	monsters_changed.emit()
	inventory_changed.emit()
	return r


## Troca vários monstros do Depot de uma vez (em pedidos de até 50).
func convert_monsters(uids: Array) -> Dictionary:
	var totals := {}
	var done := 0
	var fails := 0
	var list: Array = []
	var by_sid := {}
	for uid in uids:
		var m := monster(uid)
		if m.is_empty() or save.party.has(uid):
			continue
		list.append({"server_id": m.server_id, "level": m.level, "stage": m.stage, "stars": m.stars})
		by_sid[m.server_id] = uid
	var i := 0
	while i < list.size():
		var r := await Backend.request("convert_monsters", {"list": list.slice(i, i + 50)})
		i += 50
		if not r.get("ok", false):
			return r
		for res in r.results:
			var uid: String = by_sid.get(res.server_id, "")
			if not res.get("ok", false) or uid == "":
				fails += 1
				continue
			var m := monster(uid)
			for slot in m.equip.keys():
				var iu: String = m.equip[slot]
				if save.items.has(iu):
					save.items[iu].loc = "inv"
			save.monsters.erase(uid)
			_mark_obtained(MonsterLogic.form_id(m), bool(m.shiny))
			done += 1
		for t in r.totals:
			totals[t] = int(totals.get(t, 0)) + int(r.totals[t])
		_apply_wallet(r.wallet)
	monsters_changed.emit()
	inventory_changed.emit()
	return {"ok": true, "converted": done, "failed": fails, "totals": totals}


## Treino com ouro (+Ataque/Defesa/Vida; brilho em +5/+10/+15). O servidor cobra e registra.
func train_monster(uid: String) -> Dictionary:
	var m := monster(uid)
	if m.is_empty():
		return {"ok": false, "error": Loc.t("Monstro inválido")}
	var before := MonsterLogic.glow_tier(m)
	var r := await Backend.request("train_monster", {"server_id": m.server_id})
	if not r.get("ok", false):
		return r
	m.train = int(r.train)
	_apply_wallet(r.wallet)
	r["new_glow"] = MonsterLogic.glow_tier(m) > before
	monsters_changed.emit()
	party_changed.emit()
	return r


func train_cost(m: Dictionary) -> int:
	return Formulas.train_cost(int(m.get("train", 0)), main_level())


func shop_status() -> Dictionary:
	var r := await Backend.request("shop_status")
	if r.get("ok", false):
		_apply_wallet(r.wallet)
	return r


func shop_buy(slot: int) -> Dictionary:
	if inv_count() >= inv_cap():
		return {"ok": false, "error": Loc.t("Inventário cheio")}
	var r := await Backend.request("shop_buy", {"slot": slot})
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		add_item(r.item, false)
	return r


func shop_refresh() -> Dictionary:
	var r := await Backend.request("shop_refresh")
	if r.get("ok", false):
		_apply_wallet(r.wallet)
	return r


func buy_star(uid: String) -> Dictionary:
	var m := monster(uid)
	var r := await Backend.request("buy_star", {"server_id": m.server_id})
	if r.get("ok", false):
		m.stars = int(r.stars)
		_apply_wallet(r.wallet)
		monsters_changed.emit()
	return r


# ================================================================ abates (tempo real)

func xp_boost_mult() -> float:
	return float(DataDB.config.ads.xp_boost_mult) if xp_boost_active() else 1.0


func xp_boost_active() -> bool:
	return float(save.boosts.get("xp_until", 0.0)) > GameClock.now()


func xp_boost_remaining() -> float:
	return max(0.0, float(save.boosts.get("xp_until", 0.0)) - GameClock.now())


func grant_xp_boost() -> void:
	var start: float = maxf(GameClock.now(), float(save.boosts.get("xp_until", 0.0)))
	save.boosts.xp_until = start + float(DataDB.config.ads.xp_boost_minutes) * 60.0
	boosts_changed.emit()
	feed.emit(Loc.t("2x XP ativado por %d min!") % int(DataDB.config.ads.xp_boost_minutes), Color.GOLD)


func get_spawn_ticket(hunt_id: String) -> Dictionary:
	if not tickets.has(hunt_id):
		tickets[hunt_id] = []
	var arr: Array = tickets[hunt_id]
	if arr.size() < 10 and not _requesting_tickets.get(hunt_id, false):
		_request_tickets(hunt_id)
	if arr.is_empty():
		return {}
	return arr.pop_front()


func _request_tickets(hunt_id: String) -> void:
	_requesting_tickets[hunt_id] = true
	var r := await Backend.request("spawn_tickets", {"hunt": hunt_id, "n": int(DataDB.config.sync.spawn_ticket_batch)})
	_requesting_tickets[hunt_id] = false
	if r.get("ok", false):
		if not tickets.has(hunt_id):
			tickets[hunt_id] = []
		tickets[hunt_id].append_array(r.tickets)


func mark_seen(form_id: String) -> void:
	var c := _coll(form_id)
	if not c.seen:
		c.seen = true
		collection_changed.emit()


## Chamado pelo mundo a cada inimigo derrotado numa hunt.
## Retorna {xp: Array, drop: Dictionary}
func on_kill(hunt: Dictionary, form_id: String, level: int, ticket: String, shiny: bool, participants: Array = []) -> Dictionary:
	var c := _coll(form_id)
	_add_form_kills(form_id, 1)
	save.stats.kills = int(save.stats.kills) + 1
	var party := party_monsters()
	# xp_pct dos stats do principal já inclui o bônus dos Marcos
	var bonus: float = monster_stats(party[0]).xp_pct if not party.is_empty() else float(account_bonuses().xp_pct)
	var base := Formulas.xp_for_kill(level) * float(hunt.get("xp_mult", 1.0)) * xp_boost_mult()
	var shares := PartyLogic.split_xp(party, base, level, bonus, participants)
	var fc_before := PartyLogic.fighting_count(main_level(), party.size())
	for i in party.size():
		var ev := MonsterLogic.add_xp(party[i], shares[i])
		_handle_progress(party[i], ev)
	if PartyLogic.fighting_count(main_level(), party.size()) != fc_before:
		fighting_changed.emit()
	var drop := {}
	var rar := LootTable.roll_rarity(rng, false, 1.0, 1.0 + float(account_bonuses().drop_pct) / 100.0)
	if debug_force_local_drop != "":
		rar = debug_force_local_drop
		debug_force_local_drop = ""
	if rar != "":
		var it := ItemLogic.create(LootTable.pick_base(hunt, rng), rar, rng, true)
		if _auto_sell(it):
			drop = it
		elif add_item(it, false):
			drop = it
	pending_gold += int(Formulas.gold_for_kill(level) * float(hunt.get("gold_mult", 1.0)))
	pending_kills.append({"hunt": hunt.id, "form": form_id, "level": level, "ticket": ticket})
	if pending_kills.size() > 600:
		pending_kills = pending_kills.slice(pending_kills.size() - 600)
	if shiny:
		c.shiny_seen = true
	return {"xp": shares, "drop": drop}


func _auto_sell(it: Dictionary) -> bool:
	var key := "auto_sell_" + str(it.rarity)
	if it.get("bound", false) and save.settings.get(key, false):
		_sell_async(it)
		return true
	return false


func _sell_async(it: Dictionary) -> void:
	var r := await Backend.request("npc_sell", {"item": it})
	if r.get("ok", false):
		_apply_wallet(r.wallet)


func _handle_progress(m: Dictionary, ev: Dictionary) -> void:
	if int(ev.get("levels", 0)) > 0:
		monster_progress.emit(m.uid, ev)
		if save.party.size() > 0 and save.party[0] == m.uid:
			feed.emit(Loc.t("%s chegou ao nível %d!") % [MonsterLogic.display_name(m), int(m.level)], Color(0.6, 0.9, 1.0))
	if ev.get("evolved", false):
		_mark_obtained(MonsterLogic.form_id(m), bool(m.shiny))
		feed.emit(Loc.t("%s evoluiu para %s!") % [DataDB.form_name(ev.from_form), DataDB.form_name(ev.to_form)], Color.GOLD)
		monsters_changed.emit()


func _coll(form_id: String) -> Dictionary:
	if not save.collection.has(form_id):
		save.collection[form_id] = {"seen": false, "kills": 0, "recruited": false, "shiny": false, "shiny_seen": false}
	return save.collection[form_id]


func _mark_obtained(form_id: String, shiny: bool) -> void:
	var c := _coll(form_id)
	c.seen = true
	c.recruited = true
	if shiny:
		c.shiny = true
	collection_changed.emit()


func collection_count() -> int:
	var n := 0
	for fid in save.collection:
		if save.collection[fid].get("recruited", false):
			n += 1
	return n


# ================================================================ inventário

func inv_items() -> Array:
	var out: Array = []
	for it in save.items.values():
		if it.get("loc", "inv") == "inv":
			out.append(it)
	return out


func depot_items() -> Array:
	var out: Array = []
	for it in save.items.values():
		if it.get("loc", "inv") == "depot":
			out.append(it)
	return out


func inv_count() -> int:
	return inv_items().size()


func inv_cap() -> int:
	return int(save.inventory_cap)


## Adiciona um item. Itens negociáveis nunca são perdidos (vão para o Depot se faltar espaço).
func add_item(it: Dictionary, notify := true) -> bool:
	if it.is_empty():
		return false
	if inv_count() >= inv_cap():
		if it.get("bound", false):
			if notify:
				feed.emit(Loc.t("Inventário cheio: item descartado."), Color.ORANGE_RED)
			return false
		it["loc"] = "depot"
	else:
		it["loc"] = "inv"
	if not it.has("locked"):
		it["locked"] = false
	save.items[it.uid] = it
	if notify:
		inventory_changed.emit()
	return true


func remove_item(uid: String) -> void:
	_unequip_everywhere(uid)
	save.items.erase(uid)
	inventory_changed.emit()


func _unequip_everywhere(uid: String) -> void:
	for m in save.monsters.values():
		for slot in m.equip.keys():
			if m.equip[slot] == uid:
				m.equip.erase(slot)


func equip(mon_uid: String, item_uid: String) -> Dictionary:
	var m := monster(mon_uid)
	var it: Dictionary = save.items.get(item_uid, {})
	if m.is_empty() or it.is_empty():
		return {"ok": false, "error": Loc.t("Inválido")}
	var b := ItemLogic.base(it)
	if int(b.level) > int(m.level):
		return {"ok": false, "error": Loc.t("Requer nível %d") % int(b.level)}
	_unequip_everywhere(item_uid)
	var slot: String = b.slot
	if m.equip.has(slot) and save.items.has(m.equip[slot]):
		save.items[m.equip[slot]].loc = "inv"
	m.equip[slot] = item_uid
	it.loc = "equip"
	inventory_changed.emit()
	monsters_changed.emit()
	return {"ok": true}


func unequip(mon_uid: String, slot: String) -> void:
	var m := monster(mon_uid)
	if m.is_empty() or not m.equip.has(slot):
		return
	var iu: String = m.equip[slot]
	m.equip.erase(slot)
	if save.items.has(iu):
		save.items[iu].loc = "inv"
	inventory_changed.emit()
	monsters_changed.emit()


func toggle_lock(uid: String) -> void:
	if save.items.has(uid):
		save.items[uid].locked = not save.items[uid].get("locked", false)
		inventory_changed.emit()


func move_item(uid: String, to_loc: String) -> Dictionary:
	var it: Dictionary = save.items.get(uid, {})
	if it.is_empty() or it.loc == "equip":
		return {"ok": false, "error": Loc.t("Item equipado")}
	if to_loc == "inv" and inv_count() >= inv_cap():
		return {"ok": false, "error": Loc.t("Inventário cheio")}
	if to_loc == "depot" and depot_items().size() >= int(DataDB.config.inventory.depot_cap):
		return {"ok": false, "error": Loc.t("Depot cheio")}
	it.loc = to_loc
	inventory_changed.emit()
	return {"ok": true}


func sell_item(uid: String) -> Dictionary:
	var it: Dictionary = save.items.get(uid, {})
	if it.is_empty():
		return {"ok": false, "error": Loc.t("Item inválido")}
	if it.get("locked", false):
		return {"ok": false, "error": Loc.t("Item travado. Destrave para vender.")}
	if it.loc == "equip":
		return {"ok": false, "error": Loc.t("Desequipe antes de vender.")}
	var r := await Backend.request("npc_sell", {"item": it})
	if r.get("ok", false):
		remove_item(uid)
		_apply_wallet(r.wallet)
	return r


## Vende vários itens ao NPC de uma vez (ignora travados e equipados).
func sell_items(uids: Array) -> Dictionary:
	var items: Array = []
	for uid in uids:
		var it: Dictionary = save.items.get(uid, {})
		if it.is_empty() or it.get("locked", false) or it.loc == "equip":
			continue
		items.append(it)
	var gold := 0
	var sold := 0
	var i := 0
	while i < items.size():
		var r := await Backend.request("npc_sell_many", {"items": items.slice(i, i + 100)})
		i += 100
		if not r.get("ok", false):
			return r
		for u in r.sold:
			remove_item(u)
			sold += 1
		gold += int(r.gold_gained)
		_apply_wallet(r.wallet)
	return {"ok": true, "sold": sold, "gold_gained": gold}


func buy_from_shop(base_id: String) -> Dictionary:
	if inv_count() >= inv_cap():
		return {"ok": false, "error": Loc.t("Inventário cheio")}
	var r := await Backend.request("npc_buy", {"base": base_id})
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		add_item(r.item)
	return r


func inventory_expand_cost() -> int:
	var inv: Dictionary = DataDB.config.inventory
	var steps := (inv_cap() - int(inv.base_cap)) / int(inv.expand_step)
	return int(inv.expand_cost_base) * (steps + 1) * (steps + 1)


func expand_inventory() -> Dictionary:
	var inv: Dictionary = DataDB.config.inventory
	if inv_cap() >= int(inv.max_cap):
		return {"ok": false, "error": Loc.t("Limite máximo")}
	var r := await Backend.request("spend", {"gold": inventory_expand_cost(), "essences": {}, "reason": "inventory"})
	if r.get("ok", false):
		save.inventory_cap = inv_cap() + int(inv.expand_step)
		_apply_wallet(r.wallet)
		inventory_changed.emit()
	return r


func enhance_item(uid: String) -> Dictionary:
	var it: Dictionary = save.items.get(uid, {})
	if it.is_empty():
		return {"ok": false, "error": Loc.t("Item inválido")}
	var r: Dictionary
	if it.get("bound", false):
		var cost := EssenceLogic.enhance_cost(it)
		r = await Backend.request("spend", {"gold": cost.gold, "essences": {cost.essence_type: cost.essence}, "reason": "enhance_bound"})
		if r.get("ok", false):
			r["success"] = EssenceLogic.try_enhance(it, rng)
	else:
		r = await Backend.request("enhance_item", {"uid": uid})
		if r.get("ok", false):
			var loc: String = it.get("loc", "inv")
			var locked: bool = it.get("locked", false)
			var ni: Dictionary = r.item
			ni["loc"] = loc
			ni["locked"] = locked
			save.items[uid] = ni
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		inventory_changed.emit()
		monsters_changed.emit()
	return r


# ================================================================ market (espelho local)

func market_list_item(uid: String, price: int) -> Dictionary:
	var it: Dictionary = save.items.get(uid, {})
	if it.is_empty() or it.get("bound", false):
		return {"ok": false, "error": Loc.t("Item não negociável")}
	if it.get("locked", false):
		return {"ok": false, "error": Loc.t("Item travado")}
	if it.loc == "equip":
		return {"ok": false, "error": Loc.t("Desequipe antes")}
	var r := await Backend.request("market_list_item", {"uid": uid, "price": price})
	if r.get("ok", false):
		remove_item(uid)
		_apply_wallet(r.wallet)
	return r


func market_list_essence(type_id: String, amount: int, price: int) -> Dictionary:
	var r := await Backend.request("market_list_essence", {"type": type_id, "amount": amount, "price": price})
	if r.get("ok", false):
		_apply_wallet(r.wallet)
	return r


func market_buy(listing_id: String) -> Dictionary:
	var r := await Backend.request("market_buy", {"listing": listing_id})
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		if not r.get("item", {}).is_empty():
			add_item(r.item)
	return r


func market_cancel(listing_id: String) -> Dictionary:
	var r := await Backend.request("market_cancel", {"listing": listing_id})
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		if not r.get("item", {}).is_empty():
			add_item(r.item)
	return r


func market_my() -> Dictionary:
	var r := await Backend.request("market_my")
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		if not r.get("sales", []).is_empty():
			_apply_sales(r.sales)
	return r


# ================================================================ hunts e desafios

func challenge_cleared(cid: String) -> bool:
	return save.challenges.get(cid, {}).get("cleared", false)


func challenge_level_cleared(level: int) -> bool:
	if level <= 0:
		return true
	var c := DataDB.challenge_for_level(level)
	return c.is_empty() or challenge_cleared(c.id)


func world2_unlocked() -> bool:
	return save.debug_unlock_all or challenge_level_cleared(int(DataDB.config.world2.unlock_challenge))


func hunt_lock_reason(h: Dictionary) -> String:
	if save.debug_unlock_all:
		return ""
	if main_level() < int(h.unlock_level):
		return Loc.t("Requer nível %d") % int(h.unlock_level)
	var rc := int(h.get("requires_challenge", 0))
	if rc > 0 and not challenge_level_cleared(rc):
		return Loc.t("Vença o Desafio %d") % rc
	return ""


func challenge_lock_reason(c: Dictionary) -> String:
	if save.debug_unlock_all:
		return ""
	var prev := 0
	for cc in DataDB.challenges:
		if int(cc.level) < int(c.level):
			prev = int(cc.level)
	if prev > 0 and not challenge_level_cleared(prev):
		return Loc.t("Vença o Desafio %d") % prev
	if main_level() < int(c.level) - 5:
		return Loc.t("Requer nível %d") % (int(c.level) - 5)
	var cd := challenge_cooldown(c.id)
	if cd > 0:
		return Loc.t("Aguarde %ds") % int(ceil(cd))
	return ""


func challenge_cooldown(cid: String) -> float:
	var lf := float(save.challenges.get(cid, {}).get("last_fail", 0.0))
	return max(0.0, lf + DataDB.challenge_fail_cooldown - GameClock.now())


func set_current_hunt(hunt_id: String) -> void:
	if pending_kills.size() > 0:
		await flush_claims()
	save.current_hunt = hunt_id
	save_local()


func finish_challenge(cid: String, won: bool, seconds: float) -> Dictionary:
	var rec: Dictionary = save.challenges.get(cid, {"cleared": false, "best": 0.0, "last_fail": 0.0})
	save.challenges[cid] = rec
	var r := await Backend.request("claim_challenge", {"challenge": cid, "won": won, "seconds": seconds, "party": party_snapshot()})
	if not won:
		rec.last_fail = GameClock.now()
		save_local()
		return r
	if r.get("ok", false):
		rec.cleared = true
		rec.best = float(r.get("best", seconds))
		_apply_wallet(r.wallet)
		for it in r.get("items", []):
			add_item(it)
		save_local()
	return r


func suggest_easier_hunt(current_id: String) -> Dictionary:
	var cur: Dictionary = DataDB.hunts.get(current_id, {})
	var best := {}
	for h in DataDB.hunt_list:
		if hunt_lock_reason(h) != "":
			continue
		if int(h.level) < int(cur.get("level", 1)) and (best.is_empty() or int(h.level) > int(best.level)):
			best = h
	return best


func recommended_hunt() -> Dictionary:
	var lvl := main_level()
	var best := {}
	for h in DataDB.hunt_list:
		if hunt_lock_reason(h) != "":
			continue
		if int(h.level) <= lvl + 2 and (best.is_empty() or int(h.level) > int(best.level)):
			best = h
	return best


# ================================================================ chefe diário

func daily_status() -> Dictionary:
	return await Backend.request("daily_boss_status", {"level": main_level()})


func daily_start() -> Dictionary:
	await flush_claims()
	return await Backend.request("daily_boss_start", {"level": main_level()})


func daily_claim(token: String, fraction: float, seconds: float, won: bool) -> Dictionary:
	var r := await Backend.request("daily_boss_claim", {"token": token, "fraction": fraction, "seconds": seconds, "won": won, "party": party_snapshot()})
	if r.get("ok", false):
		_apply_wallet(r.wallet)
		for it in r.get("items", []):
			add_item(it)
		save.stats.daily_boss = int(save.stats.get("daily_boss", 0)) + 1
		save_local()
	return r


# ================================================================ debug

func debug_grant(gold: int, ess: int) -> void:
	var essences := {}
	for t in DataDB.type_ids:
		essences[t] = ess
	var r := await Backend.request("debug_grant", {"gold": gold, "essences": essences})
	if r.get("ok", false):
		_apply_wallet(r.wallet)


func debug_set_level(level: int) -> void:
	for m in party_monsters():
		MonsterLogic.set_level(m, level)
		_mark_obtained(MonsterLogic.form_id(m), bool(m.shiny))
	await Backend.request("debug_set_validated_level", {"level": level})
	monsters_changed.emit()
	party_changed.emit()
