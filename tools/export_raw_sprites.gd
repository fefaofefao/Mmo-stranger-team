extends SceneTree
## Exporta as spritesheets "cruas" (sem contorno) de todas as formas para o acabamento em Python:
##   godot --headless --path . -s tools/export_raw_sprites.gd -- <pasta_saida>
##   python3 tools/shade_sprites.py <pasta_saida>
## O resultado final vai para res://assets/sprites/monsters/<form_id>.png e <form_id>_shiny.png.


func _initialize() -> void:
	DataDB.load_all()
	var out := "/tmp/raw_sprites"
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	SpriteFactory.raw_mode = true
	var only := OS.get_environment("ONLY_FORMS")
	var n := 0
	for f in DataDB.form_list:
		if only != "" and not (f.form_id in only.split(",")):
			continue
		for shiny in [false, true]:
			var img := SpriteFactory.generate_sheet(f.form_id, shiny)
			img.save_png("%s/%s%s.png" % [out, f.form_id, "_shiny" if shiny else ""])
			n += 1
	SpriteFactory.raw_mode = false
	print("exportadas: ", n)
	quit()
