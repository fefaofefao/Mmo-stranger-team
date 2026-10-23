extends SceneTree
## Prévia dos mapas: renderiza um trecho de cada bioma em docs/maps_preview.png (precisa de display):
##   xvfb-run -s "-screen 0 1280x1400x24" godot --path . --rendering-driver opengl3 -s tools/map_preview.gd [-- bioma1,bioma2]

var G


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	G = root.get_node("Game")
	G.load_local()
	var biomes: Array = DataDB.biomes.keys()
	for a in OS.get_cmdline_user_args():
		biomes = Array(a.split(","))
	var cell := 360
	var cols := 4
	var rows := int(ceil(biomes.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	for i in biomes.size():
		for ch in vp.get_children():
			ch.queue_free()
		await process_frame
		var world = load("res://src/world/hunt_world.gd").new()
		vp.add_child(world)
		var h: Dictionary = DataDB.hunt_list[0].duplicate(true)
		h.biome = biomes[i]
		h.seed = 1234 + i
		world.setup_hunt(h)
		world.camera.zoom = Vector2(1.2, 1.2)
		for k in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, cell, cell), Vector2i((i % cols) * cell, (i / cols) * cell))
		print("bioma ", biomes[i])
	sheet.save_png("res://docs/maps_preview.png")
	quit()
