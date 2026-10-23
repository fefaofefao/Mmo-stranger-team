extends Screen
## Tela inicial: cena noturna animada, logo, desfile de monstros, Jogar e idioma.

var walkers: Array = []   # [{rect: TextureRect, atlas: AtlasTexture, speed, x, phase}]
var t := 0.0


func build() -> void:
	walkers.clear()
	var bg := TextureRect.new()
	bg.texture = HubArt.title_texture()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_fireflies()
	# logo
	var logo := VBoxContainer.new()
	logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	logo.offset_top = 190
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", -26)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var l1 := _logo_label("Bestiário", 104, Color("#ffd65a"))
	logo.add_child(l1)
	var l2 := _logo_label("IDLE", 70, Color("#9fe0ff"))
	logo.add_child(l2)
	var sub := UI.label(Loc.t("Caçadas automáticas · 135 monstros · Market online"), 21, Color(1, 0.95, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.9))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	logo.add_child(gap)
	logo.add_child(sub)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", 8.0, 1.6).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", -8.0, 1.6).as_relative().set_trans(Tween.TRANS_SINE)
	# desfile dos iniciais na colina
	var vs := get_viewport_rect().size
	var starters := DataDB.starters()
	for i in starters.size():
		var fam: Dictionary = starters[i]
		_add_walker(fam.stages[0].form_id, i, starters.size(), vs, i == 4)
	# botões
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -270
	bottom.offset_bottom = -30
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	add_child(bottom)
	var b := UI.icon_button("play", Loc.t("Jogar"), _on_play, 40, 108, "primary")
	b.custom_minimum_size = Vector2(460, 108)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(b)
	b.pivot_offset = Vector2(230, 54)
	var pt := b.create_tween().set_loops()
	pt.tween_property(b, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	pt.tween_property(b, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	var lang := UI.hbox(8)
	lang.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(lang)
	for l in Loc.LANGS:
		var code: String = l
		var lb := UI.icon_button("globe" if Loc.locale == l else "", Loc.LANG_NAMES[l], func():
			Game.save.settings.locale = code
			Loc.set_locale(code)
			rebuild(), 18, 52, "tab_on" if Loc.locale == l else "tab")
		lb.custom_minimum_size = Vector2(176, 52)
		if Loc.locale != l:
			lb.icon = null
		lang.add_child(lb)
	var st := UI.label(Loc.t("Servidor: %s") % (Loc.t("local (modo de teste)") if Backend.is_mock() else "Supabase") + "  ·  v%s%s" % [ProjectSettings.get_setting("application/config/version", "0.1"), " · DEBUG" if OS.is_debug_build() else ""], 15, Color(1, 1, 1, 0.6))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(st)


func _logo_label(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 18)
	l.add_theme_color_override("font_outline_color", Color("#1a0e2a"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 8)
	l.add_theme_constant_override("shadow_outline_size", 18)
	return l


## Monstro andando pela colina (quadros de caminhada da própria spritesheet).
func _add_walker(form_id: String, i: int, n: int, vs: Vector2, shiny: bool) -> void:
	var sheet: Texture2D = SpriteFactory.sheet(form_id, shiny)
	var fw := sheet.get_width() / SpriteFactory.COLS
	var fh := sheet.get_height() / SpriteFactory.ROWS
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(2 * fw, SpriteFactory.DIR_RIGHT * fh, fw, fh)
	var r := TextureRect.new()
	r.texture = at
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var sz := 140.0
	r.size = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var ground := vs.y * 0.775 + (i % 2) * 10.0
	var spacing := (vs.x + 300.0) / n
	walkers.append({"rect": r, "atlas": at, "fw": fw, "fh": fh, "speed": 46.0 + (i % 3) * 6.0, "x": -150.0 + i * spacing,
		"y": ground - sz, "phase": randf(), "span": vs.x + 300.0})


func _process(delta: float) -> void:
	t += delta
	for w in walkers:
		if not is_instance_valid(w.rect):
			continue
		w.x += w.speed * delta
		if w.x > w.span - 150.0:
			w.x -= w.span
		var bob := absf(sin((t + w.phase) * 6.0)) * 6.0
		w.rect.position = Vector2(w.x, w.y - bob)
		var col := 2 + int((t + w.phase) * 7.0) % 3
		(w.atlas as AtlasTexture).region = Rect2(col * w.fw, SpriteFactory.DIR_RIGHT * w.fh, w.fw, w.fh)


func _fireflies() -> void:
	var p := CPUParticles2D.new()
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 5:
			var d := Vector2(x - 2, y - 2).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.2 - d * 0.45, 0, 1)))
	p.texture = ImageTexture.create_from_image(img)
	var vs := get_viewport_rect().size
	p.position = Vector2(vs.x * 0.5, vs.y * 0.62)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vs.x * 0.5, vs.y * 0.25)
	p.amount = 34
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.direction = Vector2.UP
	p.spread = 180
	p.initial_velocity_min = 4
	p.initial_velocity_max = 16
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.color = Color(0.85, 1.0, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.5, Color(1, 1, 1, 1))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)


func _on_play() -> void:
	main.start_game()
