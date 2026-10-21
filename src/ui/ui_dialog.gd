class_name UIDialog
extends Control
## Diálogo modal simples. `var i = await dialog.chosen` retorna o índice do botão (-1 = fechado).

signal chosen(index: int)

var content: VBoxContainer
var line_edit: LineEdit


func build(p_title: String, text: String, buttons: Array, with_input := false, input_default := "") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	content = UI.vbox(14)
	p.add_child(content)
	content.add_child(UI.title(p_title))
	if text != "":
		var l := UI.label(text, 23, UI.C_TEXT, true)
		l.custom_minimum_size = Vector2(580, 0)
		content.add_child(l)
	if with_input:
		line_edit = LineEdit.new()
		line_edit.text = input_default
		line_edit.custom_minimum_size = Vector2(0, 60)
		line_edit.add_theme_font_size_override("font_size", 26)
		line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		content.add_child(line_edit)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	for i in buttons.size():
		var idx := i
		var b := UI.button(buttons[i], func(): _choose(idx))
		b.custom_minimum_size = Vector2(170, 64)
		row.add_child(b)


func _choose(i: int) -> void:
	chosen.emit(i)
	queue_free()


func value() -> String:
	return line_edit.text if line_edit else ""


static func ask_number(parent: Node, p_title: String, text: String, default_value: int) -> int:
	var d := UIDialog.new()
	parent.add_child(d)
	d.build(p_title, text, ["OK", "Cancelar"], true, str(default_value))
	var holder := [d.line_edit]
	var i: int = await d.chosen
	if i != 0:
		return -1
	var v: String = holder[0].text.strip_edges()
	if not v.is_valid_int():
		return -1
	return int(v)


static func confirm(parent: Node, p_title: String, text: String, yes := "Sim", no := "Não") -> bool:
	var d := UIDialog.new()
	parent.add_child(d)
	d.build(p_title, text, [yes, no])
	var i: int = await d.chosen
	return i == 0
