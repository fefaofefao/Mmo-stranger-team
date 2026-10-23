class_name Tutorial
extends Control
## Tutorial do começo do jogo: escurece a tela, destaca uma área (moldura dourada) e explica em
## passos curtos. `await tutorial.finished`. Steps: [{title, text, icon, target: Control ou null}].

signal finished

var steps: Array = []
var idx := 0
var shades: Array = []
var frame: Panel
var card: PanelContainer
var title_l: Label
var text_l: Label
var icon_r: TextureRect
var dots: Label
var next_b: Button


static func run(parent: Node, p_steps: Array) -> Tutorial:
	var t := Tutorial.new()
	parent.add_child(t)
	t.steps = p_steps
	t._build()
	t._show(0)
	return t


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 4:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 0.66)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		shades.append(r)
	frame = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color("#f4c542")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	card = UI.panel("panel_gold")
	card.custom_minimum_size = Vector2(640, 0)
	add_child(card)
	var v := UI.vbox(10)
	card.add_child(v)
	var h := UI.hbox(10)
	v.add_child(h)
	icon_r = UI.icon("sparkle", 44)
	h.add_child(icon_r)
	title_l = UI.title("", 26)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title_l)
	dots = UI.label("", 16, UI.C_MUTED)
	h.add_child(dots)
	text_l = UI.label("", 21, UI.C_TEXT, true)
	text_l.custom_minimum_size = Vector2(600, 0)
	v.add_child(text_l)
	var row := UI.hbox(10)
	v.add_child(row)
	var skip := UI.button(Loc.t("Pular"), _finish, 19, 60)
	skip.custom_minimum_size = Vector2(170, 60)
	row.add_child(skip)
	row.add_child(UI.hspace())
	next_b = UI.button(Loc.t("Próximo"), func(): _show(idx + 1), 21, 60, "primary")
	next_b.custom_minimum_size = Vector2(220, 60)
	row.add_child(next_b)


func _show(i: int) -> void:
	if i >= steps.size():
		_finish()
		return
	idx = i
	var s: Dictionary = steps[i]
	title_l.text = s.title
	text_l.text = s.text
	icon_r.texture = Icons.tex(s.get("icon", "sparkle"))
	dots.text = "%d/%d" % [i + 1, steps.size()]
	next_b.text = Loc.t("Começar!") if i == steps.size() - 1 else Loc.t("Próximo")
	_layout.call_deferred()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var s: Dictionary = steps[idx]
	var tgt = s.get("target")
	var r := Rect2(vs.x * 0.5, vs.y * 0.5, 0, 0)
	if tgt is Control and is_instance_valid(tgt) and tgt.is_visible_in_tree():
		r = (tgt as Control).get_global_rect().grow(6)
	frame.visible = r.size.x > 0
	frame.position = r.position
	frame.size = r.size
	# 4 faixas escuras em volta do destaque
	shades[0].position = Vector2.ZERO
	shades[0].size = Vector2(vs.x, maxf(0, r.position.y))
	shades[1].position = Vector2(0, r.end.y)
	shades[1].size = Vector2(vs.x, maxf(0, vs.y - r.end.y))
	shades[2].position = Vector2(0, r.position.y)
	shades[2].size = Vector2(maxf(0, r.position.x), r.size.y)
	shades[3].position = Vector2(r.end.x, r.position.y)
	shades[3].size = Vector2(maxf(0, vs.x - r.end.x), r.size.y)
	# cartão longe do destaque
	var cs := card.get_combined_minimum_size()
	card.size = cs
	var y := vs.y * 0.5 - cs.y * 0.5
	if r.size.x > 0:
		y = r.end.y + 16 if r.get_center().y < vs.y * 0.5 else r.position.y - cs.y - 16
	card.position = Vector2((vs.x - cs.x) * 0.5, clampf(y, 16, vs.y - cs.y - 16))


func _finish() -> void:
	finished.emit()
	queue_free()
