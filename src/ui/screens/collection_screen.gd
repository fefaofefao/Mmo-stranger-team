extends Screen
## Coleção das 135 formas: vistas, abates, obtidas e shiny. Marcos de abates dão bônus.

var type_tab := 0


func build() -> void:
	var b := make_layout(Loc.t("Coleção"), "book")
	var seen := 0
	var shiny := 0
	for fid in Game.save.collection:
		var c: Dictionary = Game.save.collection[fid]
		if c.get("seen", false):
			seen += 1
		if c.get("shiny", false):
			shiny += 1
	var bon := Game.account_bonuses()
	var chips := UI.hbox(6)
	chips.add_child(UI.chip("book", Loc.t("Vistas %d") % seen, UI.C_TEXT, 17))
	chips.add_child(UI.chip("check", Loc.t("Obtidas %d/135") % Game.collection_count(), UI.C_GOOD, 17))
	chips.add_child(UI.chip("sparkle", Loc.t("Shiny %d") % shiny, UI.C_GOLD, 17))
	b.add_child(chips)
	b.add_child(UI.label(Loc.t("Marcos de abates: %d (+%.1f%% ataque e +%.1f%% XP permanentes)") % [int(bon.milestones), bon.atk_pct, bon.xp_pct], 17, UI.C_MUTED, true))
	var row1: Array = []
	for t in DataDB.type_ids:
		row1.append(DataDB.type_name(t).substr(0, 4))
	b.add_child(tabs(row1.slice(0, 5), type_tab if type_tab < 5 else -1, func(i): type_tab = i; rebuild()))
	b.add_child(tabs(row1.slice(5), type_tab - 5 if type_tab >= 5 else -1, func(i): type_tab = i + 5; rebuild()))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	var g := UI.grid(3, 8)
	sc[1].add_child(g)
	var tid: String = DataDB.type_ids[type_tab]
	var ms: Array = DataDB.config.collection.milestones
	for f in DataDB.form_list:
		if f.type != tid:
			continue
		var c: Dictionary = Game.save.collection.get(f.form_id, {})
		var p := UI.card(c.get("recruited", false), not c.get("seen", false))
		p.custom_minimum_size = Vector2(216, 0)
		var v := UI.vbox(2)
		p.add_child(v)
		var pf := UI.portrait_frame(f.form_id, c.get("shiny", false), 84, c.get("seen", false))
		pf.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pf)
		var nm := UI.label(f.name if c.get("seen", false) else "???", 18, UI.C_GOLD if c.get("recruited", false) else UI.C_TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		v.add_child(nm)
		var k := int(c.get("kills", 0))
		var stars := 0
		for m in ms:
			if k >= int(m):
				stars += 1
		var sr := UI.hbox(2)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.add_child(UI.label(UI.fmt(k), 15, UI.C_MUTED))
		for i in 3:
			sr.add_child(UI.icon("star" if i < stars else "star_empty", 16))
		v.add_child(sr)
		var fr := UI.hbox(4)
		fr.alignment = BoxContainer.ALIGNMENT_CENTER
		if c.get("recruited", false):
			fr.add_child(UI.icon("check", 20))
		if c.get("shiny", false):
			fr.add_child(UI.icon("sparkle", 20))
		v.add_child(fr)
		g.add_child(p)
