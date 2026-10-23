extends SceneTree
## Exporta os dados de balanceamento (incluindo as hunts do Mundo 2 geradas) para a Edge Function.
##   godot --headless --path . -s tools/export_server_data.gd
## Gera supabase/functions/_shared/gamedata.json — rode de novo sempre que mudar data/*.json.


func _initialize() -> void:
	DataDB.load_all()
	var hunts := {}
	for h in DataDB.hunt_list:
		hunts[h.id] = {"id": h.id, "world": h.world, "level": h.level, "monsters": h.monsters, "density": h.density,
			"drops": h.drops, "recruit": h.get("recruit", false), "recruit_mult": h.get("recruit_mult", 1.0),
			"xp_mult": h.get("xp_mult", 1.0), "gold_mult": h.get("gold_mult", 1.0), "rarity_mult": h.get("rarity_mult", 1.0)}
	var out := {
		"config": DataDB.config, "types": DataDB.type_ids, "strong_mult": DataDB.strong_mult, "weak_mult": DataDB.weak_mult,
		"families": DataDB.families, "forms": DataDB.forms, "abilities": DataDB.abilities, "hunts": hunts,
		"challenges": DataDB.challenges, "challenge_fail_cooldown": DataDB.challenge_fail_cooldown,
		"item_bases": DataDB.item_bases, "iap": DataDB.iap,
		"form_order": _adult_order(), "item_tiers": DataDB.item_tiers, "item_slots": DataDB.item_slots, "affixes": DataDB.affixes,
	}
	var f := FileAccess.open("res://supabase/functions/_shared/gamedata.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	print("gamedata.json exportado (%d hunts)" % hunts.size())
	quit()



func _adult_order() -> Array:
	var out: Array = []
	for f in DataDB.form_list:
		if int(f.stage) == 3:
			out.append(f.form_id)
	return out
