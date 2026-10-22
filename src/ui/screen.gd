class_name Screen
extends Control
## Base das telas de menu: cabeçalho padrão (voltar, ícone + título, ouro e Essência) e corpo.

var main  # Main
var params: Dictionary = {}
var body: VBoxContainer
var gold_chip: PanelContainer


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
	gold_chip = UI.chip("coin", "", UI.C_GOLD, 22)
	gold_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(gold_chip)
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
