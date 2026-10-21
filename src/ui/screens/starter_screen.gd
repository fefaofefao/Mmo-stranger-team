extends Screen
## Escolha do monstro inicial (9 opções, 1 por tipo).

var selected := ""
var detail: VBoxContainer


func build() -> void:
	var b := make_layout("Escolha seu inicial", false)
	var hint := UI.label("Cada tipo é forte contra o próximo do ciclo e fraco contra o anterior:\nÁgua › Fogo › Gelo › Planta › Terra › Elétrico › Vento › Luz › Sombra › Água", 19, UI.C_MUTED, true)
	b.add_child(hint)
	var g := UI.grid(3, 10)
	b.add_child(g)
	for fam in DataDB.starters():
		var fid: String = fam.stages[0].form_id
		var card := UI.button("", func(): _select(fam.id), 20, 170)
		card.custom_minimum_size = Vector2(220, 170)
		var cv := UI.vbox(2)
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		var p := UI.portrait(fid, false, 96)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(p)
		var n := UI.label(DataDB.form(fid).name, 22)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(n)
		var tl := UI.type_badge(fam.type, 18)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(tl)
		if selected == fam.id:
			card.add_theme_stylebox_override("normal", UI.sb(Color("#6a5838"), UI.C_GOLD))
		card.add_child(cv)
		g.add_child(card)
	var p2 := UI.panel()
	p2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(p2)
	detail = UI.vbox(8)
	p2.add_child(detail)
	_show_detail()


func _select(fid: String) -> void:
	selected = fid
	rebuild()


func _show_detail() -> void:
	if selected == "":
		detail.add_child(UI.label("Toque em um monstro para ver detalhes.", 22, UI.C_MUTED))
		return
	var fam: Dictionary = DataDB.families[selected]
	var f1 := DataDB.form(fam.stages[0].form_id)
	var row := UI.hbox(12)
	detail.add_child(row)
	for st in fam.stages:
		var c := UI.vbox(0)
		c.add_child(UI.portrait(st.form_id, false, 80))
		var l := UI.label(st.name, 18, UI.C_MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
		row.add_child(c)
	var style_name := {"melee": "Corpo a corpo", "ranged": "Distância", "magic": "Mágico"}
	detail.add_child(UI.label("%s · %s · Evolui nos níveis %d e %d" % [DataDB.type_name(fam.type), style_name[fam.style], int(fam.evo_levels[0]), int(fam.evo_levels[1])], 20, UI.C_GOLD, true))
	detail.add_child(UI.label(f1.desc, 20, UI.C_TEXT, true))
	var s := Formulas.raw_stats(f1.form_id, 1)
	detail.add_child(UI.label("HP %d · ATQ %d · DEF %d · VEL %d · Alcance %d" % [s.hp, s.atk, s.def, s.spd, s.rng], 20))
	detail.add_child(UI.label("Forte contra %s · Fraco contra %s" % [DataDB.type_name(TypeChart.strong_against(fam.type)), DataDB.type_name(TypeChart.weak_against(fam.type))], 20, UI.C_MUTED, true))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	detail.add_child(UI.button("Escolher %s" % f1.name, _confirm, 28, 80))


func _confirm() -> void:
	var f1 := DataDB.form(DataDB.families[selected].stages[0].form_id)
	if not await main.confirm("Confirmar", "Começar a jornada com %s?" % f1.name):
		return
	await Game.choose_starter(selected)
	main.goto("hunt")
	main.toast("Seu %s já está caçando sozinho! Acompanhe pelo mapa." % f1.name, UI.C_GOLD)
