extends Screen
## Coleção das 135 formas: vistas, abates, obtidas e shiny + resumo dos Marcos de Caça (bônus da conta).

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
	# resumo dos Marcos de Caça: um bônus por tipo
	var mp := UI.panel("inset")
	b.add_child(mp)
	var mv := UI.vbox(4)
	mp.add_child(mv)
	mv.add_child(UI.label(Loc.t("Marcos de Caça: %d marcos · bônus permanentes da conta") % int(bon.tiers), 17, UI.C_GOLD))
	var mg := UI.grid(3, 4)
	mv.add_child(mg)
	for t in DataDB.type_ids:
		var st: Dictionary = Mastery.stat_of_type(t)
		var cell := UI.hbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(UI.icon(Mastery.stat_icon(st.stat), 24))
		var val: float = bon.get(st.stat, 0.0)
		var l := UI.label(Mastery.fmt_bonus(st.stat, val), 15, UI.C_GOOD if val > 0 else UI.C_MUTED)
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(l)
		mg.add_child(cell)
	# abas por tipo com o ícone do elemento
	var trow := UI.hbox(4)
	b.add_child(trow)
	for i in DataDB.type_ids.size():
		var idx := i
		var t: String = DataDB.type_ids[i]
		var tb := UI.button("", func(): type_tab = idx; rebuild(), 16, 56, "tab_on" if i == type_tab else "tab")
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic := UI.icon("t_" + t, 34)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_top = 6
		ic.offset_bottom = -6
		tb.add_child(ic)
		trow.add_child(tb)
	var st_t: Dictionary = Mastery.stat_of_type(DataDB.type_ids[type_tab])
	b.add_child(UI.label(Loc.t("%s: cada marco de uma forma deste tipo dá %s por ponto.") % [DataDB.type_name(DataDB.type_ids[type_tab]), Mastery.fmt_bonus(st_t.stat, float(st_t.per_point))], 15, UI.C_MUTED, true))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	var g := UI.grid(3, 8)
	sc[1].add_child(g)
	var tid: String = DataDB.type_ids[type_tab]
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
		var info := Mastery.form_info(f.form_id, k)
		var sr := UI.hbox(4)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		if int(info.tier) > 0:
			sr.add_child(UI.pill(Mastery.tier_name(info.tier), Mastery.tier_color(info.tier), 13))
		sr.add_child(UI.label(UI.fmt(k) if info.max else "%s/%s" % [UI.fmt(k), UI.fmt(info.next_at)], 14, UI.C_MUTED))
		v.add_child(sr)
		var pb := UI.bar(info.progress, Mastery.tier_color(mini(int(info.tier) + 1, 6)), 180, 7)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(pb)
		if int(info.tier) > 0:
			var el := UI.label(Mastery.fmt_bonus(info.stat, info.earned), 13, UI.C_GOOD)
			el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			el.clip_text = true
			v.add_child(el)
		var fr := UI.hbox(4)
		fr.alignment = BoxContainer.ALIGNMENT_CENTER
		if c.get("recruited", false):
			fr.add_child(UI.icon("check", 20))
		if c.get("shiny", false):
			fr.add_child(UI.icon("sparkle", 20))
		v.add_child(fr)
		g.add_child(p)
