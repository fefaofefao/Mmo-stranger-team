extends Screen
## Escolha do monstro inicial (9 opções, 1 por tipo).

var selected := ""


func build() -> void:
	var b := make_layout(Loc.t("Escolha seu parceiro"), "paw", false)
	var hint := UI.label(Loc.t("Cada tipo é forte contra o próximo do ciclo:") + "\n" + _cycle(), 18, UI.C_MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(hint)
	var g := UI.grid(3, 8)
	b.add_child(g)
	if selected == "":
		selected = DataDB.starters()[0].id
	for fam in DataDB.starters():
		var fid: String = fam.stages[0].form_id
		var fam_id: String = fam.id
		var card := UI.button("", func(): selected = fam_id; rebuild(), 20, 168, "tab_on" if selected == fam_id else "tab")
		card.custom_minimum_size = Vector2(220, 168)
		var cv := UI.vbox(2)
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := UI.portrait(fid, false, 92)
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(p)
		var n := UI.label(DataDB.form_name(fid), 21)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(n)
		var tb := UI.type_badge(fam.type, 15)
		tb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(tb)
		card.add_child(cv)
		g.add_child(card)
	var p2 := UI.panel("panel_gold")
	p2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(p2)
	var detail := UI.vbox(8)
	p2.add_child(detail)
	var fam: Dictionary = DataDB.families[selected]
	var f1 := DataDB.form(fam.stages[0].form_id)
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.add_child(row)
	for i in fam.stages.size():
		var st: Dictionary = fam.stages[i]
		var c := UI.vbox(2)
		c.add_child(UI.portrait_frame(st.form_id, false, 84 + i * 6))
		var l := UI.label(st.name, 17, UI.C_GOLD if i == 0 else UI.C_MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
		row.add_child(c)
		if i < 2:
			var ar := UI.label("›", 30, UI.C_MUTED)
			ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ar)
	var info := UI.hbox(8)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UI.type_badge(fam.type, 18))
	info.add_child(UI.pill(_style(fam.style), UI.C_INFO, 18))
	info.add_child(UI.pill(Loc.t("Evolui: Nv %d e %d") % [int(fam.evo_levels[0]), int(fam.evo_levels[1])], UI.C_GOLD, 18))
	detail.add_child(info)
	var d := UI.label(DataDB.form_desc(f1.form_id), 21, UI.C_TEXT, true)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(d)
	var s := Formulas.raw_stats(f1.form_id, 1)
	var sl := UI.label(Loc.t("HP %d · ATQ %d · DEF %d · VEL %d · Alcance %d") % [s.hp, s.atk, s.def, s.spd, s.rng], 19, UI.C_MUTED)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(sl)
	var tl := UI.label(Loc.t("Forte contra %s · Fraco contra %s") % [DataDB.type_name(TypeChart.strong_against(fam.type)), DataDB.type_name(TypeChart.weak_against(fam.type))], 19, UI.C_MUTED, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(tl)
	detail.add_child(UI.hspace())
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(sp)
	detail.add_child(UI.icon_button("paw", Loc.t("Escolher %s") % f1.name, _confirm, 28, 84, "primary"))


static func _style(s: String) -> String:
	return {"melee": Loc.t("Corpo a corpo"), "ranged": Loc.t("Distância"), "magic": Loc.t("Mágico")}.get(s, s)


func _cycle() -> String:
	var names: Array = []
	for t in DataDB.type_ids:
		names.append(DataDB.type_name(t))
	names.append(names[0])
	return " › ".join(names)


func _confirm() -> void:
	var f1 := DataDB.form(DataDB.families[selected].stages[0].form_id)
	if not await main.confirm(Loc.t("Confirmar"), Loc.t("Começar a jornada com %s?") % f1.name):
		return
	await Game.choose_starter(selected)
	main.goto("hunt")
	main.toast(Loc.t("%s já está caçando sozinho!") % f1.name, UI.C_GOLD, "paw")
