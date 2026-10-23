class_name DataDB
extends RefCounted
## Carrega todos os dados de balanceamento (JSON em res://data) e oferece consultas.
## Classe estática para poder ser usada em testes headless e na simulação de balanceamento.

const DATA_DIR := "res://data/"

static var loaded := false
static var config: Dictionary = {}
static var ads_cfg: Dictionary = {}
static var iap: Dictionary = {}
static var backend_cfg: Dictionary = {}

static var type_ids: Array = []
static var type_info: Dictionary = {}
static var type_index: Dictionary = {}
static var strong_mult := 1.5
static var weak_mult := 0.67
static var neutral_mult := 1.0

static var families: Dictionary = {}
static var family_list: Array = []
static var forms: Dictionary = {}
static var form_list: Array = []
static var abilities: Dictionary = {}
static var biomes: Dictionary = {}
static var hunts: Dictionary = {}
static var hunt_list: Array = []
static var challenges: Array = []
static var challenge_by_id: Dictionary = {}
static var challenge_fail_cooldown := 60.0
static var item_bases: Dictionary = {}
static var item_slots: Array = []
static var item_tiers: Array = []
static var affixes: Array = []
static var rarities: Array = []
static var rarity_index: Dictionary = {}


static func ensure_loaded() -> void:
	if not loaded:
		load_all()


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataDB: não foi possível abrir %s" % path)
		return {}
	var txt := f.get_as_text()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("DataDB: JSON inválido em %s" % path)
		return {}
	return parsed


static func load_all() -> void:
	config = load_json(DATA_DIR + "config.json")
	ads_cfg = load_json(DATA_DIR + "ads.json")
	iap = load_json(DATA_DIR + "iap.json")
	backend_cfg = load_json(DATA_DIR + "backend.json")

	var t: Dictionary = load_json(DATA_DIR + "types.json")
	strong_mult = float(t.get("strong_mult", 1.5))
	weak_mult = float(t.get("weak_mult", 0.67))
	neutral_mult = float(t.get("neutral_mult", 1.0))
	type_ids.clear()
	type_info.clear()
	type_index.clear()
	for ti in t.get("types", []):
		type_index[ti.id] = type_ids.size()
		type_ids.append(ti.id)
		type_info[ti.id] = ti

	abilities = load_json(DATA_DIR + "abilities.json").get("abilities", {})

	families.clear()
	family_list.clear()
	forms.clear()
	form_list.clear()
	for fam in load_json(DATA_DIR + "families.json").get("families", []):
		families[fam.id] = fam
		family_list.append(fam)
		for st in fam.stages:
			var form := {
				"form_id": st.form_id, "name": st.name, "stage": int(st.stage), "desc": st.desc,
				"abilities": st.abilities, "family": fam.id, "type": fam.type, "shape": fam.shape,
				"style": fam.style, "hue_shift": float(fam.get("hue_shift", 0.0)), "features": fam.get("features", {}),
			}
			forms[st.form_id] = form
			form_list.append(form)

	biomes.clear()
	for b in load_json(DATA_DIR + "biomes.json").get("biomes", []):
		biomes[b.id] = b

	var it: Dictionary = load_json(DATA_DIR + "items.json")
	item_bases = it.get("bases", {})
	item_slots = it.get("slots", [])
	item_tiers = it.get("tiers", [])
	affixes = it.get("affixes", [])

	rarities = config.get("rarities", [])
	rarity_index.clear()
	for i in rarities.size():
		rarity_index[rarities[i].id] = i

	var ch: Dictionary = load_json(DATA_DIR + "challenges.json")
	challenges = ch.get("challenges", [])
	challenge_fail_cooldown = float(ch.get("fail_cooldown_seconds", 60))
	challenges.sort_custom(func(a, b): return a.level < b.level)
	challenge_by_id.clear()
	for c in challenges:
		challenge_by_id[c.id] = c

	hunts.clear()
	hunt_list.clear()
	for h in load_json(DATA_DIR + "hunts_world1.json").get("hunts", []):
		h["world"] = 1
		hunts[h.id] = h
		hunt_list.append(h)
	for h in generate_world2_hunts():
		hunts[h.id] = h
		hunt_list.append(h)
	loaded = true


## Mundo 2 é gerado a partir de config.world2 (escalável sem editar JSON de hunts).
static func generate_world2_hunts() -> Array:
	var w2: Dictionary = config.get("world2", {})
	var out: Array = []
	if w2.is_empty():
		return out
	var lvl := int(w2.start)
	var adults: Dictionary = {}
	for f in form_list:
		if f.stage == 3:
			if not adults.has(f.type):
				adults[f.type] = []
			adults[f.type].append(f.form_id)
	while lvl <= int(w2.end):
		for k in int(w2.hunts_per_level):
			var rng := RandomNumberGenerator.new()
			rng.seed = int(w2.seed) + lvl * 31 + k * 7
			var types: Array = []
			var pool := type_ids.duplicate()
			# tipos consecutivos no ciclo combinam melhor com biomas de transição
			var start := rng.randi_range(0, pool.size() - 1)
			for j in int(w2.types_per_hunt):
				var tid: String = pool[(start + j * (1 + k)) % pool.size()]
				if not types.has(tid):
					types.append(tid)
			var biome := biome_for_types(types, rng)
			var monsters: Array = []
			for j in int(w2.monsters_per_hunt):
				var tid2: String = types[j % types.size()]
				var arr: Array = adults[tid2]
				var fid: String = arr[rng.randi_range(0, arr.size() - 1)]
				monsters.append({"form": fid, "weight": 1})
			var h := {
				"id": "w2_%d_%d" % [lvl, k], "name": _w2_name(biomes[biome].name, _roman(k + 1)),
				"world": 2, "category": "mundo2", "level": lvl, "unlock_level": max(80, lvl - 5),
				"requires_challenge": int(w2.unlock_challenge), "biome": biome, "corrupted": true, "types": types,
				"monsters": monsters, "density": int(w2.density), "respawn": float(w2.respawn),
				"map_size": w2.map_size, "seed": int(w2.seed) * 1000 + lvl * 10 + k, "recruit": false,
				"recruit_mult": 0.0, "xp_mult": float(w2.get("xp_mult", 1.0)), "gold_mult": float(w2.gold_mult),
				"rarity_mult": float(w2.rarity_mult), "drops": world2_drops(types, lvl),
			}
			out.append(h)
		lvl += int(w2.step)
	return out


static func _w2_name(bname, roman: String) -> Dictionary:
	var out := {}
	var prefix := {"pt_BR": "Abismo", "en": "Abyss", "es": "Abismo"}
	for l in Loc.LANGS:
		var b := str(bname.get(l, bname.get("pt_BR", ""))) if bname is Dictionary else str(bname)
		out[l] = "%s · %s %s" % [prefix[l], b, roman]
	return out


static func _roman(n: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI"][clampi(n - 1, 0, 5)]


static func biome_for_types(types: Array, rng: RandomNumberGenerator = null) -> String:
	# bioma de transição que cubra os tipos; senão, bioma do tipo predominante
	var best := ""
	var best_cover := 0
	for b in biomes.values():
		if b.types.size() < 2:
			continue
		var cover := 0
		for t in types:
			if b.types.has(t):
				cover += 1
		if cover > best_cover and cover >= 2:
			best_cover = cover
			best = b.id
	if best != "":
		return best
	var subs := sub_biomes(types[0])
	if subs.is_empty():
		return biomes.keys()[0]
	if rng:
		return subs[rng.randi_range(0, subs.size() - 1)]
	return subs[0]


static func sub_biomes(type_id: String) -> Array:
	var out: Array = []
	for b in biomes.values():
		if b.types.size() == 1 and b.types[0] == type_id:
			out.append(b.id)
	return out


static func world2_drops(types: Array, level: int) -> Array:
	var tier := 1
	for tr in item_tiers:
		if int(tr.level) <= level:
			tier = int(tr.tier)
	var out: Array = []
	for t in types:
		for tt in [tier - 1, tier]:
			if tt < 1:
				continue
			for s in item_slots:
				var bid := "%s_%s_t%d" % [s.id, t, tt]
				if item_bases.has(bid):
					out.append({"base": bid, "weight": 3 if tt == tier else 1})
	return out


static func form(form_id: String) -> Dictionary:
	return forms.get(form_id, {})


static func family_of(form_id: String) -> Dictionary:
	var f := form(form_id)
	if f.is_empty():
		return {}
	return families.get(f.family, {})


static func form_for_stage(family_id: String, stage: int) -> String:
	var fam: Dictionary = families.get(family_id, {})
	if fam.is_empty():
		return ""
	return fam.stages[clampi(stage, 1, 3) - 1].form_id


static func starters() -> Array:
	var out: Array = []
	for fam in family_list:
		if fam.get("starter", false):
			out.append(fam)
	return out


static func type_name(type_id: String) -> String:
	return Loc.tx(type_info.get(type_id, {}).get("name", type_id))


static func rarity_name(id: String) -> String:
	return Loc.tx(rarity(id).get("name", id))


static func biome_name(id: String) -> String:
	return Loc.tx(biomes.get(id, {}).get("name", id))


static func hunt_name(h: Dictionary) -> String:
	return Loc.tx(h.get("name", h.get("id", "?")))


static func ability_name(id: String) -> String:
	return Loc.tx(abilities.get(id, {}).get("name", id))


static func form_name(form_id: String) -> String:
	return str(forms.get(form_id, {}).get("name", "?"))


static func form_desc(form_id: String) -> String:
	return Loc.tx(forms.get(form_id, {}).get("desc", ""))


static func challenge_name(c: Dictionary) -> String:
	return Loc.tx(c.get("name", c.get("id", "?")))


## Faixa de qualidade (Comum/Bom/Ótimo/Perfeito) para uma qualidade 0-100.
static func quality_grade(q: int) -> Dictionary:
	var best: Dictionary = {}
	for g in config.get("quality", {}).get("grades", []):
		if q >= int(g.min):
			best = g
	return best


static func type_color(type_id: String) -> Color:
	return Color(type_info.get(type_id, {}).get("color", "#ffffff"))


static func rarity(id: String) -> Dictionary:
	return rarities[rarity_index.get(id, 0)]


static func rarity_color(id: String) -> Color:
	return Color(rarity(id).get("color", "#ffffff"))


static func challenge_for_level(level: int) -> Dictionary:
	for c in challenges:
		if int(c.level) == level:
			return c
	return {}


static func iap_product(id: String) -> Dictionary:
	for pr in iap.get("products", []):
		if pr.id == id:
			return pr
	return {}
