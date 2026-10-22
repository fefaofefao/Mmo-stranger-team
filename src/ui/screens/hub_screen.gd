extends Screen
## Hub central em menu (sem personagem andando).

var _daily_badge := ""


func build() -> void:
	var b := make_layout(Loc.t("Hub"), "house")
	var art_panel := UI.panel("inset")
	b.add_child(art_panel)
	var art := UI.tex(HubArt.texture(), 280)
	art.custom_minimum_size = Vector2(0, 280)
	art_panel.add_child(art)
	var main_m := Game.main_monster()
	if not main_m.is_empty():
		var info := UI.card()
		b.add_child(info)
		var row := UI.hbox(10)
		info.add_child(row)
		row.add_child(UI.portrait_frame(MonsterLogic.form_id(main_m), bool(main_m.shiny), 56))
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UI.label("%s · %s" % [MonsterLogic.display_name(main_m), Loc.t("Nv %d") % int(main_m.level)], 22, UI.C_GOLD))
		col.add_child(UI.label(Loc.t("Coleção %d/135 · Essências %s") % [Game.collection_count(), _ess_total()], 18, UI.C_MUTED))
	var sc := UI.scroll(10)
	b.add_child(sc[0])
	var g := UI.grid(3, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc[1].add_child(g)
	var items := [
		["sword", Loc.t("Caçar"), "hunt", "primary"], ["map", Loc.t("Hunts"), "hunts", ""], ["crown", Loc.t("Chefe Diário"), "daily", ""],
		["skull", Loc.t("Desafios"), "challenges", ""], ["paw", Loc.t("Grupo"), "party", ""], ["chest", Loc.t("Depot"), "depot", ""],
		["bag", Loc.t("Inventário"), "inventory", ""], ["shop", Loc.t("Loja"), "shop", ""], ["scales", Loc.t("Market"), "market", ""],
		["altar", Loc.t("Altar"), "altar", ""], ["book", Loc.t("Coleção"), "collection", ""], ["trophy", Loc.t("Rankings"), "rankings", ""],
		["gear", Loc.t("Ajustes"), "settings", ""],
	]
	for it in items:
		var target: String = it[2]
		var badge := ""
		if target == "daily":
			badge = _daily_badge
		g.add_child(UI.tile_button(it[0], it[1], func(): main.goto(target), 52, Vector2(214, 132), it[3], badge))
	if _daily_badge == "":
		_load_daily()


func _load_daily() -> void:
	var r: Dictionary = await Game.daily_status()
	if r.get("ok", false) and is_inside_tree():
		_daily_badge = "%d/%d" % [int(r.entries) - int(r.used), int(r.entries)]
		rebuild()


func _ess_total() -> String:
	var t := 0
	for k in Game.save.essences:
		t += int(Game.save.essences[k])
	return UI.fmt(t)
