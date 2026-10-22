class_name NotifyCenter
extends Control
## Avisos rápidos centralizados no topo da tela, empilhados (máx. 3), com ícone e animação.

const MAX := 3
var stack: VBoxContainer


func _ready() -> void:
	name = "NotifyCenter"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stack.offset_top = 150
	stack.offset_left = 30
	stack.offset_right = -30
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)


func push(text: String, color := UI.C_TEXT, icon_name := "") -> void:
	while stack.get_child_count() >= MAX:
		var old := stack.get_child(0)
		stack.remove_child(old)
		old.queue_free()
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UI.panel("toast")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(10)
	if icon_name == "":
		icon_name = "check" if color == UI.C_GOOD else ("cross" if color == UI.C_BAD else "sparkle")
	h.add_child(UI.icon(icon_name, 32))
	var l := UI.label(text, 22, color, true)
	l.custom_minimum_size = Vector2(0, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	var w := minf(560.0, UI.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 8)
	l.custom_minimum_size.x = w
	h.add_child(l)
	p.add_child(h)
	holder.add_child(p)
	stack.add_child(holder)
	p.modulate.a = 0.0
	p.position.y = -20
	var tw := holder.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(holder.queue_free)
