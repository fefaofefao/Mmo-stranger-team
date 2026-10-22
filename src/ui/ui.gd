class_name UI
extends RefCounted
## Kit visual do jogo: molduras pixel art com relevo (9-patch gerado por código), botões com variantes,
## ícones, chips, barras, cards e diálogos. Todas as telas usam este kit para manter a identidade visual.

const C_BG := Color("#17151a")
const C_PANEL := Color("#2a2520")
const C_BORDER := Color("#6e5b3c")
const C_GOLD := Color("#f6cf5a")
const C_TEXT := Color("#efe6d2")
const C_MUTED := Color("#a89d88")
const C_GOOD := Color("#7be07b")
const C_BAD := Color("#ff7a66")
const C_INFO := Color("#8fc8ff")
const C_PURPLE := Color("#c99bff")

static var _theme: Theme
static var _font: Font
static var _styles := {}
static var _bg_tex: Texture2D


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf")
	return _font


# ------------------------------------------------------------------ molduras 9-patch

## Gera uma moldura pixel art 12x(12+sombra) ampliada 2x: contorno escuro, borda com luz/sombra e
## preenchimento em degradê.
static func _frame_img(fill_a: Color, fill_b: Color, border: Color, outer: Color, shadow := 0, inset := false) -> Image:
	var n := 12
	var h := n + shadow
	var img := Image.create(n, h, false, Image.FORMAT_RGBA8)
	var hi := border.lightened(0.28)
	var lo := border.darkened(0.3)
	if inset:
		var t := hi
		hi = lo
		lo = t
	for y in h:
		for x in n:
			var corner := (x == 0 or x == n - 1) and (y == 0 or y == h - 1)
			if corner:
				continue
			var c: Color
			if x == 0 or x == n - 1 or y == 0 or y == h - 1:
				c = outer
			elif shadow > 0 and y >= h - 1 - shadow:
				c = fill_b.darkened(0.55)
			elif x == 1 or y == 1:
				c = hi
			elif x == n - 2 or y == h - 2 - shadow:
				c = lo
			else:
				c = fill_a.lerp(fill_b, float(y) / float(h - shadow))
			img.set_pixel(x, y, c)
	img.resize(n * 2, h * 2, Image.INTERPOLATE_NEAREST)
	return img


static func _sbt(img: Image, shadow := 0, pad := 10.0, pad_v := 6.0, push := 0.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_margin_left = 6
	s.texture_margin_right = 6
	s.texture_margin_top = 6
	s.texture_margin_bottom = 6 + shadow * 2
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad_v + push
	s.content_margin_bottom = pad_v + shadow * 2 - push
	return s


## Estilos nomeados (cacheados).
static func style(name: String) -> StyleBox:
	if _styles.has(name):
		return _styles[name]
	var s: StyleBox
	var outer := Color("#120e0b")
	match name:
		"panel":
			s = _sbt(_frame_img(Color("#302a23"), Color("#26211b"), C_BORDER, outer), 0, 14, 12)
		"panel_gold":
			s = _sbt(_frame_img(Color("#3a3024"), Color("#2c251c"), Color("#c9a050"), outer), 0, 14, 12)
		"card":
			s = _sbt(_frame_img(Color("#28231e"), Color("#211d18"), Color("#54472f"), outer), 0, 12, 10)
		"card_hi":
			s = _sbt(_frame_img(Color("#3a3226"), Color("#2e271e"), Color("#d2aa55"), outer), 0, 12, 10)
		"card_dim":
			s = _sbt(_frame_img(Color("#1f1c19"), Color("#1a1815"), Color("#3c352b"), outer), 0, 12, 10)
		"inset":
			s = _sbt(_frame_img(Color("#141210"), Color("#1a1714"), Color("#4a3e2c"), outer, 0, true), 0, 10, 8)
		"header":
			s = _sbt(_frame_img(Color("#251f19"), Color("#1a1612"), Color("#8a7042"), outer), 0, 12, 8)
		"hud":
			s = _sbt(_frame_img(Color(0.12, 0.1, 0.08, 0.94), Color(0.09, 0.08, 0.07, 0.94), Color("#6e5b3c"), outer), 0, 10, 8)
		"btn":
			s = _sbt(_frame_img(Color("#62513d"), Color("#4b3e2f"), Color("#b0925a"), outer, 2), 2)
		"btn_hover":
			s = _sbt(_frame_img(Color("#6e5b45"), Color("#564736"), Color("#d2b070"), outer, 2), 2)
		"btn_pressed":
			s = _sbt(_frame_img(Color("#3e3328"), Color("#4b3e2f"), Color("#d2b070"), outer, 0, true), 0, 10, 6, 2)
		"btn_disabled":
			s = _sbt(_frame_img(Color("#3a3632"), Color("#302c28"), Color("#5a5248"), outer, 2), 2)
		"primary":
			s = _sbt(_frame_img(Color("#f2c75a"), Color("#c9952e"), Color("#fff0b4"), outer, 2), 2)
		"primary_hover":
			s = _sbt(_frame_img(Color("#ffd774"), Color("#d8a43a"), Color("#fff6d0"), outer, 2), 2)
		"primary_pressed":
			s = _sbt(_frame_img(Color("#b8862a"), Color("#c9952e"), Color("#fff0b4"), outer, 0, true), 0, 10, 6, 2)
		"danger":
			s = _sbt(_frame_img(Color("#c4563e"), Color("#963322"), Color("#ffb4a0"), outer, 2), 2)
		"danger_pressed":
			s = _sbt(_frame_img(Color("#7e2a1c"), Color("#963322"), Color("#ffb4a0"), outer, 0, true), 0, 10, 6, 2)
		"ad":
			s = _sbt(_frame_img(Color("#5cbf5a"), Color("#2f8a3a"), Color("#c8ffc0"), outer, 2), 2)
		"ad_pressed":
			s = _sbt(_frame_img(Color("#25702f"), Color("#2f8a3a"), Color("#c8ffc0"), outer, 0, true), 0, 10, 6, 2)
		"tab":
			s = _sbt(_frame_img(Color("#3a3128"), Color("#2e271f"), Color("#7a6644"), outer, 2), 2, 8, 4)
		"tab_on":
			s = _sbt(_frame_img(Color("#7a6238"), Color("#5c4a2c"), Color("#ffe08a"), outer, 2), 2, 8, 4)
		"chip":
			s = _sbt(_frame_img(Color("#1c1915"), Color("#16130f"), Color("#5a4a30"), outer), 0, 8, 2)
		"bar_bg":
			var b := StyleBoxFlat.new()
			b.bg_color = Color("#0e0c0a")
			b.border_color = Color("#000000")
			b.set_border_width_all(2)
			b.anti_aliasing = false
			s = b
		"toast":
			s = _sbt(_frame_img(Color(0.16, 0.13, 0.1, 0.97), Color(0.11, 0.09, 0.07, 0.97), Color("#c9a050"), outer), 0, 14, 10)
		_:
			s = StyleBoxEmpty.new()
	_styles[name] = s
	return s


static func bg_texture() -> Texture2D:
	if _bg_tex:
		return _bg_tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 32:
		for x in 32:
			var c := C_BG
			var r := rng.randf()
			if r < 0.08:
				c = C_BG.lightened(0.04)
			elif r < 0.14:
				c = C_BG.darkened(0.15)
			img.set_pixel(x, y, c)
	img.resize(64, 64, Image.INTERPOLATE_NEAREST)
	_bg_tex = ImageTexture.create_from_image(img)
	return _bg_tex


static func background() -> TextureRect:
	var t := TextureRect.new()
	t.texture = bg_texture()
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 24
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("normal", "Button", style("btn"))
	t.set_stylebox("hover", "Button", style("btn_hover"))
	t.set_stylebox("pressed", "Button", style("btn_pressed"))
	t.set_stylebox("disabled", "Button", style("btn_disabled"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", C_GOLD)
	t.set_color("font_disabled_color", "Button", Color("#7a7268"))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Button", 4)
	t.set_constant("h_separation", "Button", 8)
	t.set_stylebox("panel", "PanelContainer", style("panel"))
	t.set_stylebox("panel", "Panel", style("panel"))
	t.set_stylebox("normal", "LineEdit", style("inset"))
	t.set_stylebox("focus", "LineEdit", style("inset"))
	t.set_color("font_color", "LineEdit", C_TEXT)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#8a7a5a")
	grabber.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.25)
	sbg.content_margin_left = 3
	sbg.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sbg)
	for st in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(st, "OptionButton", style({"normal": "btn", "hover": "btn_hover", "pressed": "btn_pressed", "focus": "btn"}[st]))
	t.set_stylebox("panel", "PopupMenu", style("panel"))
	t.set_font_size("font_size", "PopupMenu", 24)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_stylebox("background", "ProgressBar", style("bar_bg"))
	t.set_font_size("font_size", "ProgressBar", 14)
	_theme = t
	return t


# ------------------------------------------------------------------ textos

static func label(text: String, size := 24, color := C_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4 if size >= 22 else 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 40
	return l


static func title(text: String, size := 32) -> Label:
	var l := label(text, size, C_GOLD)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func section(text: String, icon_name := "") -> Control:
	var h := hbox(8)
	if icon_name != "":
		h.add_child(icon(icon_name, 28))
	var l := label(text, 24, C_GOLD)
	h.add_child(l)
	var line := ColorRect.new()
	line.color = Color("#5a4a30")
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(line)
	return h


# ------------------------------------------------------------------ botões

static func button(text: String, cb: Callable = Callable(), size := 24, min_h := 68.0, variant := "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.clip_text = true
	if variant != "":
		set_variant(b, variant)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func set_variant(b: Button, variant: String) -> void:
	match variant:
		"primary":
			b.add_theme_stylebox_override("normal", style("primary"))
			b.add_theme_stylebox_override("hover", style("primary_hover"))
			b.add_theme_stylebox_override("pressed", style("primary_pressed"))
			b.add_theme_color_override("font_color", Color("#2a1a08"))
			b.add_theme_color_override("font_hover_color", Color("#1a1006"))
			b.add_theme_color_override("font_pressed_color", Color("#2a1a08"))
			b.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75, 0.6))
			b.add_theme_constant_override("outline_size", 2)
		"danger":
			b.add_theme_stylebox_override("normal", style("danger"))
			b.add_theme_stylebox_override("hover", style("danger"))
			b.add_theme_stylebox_override("pressed", style("danger_pressed"))
		"ad":
			b.add_theme_stylebox_override("normal", style("ad"))
			b.add_theme_stylebox_override("hover", style("ad"))
			b.add_theme_stylebox_override("pressed", style("ad_pressed"))
		"tab":
			b.add_theme_stylebox_override("normal", style("tab"))
			b.add_theme_stylebox_override("hover", style("tab"))
			b.add_theme_stylebox_override("pressed", style("tab_on"))
		"tab_on":
			b.add_theme_stylebox_override("normal", style("tab_on"))
			b.add_theme_stylebox_override("hover", style("tab_on"))
			b.add_theme_stylebox_override("pressed", style("tab_on"))
			b.add_theme_color_override("font_color", Color("#fff3c8"))


static func small_button(text: String, cb: Callable = Callable(), variant := "") -> Button:
	return button(text, cb, 20, 56.0, variant)


static func icon_button(icon_name: String, text: String, cb: Callable = Callable(), size := 22, min_h := 68.0, variant := "") -> Button:
	var b := button(text, cb, size, min_h, variant)
	b.icon = Icons.tex(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 32)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b


## Botão-ícone grande com legenda embaixo (Hub, barra de navegação).
static func tile_button(icon_name: String, text: String, cb: Callable, icon_px := 48, min_size := Vector2(200, 140), variant := "", badge := "") -> Button:
	var b := button("", cb, 20, min_size.y, variant)
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(icon_name, icon_px)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := label(text, 20 if min_size.y >= 110 else 17, Color("#2a1a08") if variant == "primary" else C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if variant == "primary":
		l.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75, 0.5))
	v.add_child(l)
	b.add_child(v)
	if badge != "":
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", style("chip"))
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bl := label(badge, 16, C_GOLD)
		bp.add_child(bl)
		bp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		bp.position = Vector2(-6, 6)
		bp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.add_child(bp)
	return b


# ------------------------------------------------------------------ contêineres

static func panel(kind := "panel") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(kind))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func card(highlight := false, dim := false) -> PanelContainer:
	return panel("card_hi" if highlight else ("card_dim" if dim else "card"))


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


static func grid(cols: int, sep := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	return g


static func margin(child: Control, m := 16) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.mouse_filter = Control.MOUSE_FILTER_PASS
	mc.add_child(child)
	return mc


## Retorna [ScrollContainer, VBoxContainer interno]. A rolagem por toque funciona sobre cards e botões.
static func scroll(sep := 8) -> Array:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 12
	var v := vbox(sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	return [s, v]


## Deixa o toque "atravessar" controles para o ScrollContainer conseguir arrastar.
static func touch_friendly(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c is ScrollBar) and not (c is LineEdit) and not (c is OptionButton):
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
		touch_friendly(c)


static func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hspace() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func clear(node: Node) -> void:
	for ch in node.get_children():
		ch.queue_free()


# ------------------------------------------------------------------ imagens, ícones, chips, barras

static func tex(t: Texture2D, size := 64.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func icon(name: String, size := 36.0) -> TextureRect:
	return tex(Icons.tex(name), size)


static func portrait(form_id: String, shiny := false, size := 64.0) -> TextureRect:
	return tex(SpriteFactory.portrait(form_id, shiny), size)


## Retrato dentro de uma moldura com fundo da cor do tipo.
static func portrait_frame(form_id: String, shiny := false, size := 72.0, seen := true) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var tc := DataDB.type_color(DataDB.form(form_id).get("type", "agua"))
	sb.bg_color = tc.darkened(0.72) if seen else Color("#141210")
	sb.border_color = Color(1, 0.85, 0.35) if shiny else tc.darkened(0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pr := portrait(form_id, shiny, size)
	if not seen:
		pr.modulate = Color(0, 0, 0, 0.85)
	p.add_child(pr)
	return p


## Chip: [ícone] valor
static func chip(icon_name: String, text: String, color := C_TEXT, size := 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style("chip"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := hbox(4)
	if icon_name != "":
		h.add_child(icon(icon_name, size + 4))
	var l := label(text, size, color)
	l.name = "Value"
	h.add_child(l)
	p.add_child(h)
	return p


## Etiqueta colorida (tipo, raridade, estado).
static func pill(text: String, color: Color, size := 17) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.62)
	sb.border_color = color.darkened(0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, size, color.lightened(0.35))
	l.add_theme_constant_override("outline_size", 3)
	p.add_child(l)
	return p


static func type_badge(type_id: String, size := 17) -> PanelContainer:
	return pill(DataDB.type_name(type_id), DataDB.type_color(type_id), size)


static func rarity_badge(rarity_id: String, size := 17) -> PanelContainer:
	return pill(DataDB.rarity_name(rarity_id), DataDB.rarity_color(rarity_id), size)


static func quality_badge(m: Dictionary, size := 17) -> PanelContainer:
	return pill(MonsterLogic.quality_text(m), MonsterLogic.quality_color(m), size)


static func bar(ratio: float, color: Color, w := 200.0, h := 14.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 1
	p.step = 0.001
	p.value = ratio
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.border_color = color.lightened(0.35)
	fill.border_width_top = 2
	fill.anti_aliasing = false
	p.add_theme_stylebox_override("fill", fill)
	return p


static func stars(n: int, size := 26.0) -> HBoxContainer:
	var h := hbox(2)
	for i in 5:
		h.add_child(icon("star" if i < n else "star_empty", size))
	return h


# ------------------------------------------------------------------ formatação

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


# ------------------------------------------------------------------ diálogos e avisos

static func dialog(parent: Node, p_title: String, text: String, buttons: Array, icon_name := "") -> UIDialog:
	var d := UIDialog.new()
	parent.add_child(d)
	d.build(p_title, text, buttons, false, "", icon_name)
	return d


static func toast(parent: Node, text: String, color := C_TEXT, icon_name := "") -> void:
	if parent == null:
		return
	var nc = parent.get_node_or_null("NotifyCenter")
	if nc:
		nc.push(text, color, icon_name)
