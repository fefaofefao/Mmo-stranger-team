class_name UI
extends RefCounted
## Fábrica de widgets e tema (visual "pedra e couro" pixelado, inspirado em UIs clássicas de MMO).

const C_BG := Color("#1b1a1f")
const C_PANEL := Color("#2c2924")
const C_PANEL_LIGHT := Color("#3b362e")
const C_BORDER := Color("#6e5f45")
const C_GOLD := Color("#f2c95a")
const C_TEXT := Color("#ece4d4")
const C_MUTED := Color("#a59b88")
const C_GOOD := Color("#7be07b")
const C_BAD := Color("#ff6b5a")

static var _theme: Theme
static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	return _font


static func sb(bg: Color, border: Color, bw := 3, radius := 2, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = false
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 24
	t.set_color("font_color", "Label", C_TEXT)
	t.set_stylebox("normal", "Button", sb(Color("#4a3f33"), Color("#9a8458")))
	t.set_stylebox("hover", "Button", sb(Color("#5a4d3e"), Color("#c2a86e")))
	t.set_stylebox("pressed", "Button", sb(Color("#332b23"), Color("#c2a86e")))
	t.set_stylebox("disabled", "Button", sb(Color("#2e2a26"), Color("#4d453a")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", C_GOLD)
	t.set_color("font_disabled_color", "Button", Color("#6d665c"))
	t.set_stylebox("panel", "PanelContainer", sb(C_PANEL, C_BORDER, 3, 2, 12))
	t.set_stylebox("panel", "Panel", sb(C_PANEL, C_BORDER, 3, 2, 12))
	t.set_stylebox("normal", "LineEdit", sb(Color("#141312"), C_BORDER, 2, 2, 10))
	t.set_stylebox("focus", "LineEdit", sb(Color("#141312"), C_GOLD, 2, 2, 10))
	t.set_color("font_color", "LineEdit", C_TEXT)
	var grabber := sb(Color("#8a7a5a"), Color("#8a7a5a"), 0, 3, 0)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", sb(Color("#141312"), Color("#141312"), 0, 3, 4))
	t.set_stylebox("normal", "OptionButton", sb(Color("#4a3f33"), Color("#9a8458")))
	t.set_stylebox("hover", "OptionButton", sb(Color("#5a4d3e"), Color("#c2a86e")))
	t.set_stylebox("pressed", "OptionButton", sb(Color("#332b23"), Color("#c2a86e")))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", sb(C_PANEL, C_BORDER))
	t.set_font_size("font_size", "PopupMenu", 24)
	t.set_stylebox("background", "ProgressBar", sb(Color("#141312"), Color("#000000"), 1, 1, 0))
	t.set_stylebox("fill", "ProgressBar", sb(C_GOOD, C_GOOD, 0, 1, 0))
	t.set_font_size("font_size", "ProgressBar", 14)
	_theme = t
	return t


static func label(text: String, size := 24, color := C_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4 if size >= 22 else 3)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	var l := label(text, 32, C_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, cb: Callable = Callable(), size := 24, min_h := 64.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func small_button(text: String, cb: Callable = Callable()) -> Button:
	return button(text, cb, 20, 52.0)


static func panel(bg := C_PANEL, border := C_BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, 3, 2, 12))
	return p


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func grid(cols: int, sep := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func margin(child: Control, m := 16) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


## Retorna [ScrollContainer, VBoxContainer interno]
static func scroll(sep := 8) -> Array:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	return [s, v]


static func tex(t: Texture2D, size := 64.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


static func portrait(form_id: String, shiny := false, size := 64.0) -> TextureRect:
	return tex(SpriteFactory.portrait(form_id, shiny), size)


static func bar(ratio: float, color: Color, w := 200.0, h := 14.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 1
	p.step = 0.001
	p.value = ratio
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, h)
	p.add_theme_stylebox_override("fill", sb(color, color, 0, 1, 0))
	return p


static func type_badge(type_id: String, size := 18) -> Label:
	var l := label(" " + DataDB.type_name(type_id) + " ", size, DataDB.type_color(type_id).lightened(0.25))
	return l


static func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func clear(node: Node) -> void:
	for ch in node.get_children():
		ch.queue_free()


static func fmt(n: float) -> String:
	var v := int(n)
	if v >= 1000000000:
		return "%.2fB" % (v / 1e9)
	if v >= 1000000:
		return "%.2fM" % (v / 1e6)
	if v >= 10000:
		return "%.1fk" % (v / 1e3)
	return str(v)


static func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s


static func dialog(parent: Node, p_title: String, text: String, buttons: Array) -> UIDialog:
	var d := UIDialog.new()
	parent.add_child(d)
	d.build(p_title, text, buttons)
	return d


static func toast(parent: Node, text: String, color := C_TEXT) -> void:
	if parent == null:
		return
	var p := panel(Color(0.08, 0.07, 0.06, 0.92), C_BORDER)
	var l := label(text, 22, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position = Vector2(40, 160)
	p.size = Vector2(640, 0)
	p.custom_minimum_size = Vector2(640, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
