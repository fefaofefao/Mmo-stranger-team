extends Screen
## Hub central em menu (sem personagem andando).

var _daily_badge := ""


func build() -> void:
	var b := make_layout(Loc.t("Hub"), "house")
	b.add_child(_showcase())
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
		g.add_child(UI.tile_button(it[0], it[1], func(): main.goto(target), 60, Vector2(214, 128), it[3], badge))
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


## Vitrine do grupo: cenário baixo com os monstros do grupo grandes, andando no lugar.
func _showcase() -> Control:
	var frame := UI.panel("inset")
	var box := Control.new()
	box.custom_minimum_size = Vector2(0, 250)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(box)
	var bg := TextureRect.new()
	bg.texture = HubArt.texture()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var party := Game.party_monsters()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -190
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	for i in party.size():
		var m: Dictionary = party[i]
		var px := 176.0 if i == 0 else 138.0
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.custom_minimum_size = Vector2(px + 40, 0)
		row.add_child(col)
		var sz := px * 0.82
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(sz, sz)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(holder)
		var spr := UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), sz)
		spr.size = Vector2(sz, sz)
		holder.add_child(spr)
		var tw := spr.create_tween().set_loops()
		var amp := 5.0 + i
		tw.tween_property(spr, "position:y", -amp, 0.55 + 0.1 * i).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "position:y", amp, 0.55 + 0.1 * i).as_relative().set_trans(Tween.TRANS_SINE)
		var tag := UI.panel("chip")
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tl := UI.label("%s · %s" % [MonsterLogic.display_name(m), Loc.t("Nv %d") % int(m.level)], 17 if i == 0 else 15, UI.C_GOLD if i == 0 else UI.C_TEXT)
		tag.add_child(tl)
		col.add_child(tag)
	var info := UI.panel("chip")
	info.position = Vector2(8, 8)
	var il := UI.label(Loc.t("Coleção %d/135 · Essências %s") % [Game.collection_count(), _ess_total()], 16, UI.C_TEXT)
	info.add_child(il)
	box.add_child(info)
	return frame
