class_name HuntStatsPanel
extends Control
## Status da caça atual: abates, médias por hora, XP, ouro, itens, shinies e recrutas.
## Atualiza ao vivo com o mapa rodando por trás. Os contadores zeram ao trocar de hunt.

var _vals := {}      # chave -> [Label valor, Label por hora]
var _time_l: Label
var _rar_box: HBoxContainer
var _t := 0.0


static func open(parent: Node) -> HuntStatsPanel:
	var p := HuntStatsPanel.new()
	parent.add_child(p)
	p._build()
	return p


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: queue_free())
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UI.panel("panel_gold")
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var v := UI.vbox(8)
	panel.add_child(v)
	var head := UI.hbox(10)
	head.add_child(UI.icon("stats", 40))
	var tv := UI.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.title(Loc.t("Status da caça"), 26))
	var hl := UI.label(DataDB.hunt_name(DataDB.hunts.get(Game.save.current_hunt, {})), 17, UI.C_MUTED)
	hl.clip_text = true
	tv.add_child(hl)
	head.add_child(tv)
	_time_l = UI.label("", 18, UI.C_TEXT)
	head.add_child(_time_l)
	v.add_child(head)
	var g := UI.grid(3, 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(g)
	for row in [["kills", "sword", Loc.t("Monstros caçados")], ["xp", "xp", Loc.t("XP ganho")], ["gold", "coin", Loc.t("Ouro")],
			["items", "bag", Loc.t("Itens dropados")], ["shinies", "sparkle", Loc.t("Shinies encontrados")], ["recruits", "egg", Loc.t("Monstros recrutados")]]:
		var nh := UI.hbox(8)
		nh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nh.add_child(UI.icon(row[1], 30))
		nh.add_child(UI.label(row[2], 19, UI.C_TEXT))
		g.add_child(nh)
		var val := UI.label("0", 21, UI.C_GOLD)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(110, 0)
		g.add_child(val)
		var ph := UI.label("", 16, UI.C_MUTED)
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ph.custom_minimum_size = Vector2(130, 0)
		g.add_child(ph)
		_vals[row[0]] = [val, ph]
	_rar_box = UI.hbox(6)
	v.add_child(_rar_box)
	v.add_child(UI.label(Loc.t("Conta só a caça com o mapa aberto (sem o ganho offline). Zera ao trocar de hunt."), 15, UI.C_MUTED, true))
	var close := UI.button(Loc.t("Fechar"), queue_free, 20, 58)
	v.add_child(close)
	_refresh()


func _process(d: float) -> void:
	_t += d
	if _t >= 0.5:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	var s := Game.hunt_session_stats()
	_time_l.text = UI.fmt_time(float(s.seconds))
	var per_h := {"kills": s.kills_per_hour, "xp": s.xp_per_hour, "gold": s.gold_per_hour}
	for k in _vals:
		_vals[k][0].text = UI.fmt(float(s[k]))
		_vals[k][1].text = (Loc.t("%s/h") % UI.fmt(per_h[k])) if per_h.has(k) else ""
	if int(s.shiny_recruits) > 0:
		_vals.recruits[1].text = Loc.t("%d shiny") % int(s.shiny_recruits)
	UI.clear(_rar_box)
	for r in DataDB.rarities:
		var n := int(s.items_by_rarity.get(r.id, 0))
		if n > 0:
			_rar_box.add_child(UI.pill("%s %d" % [DataDB.rarity_name(r.id), n], DataDB.rarity_color(r.id), 15))
