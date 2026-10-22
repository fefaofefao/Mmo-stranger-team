class_name UIDialog
extends Control
## Diálogo modal. `var i = await dialog.chosen` retorna o índice do botão (-1 = fechado).
## O primeiro botão é o principal (destacado).

signal chosen(index: int)

var content: VBoxContainer
var line_edit: LineEdit


func build(p_title: String, text: String, buttons: Array, with_input := false, input_default := "", icon_name := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UI.panel("panel_gold")
	p.custom_minimum_size = Vector2(640, 0)
	center.add_child(p)
	content = UI.vbox(16)
	p.add_child(content)
	var head := UI.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon_name != "":
		head.add_child(UI.icon(icon_name, 40))
	head.add_child(UI.title(p_title, 30))
	content.add_child(head)
	if text != "":
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var l := UI.label(text, 23, UI.C_TEXT, true)
		l.custom_minimum_size = Vector2(600, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sc.add_child(l)
		content.add_child(sc)
		sc.custom_minimum_size = Vector2(600, minf(700.0, _text_height(text) + 10))
	if with_input:
		line_edit = LineEdit.new()
		line_edit.text = input_default
		line_edit.custom_minimum_size = Vector2(0, 64)
		line_edit.add_theme_font_size_override("font_size", 28)
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		content.add_child(line_edit)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	for i in buttons.size():
		var idx := i
		var b := UI.button(buttons[i], func(): _choose(idx), 24, 72, "primary" if i == 0 and buttons.size() > 1 else "")
		b.custom_minimum_size = Vector2(190, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


func _text_height(text: String) -> float:
	var lines := 0.0
	for part in text.split("\n"):
		lines += maxf(1.0, ceil(UI.font().get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x / 590.0))
	return lines * 31.0


func _choose(i: int) -> void:
	chosen.emit(i)
	queue_free()


func value() -> String:
	return line_edit.text if line_edit else ""


static func ask_number(parent: Node, p_title: String, text: String, default_value: int) -> int:
	var d := UIDialog.new()
	parent.add_child(d)
	d.build(p_title, text, [Loc.t("OK"), Loc.t("Cancelar")], true, str(default_value))
	var holder := [d.line_edit]
	var i: int = await d.chosen
	if i != 0:
		return -1
	var v: String = holder[0].text.strip_edges()
	if not v.is_valid_int():
		return -1
	return int(v)


static func confirm(parent: Node, p_title: String, text: String, yes := "", no := "") -> bool:
	var d := UIDialog.new()
	parent.add_child(d)
	d.build(p_title, text, [yes if yes != "" else Loc.t("Sim"), no if no != "" else Loc.t("Não")])
	var i: int = await d.chosen
	return i == 0
