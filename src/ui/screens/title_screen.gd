extends Screen


func build() -> void:
	var v := UI.vbox(24)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var art := UI.tex(HubArt.texture(), 360)
	art.custom_minimum_size = Vector2(720, 360)
	v.add_child(art)
	var t := UI.label("Bestiário Idle", 64, UI.C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("Caçadas automáticas · 135 monstros · Market online", 22, UI.C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for fid in ["agua_1_1", "fogo_1_1", "gelo_1_1", "planta_1_1", "terra_1_1", "eletrico_1_1", "vento_1_1", "luz_1_1", "sombra_1_1"]:
		row.add_child(UI.portrait(fid, false, 72))
	v.add_child(row)
	var b := UI.button("Jogar", _on_play, 34, 96)
	b.custom_minimum_size = Vector2(420, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	var st := UI.label("Servidor: %s" % ("mock local (sem credenciais Supabase)" if Backend.is_mock() else "Supabase"), 18, UI.C_MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var ver := UI.label("v%s%s" % [ProjectSettings.get_setting("application/config/version", "0.1"), " · DEBUG" if OS.is_debug_build() else ""], 16, UI.C_MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)


func _on_play() -> void:
	for ch in get_children():
		if ch is Control:
			ch.modulate.a = 0.6
	main.start_game()
