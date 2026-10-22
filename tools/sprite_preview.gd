extends SceneTree
## Gera docs/sprites_preview.png com todas as 135 formas (linha = tipo) e docs/sprites_anim.png (quadros).
##   godot --headless --path . -s tools/sprite_preview.gd


func _initialize() -> void:
	DataDB.load_all()
	var cell := 112
	var out := Image.create(15 * cell, 9 * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color("#2a2a30"))
	for ti in DataDB.type_ids.size():
		var t: String = DataDB.type_ids[ti]
		var col := 0
		for f in DataDB.form_list:
			if f.type != t:
				continue
			var img := SpriteFactory._frame_image(f.form_id, false, SpriteFactory.DIR_DOWN, 0)
			img.resize(cell, cell, Image.INTERPOLATE_NEAREST)
			out.blend_rect(img, Rect2i(0, 0, cell, cell), Vector2i(col * cell, ti * cell))
			col += 1
	out.save_png("res://docs/sprites_preview.png")
	# animação de algumas formas: todas as direções e quadros
	var forms := ["fogo_1_1", "agua_1_2", "eletrico_1_3", "gelo_1_1", "terra_4_3", "sombra_2_2", "planta_2_3", "luz_1_3"]
	var a := Image.create(10 * 56 * 2, forms.size() * 2 * 56 * 2, false, Image.FORMAT_RGBA8)
	a.fill(Color("#2a2a30"))
	for i in forms.size():
		var sh := SpriteFactory.generate_sheet(forms[i], i == 3)
		for row in [0, 2]:
			var r := sh.get_region(Rect2i(0, row * 56, 560, 56))
			r.resize(1120, 112, Image.INTERPOLATE_NEAREST)
			a.blend_rect(r, Rect2i(0, 0, 1120, 112), Vector2i(0, (i * 2 + row / 2) * 112))
	a.save_png("res://docs/sprites_anim.png")
	print("ok")
	quit()
