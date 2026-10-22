extends Screen


func build() -> void:
	var v := UI.vbox(22)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var art := UI.tex(HubArt.texture(), 360)
	art.custom_minimum_size = Vector2(720, 360)
	v.add_child(art)
	var t := UI.title("Bestiário Idle", 66)
	v.add_child(t)
	var sub := UI.label(Loc.t("Caçadas automáticas · 135 monstros · Market online"), 22, UI.C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for fam in DataDB.starters():
		row.add_child(UI.portrait(fam.stages[0].form_id, false, 70))
	v.add_child(row)
	var b := UI.icon_button("play", Loc.t("Jogar"), _on_play, 36, 100, "primary")
	b.custom_minimum_size = Vector2(440, 100)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var lang := UI.hbox(8)
	lang.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(lang)
	for l in Loc.LANGS:
		var code: String = l
		var lb := UI.small_button(Loc.LANG_NAMES[l], func():
			Game.save.settings.locale = code
			Loc.set_locale(code)
			rebuild(), "tab_on" if Loc.locale == l else "tab")
		lb.custom_minimum_size = Vector2(170, 52)
		lang.add_child(lb)
	var st := UI.label(Loc.t("Servidor: %s") % (Loc.t("local (modo de teste)") if Backend.is_mock() else "Supabase"), 17, UI.C_MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var ver := UI.label("v%s%s" % [ProjectSettings.get_setting("application/config/version", "0.1"), " · DEBUG" if OS.is_debug_build() else ""], 16, UI.C_MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)


func _on_play() -> void:
	for ch in get_children():
		if ch is Control and not ch is TextureRect:
			ch.modulate.a = 0.6
	main.start_game()
