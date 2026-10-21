extends Screen
## Coleção das 135 formas: vistas, abates, recrutadas e shiny. Marcos de abates dão bônus.

var type_tab := 0


func build() -> void:
	var b := make_layout("Coleção")
	var seen := 0
	var got := Game.collection_count()
	var shiny := 0
	for fid in Game.save.collection:
		var c: Dictionary = Game.save.collection[fid]
		if c.get("seen", false):
			seen += 1
		if c.get("shiny", false):
			shiny += 1
	var bon := Game.account_bonuses()
	b.add_child(UI.label("Vistas %d/135 · Obtidas %d/135 · Shiny %d\nMarcos: %d (+%.1f%% ataque, +%.1f%% XP permanentes)" % [seen, got, shiny, int(bon.milestones), bon.atk_pct, bon.xp_pct], 20, UI.C_MUTED, true))
	var names: Array = []
	for t in DataDB.type_ids:
		names.append(DataDB.type_name(t).substr(0, 4))
	b.add_child(tabs(names, type_tab, func(i): type_tab = i; rebuild()))
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	var g := UI.grid(3, 8)
	sc[1].add_child(g)
	var tid: String = DataDB.type_ids[type_tab]
	var ms: Array = DataDB.config.collection.milestones
	for f in DataDB.form_list:
		if f.type != tid:
			continue
		var c: Dictionary = Game.save.collection.get(f.form_id, {})
		var p := UI.panel()
		p.custom_minimum_size = Vector2(218, 0)
		var v := UI.vbox(2)
		p.add_child(v)
		var pr := UI.portrait(f.form_id, c.get("shiny", false), 80)
		if not c.get("seen", false):
			pr.modulate = Color(0, 0, 0, 0.85)
		v.add_child(pr)
		var nm := UI.label(f.name if c.get("seen", false) else "???", 19, UI.C_GOLD if c.get("recruited", false) else UI.C_TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var k := int(c.get("kills", 0))
		var stars := 0
		for m in ms:
			if k >= int(m):
				stars += 1
		var st := UI.label("%s abates %s" % [UI.fmt(k), "★".repeat(stars)], 16, UI.C_MUTED)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(st)
		var flags := ""
		if c.get("recruited", false):
			flags += "✓ obtida "
		if c.get("shiny", false):
			flags += "✦ shiny"
		var fl := UI.label(flags, 16, UI.C_GOOD)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(fl)
		g.add_child(p)
