class_name Screen
extends Control
## Base das telas de menu: cabeçalho padrão (voltar, ícone + título, ouro e Essência) e corpo.

var main  # Main
var params: Dictionary = {}
var body: VBoxContainer
var gold_chip: PanelContainer
var diamond_chip: PanelContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(p_main, p: Dictionary) -> void:
	main = p_main
	params = p
	rebuild()


func rebuild() -> void:
	UI.clear(self)
	add_child(UI.background())
	build()
	UI.touch_friendly(self)


func build() -> void:
	pass


## Cabeçalho + corpo com margem. Retorna o VBox do corpo.
func make_layout(p_title: String, icon_name := "", show_back := true) -> VBoxContainer:
	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var head := UI.panel("header")
	root.add_child(head)
	var top := UI.hbox(10)
	head.add_child(top)
	if show_back:
		var b := UI.icon_button("back", "", func(): main.back(), 20, 64)
		b.custom_minimum_size = Vector2(72, 64)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(b)
	if icon_name != "":
		top.add_child(UI.icon(icon_name, 40))
	var t := UI.label(p_title, 30, UI.C_GOLD)
	t.add_theme_constant_override("outline_size", 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(t)
	var wv := UI.vbox(2)
	wv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(wv)
	gold_chip = UI.chip("coin", "", UI.C_GOLD, 20)
	wv.add_child(gold_chip)
	diamond_chip = UI.chip("diamond", "", Color("#7fe8ff"), 18)
	diamond_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	diamond_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	diamond_chip.gui_input.connect(func(e):
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and get_meta("screen_name", "") != "diamonds":
			main.goto("diamonds"))
	wv.add_child(diamond_chip)
	_update_gold()
	if not Game.wallet_changed.is_connected(_update_gold):
		Game.wallet_changed.connect(_update_gold)
	var mc := UI.margin(UI.vbox(0), 12)
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mc)
	body = mc.get_child(0)
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return body


func _update_gold() -> void:
	if is_instance_valid(gold_chip):
		(gold_chip.find_child("Value", true, false) as Label).text = UI.fmt(Game.save.gold)
	if is_instance_valid(diamond_chip):
		(diamond_chip.find_child("Value", true, false) as Label).text = UI.fmt(Game.save.get("diamonds", 0))


func on_show() -> void:
	pass


func toast(text: String, color := UI.C_TEXT, icon_name := "") -> void:
	main.toast(text, color, icon_name)


## Abas. on_select(index).
func tabs(names: Array, current: int, on_select: Callable) -> HBoxContainer:
	var h := UI.hbox(6)
	for i in names.size():
		var idx := i
		var b := UI.button(names[i], func(): on_select.call(idx), 19, 56, "tab_on" if i == current else "tab")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h


## Linha "vazia" padrão para listas sem conteúdo.
func empty_note(text: String, icon_name := "sparkle") -> Control:
	var p := UI.card(false, true)
	var h := UI.hbox(10)
	h.add_child(UI.icon(icon_name, 36))
	h.add_child(UI.label(text, 20, UI.C_MUTED, true))
	p.add_child(h)
	return p


## Barra com "Todos" + os 9 tipos. Tocar num tipo filtra; tocar de novo volta para "Todos". cb(tipo ou "").
func type_filter_bar(current: String, cb: Callable) -> Control:
	var row := UI.hbox(4)
	var all := UI.button(Loc.t("Todos"), func(): cb.call(""), 16, 58, "tab_on" if current == "" else "tab")
	all.custom_minimum_size = Vector2(84, 58)
	row.add_child(all)
	for t in DataDB.type_ids:
		var tid: String = t
		var on := current == tid
		var b := UI.button("", func(): cb.call("" if on else tid), 16, 58, "tab_on" if on else "tab")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.tooltip_text = DataDB.type_name(tid)
		var ic := UI.icon("t_" + tid, 38)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4
		ic.offset_right = -4
		ic.offset_top = 6
		ic.offset_bottom = -6
		if current != "" and not on:
			ic.modulate = Color(1, 1, 1, 0.45)
		b.add_child(ic)
		if on:
			var sb := StyleBoxFlat.new()
			sb.bg_color = DataDB.type_color(tid).darkened(0.55)
			sb.border_color = DataDB.type_color(tid)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(6)
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, sb)
		row.add_child(b)
	return row
