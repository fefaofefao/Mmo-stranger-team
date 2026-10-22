class_name NotifyCenter
extends Control
## Avisos rápidos no centro da tela, empilhados (máx. 3), com ícone e animação.
## O posicionamento é calculado a cada quadro (sem containers), então fica centralizado
## em qualquer proporção de tela e com textos de qualquer largura.

const MAX := 3
const GAP := 10.0
const MAX_TEXT_W := 540.0
var toasts: Array = []   # [{panel, born}]


func _ready() -> void:
	name = "NotifyCenter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(text: String, color := UI.C_TEXT, icon_name := "") -> void:
	while toasts.size() >= MAX:
		var old: Dictionary = toasts.pop_front()
		if is_instance_valid(old.panel):
			old.panel.queue_free()
	var p := UI.panel("toast")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon_name == "":
		icon_name = "check" if color == UI.C_GOOD else ("cross" if color == UI.C_BAD else "sparkle")
	var ic := UI.icon(icon_name, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UI.label(text, 22, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = minf(MAX_TEXT_W, UI.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 6)
	h.add_child(l)
	p.add_child(h)
	add_child(p)
	p.modulate.a = 0.0
	p.scale = Vector2(0.92, 0.92)
	toasts.append({"panel": p})
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.16)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(p, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(_drop.bind(p))
	_layout()


func _drop(p: Control) -> void:
	for i in toasts.size():
		if toasts[i].panel == p:
			toasts.remove_at(i)
			break
	if is_instance_valid(p):
		p.queue_free()


func _process(_d: float) -> void:
	if not toasts.is_empty():
		_layout()


## Pilha centralizada na horizontal e na vertical (o mais novo embaixo).
func _layout() -> void:
	var sizes: Array = []
	var total := 0.0
	for t in toasts:
		var s: Vector2 = t.panel.get_combined_minimum_size()
		sizes.append(s)
		total += s.y
	total += GAP * maxf(0.0, toasts.size() - 1)
	var area := get_viewport_rect().size
	var y := (area.y - total) * 0.5
	for i in toasts.size():
		var p: Control = toasts[i].panel
		var s: Vector2 = sizes[i]
		p.size = s
		p.pivot_offset = s * 0.5
		p.global_position = Vector2(roundf((area.x - s.x) * 0.5), roundf(y))
		y += s.y + GAP
