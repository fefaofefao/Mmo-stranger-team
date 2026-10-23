class_name MonsterPicker
extends Control
## Janela modal para escolher um monstro do Depot (ordenado por Poder).
## `var uid = await picker.chosen` ("" = cancelado).

signal chosen(uid: String)


static func open(parent: Node, title: String, current: Dictionary = {}) -> MonsterPicker:
	var p := MonsterPicker.new()
	parent.add_child(p)
	p._build(title, current)
	return p


func _build(title: String, current: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close(""))
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UI.panel("panel_gold")
	var vh := get_viewport_rect().size.y
	panel.custom_minimum_size = Vector2(660, minf(980.0, vh * 0.78))
	center.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	var head := UI.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UI.icon("swap", 36))
	head.add_child(UI.title(title, 28))
	v.add_child(head)
	if not current.is_empty():
		var cur := UI.panel("inset")
		var cr := UI.hbox(10)
		cur.add_child(cr)
		cr.add_child(UI.portrait_frame(MonsterLogic.form_id(current), bool(current.shiny), 48))
		var cl := UI.label(Loc.t("Sai: %s · Poder %d") % [MonsterLogic.display_name(current), MonsterLogic.power(Game.monster_stats(current))], 19, UI.C_MUTED)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cl.clip_text = true
		cr.add_child(cl)
		v.add_child(cur)
	var sc := UI.scroll(8)
	v.add_child(sc[0])
	var list: VBoxContainer = sc[1]
	var dep: Array = []
	for m in Game.depot_monsters():
		dep.append({"m": m, "power": MonsterLogic.power(Game.monster_stats(m))})
	dep.sort_custom(func(a, b): return a.power > b.power)
	if dep.is_empty():
		var l := UI.label(Loc.t("Nenhum monstro no Depot. Cada abate no Mundo 1 tem chance de recrutar o monstro."), 20, UI.C_MUTED, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(l)
	for e in dep:
		var m: Dictionary = e.m
		var card := UI.card()
		var row := UI.hbox(10)
		card.add_child(row)
		row.add_child(UI.monster_frame(m, 56))
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var nl := UI.label(MonsterLogic.display_name(m), 20)
		nl.clip_text = true
		col.add_child(nl)
		var r := UI.hbox(4)
		r.add_child(UI.pill(Loc.t("Nv %d") % int(m.level), UI.C_GOLD, 14))
		r.add_child(UI.type_badge(MonsterLogic.type_of(m), 14))
		r.add_child(UI.quality_badge(m, 14))
		col.add_child(r)
		col.add_child(UI.label(Loc.t("Poder %d") % int(e.power), 15, UI.C_MUTED))
		var uid: String = m.uid
		row.add_child(UI.small_button(Loc.t("Escolher"), func(): _close(uid), "primary"))
		list.add_child(card)
	v.add_child(UI.button(Loc.t("Cancelar"), func(): _close(""), 22, 64))
	UI.touch_friendly(self)


func _close(uid: String) -> void:
	chosen.emit(uid)
	queue_free()
