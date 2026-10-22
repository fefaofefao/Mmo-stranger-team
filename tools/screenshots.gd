extends SceneTree
## Captura screenshots das telas principais (precisa de display; use xvfb-run em servidores):
##   xvfb-run -s "-screen 0 1280x1400x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 -s tools/screenshots.gd
## Salva em docs/screenshots/. Usa um perfil limpo (apaga o save local!).

var main
var G
var B
var n := 0


func _initialize() -> void:
	for f in ["user://save.json", "user://mock_server.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	_run.call_deferred()


func frames(k: int) -> void:
	for i in k:
		await process_frame


func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
	n += 1
	var suffix := "" if Loc.locale == "pt_BR" else "_" + Loc.locale
	img.save_png("res://docs/screenshots/%02d_%s%s.png" % [n, name, suffix])
	print("screenshot ", name)


func _run() -> void:
	G = root.get_node("Game")
	B = root.get_node("Backend")
	G.load_local()
	G.save.settings.consent_answered = true
	var lang := "pt_BR"
	for a in OS.get_cmdline_user_args():
		if a in ["pt_BR", "en", "es"]:
			lang = a
	G.save.settings.locale = lang
	Loc.set_locale(lang)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(10)
	await shot("titulo")
	await G.start_session()
	main.goto("starter", {}, false)
	await frames(2)
	main.current.selected = "fogo_1"
	main.current.rebuild()
	await shot("escolha_inicial")
	await G.choose_starter("fogo_1")
	G.save.settings.zoom = 2.0
	main.goto("hunt")
	var hs = main.hunt_screen
	G.time_scale = 3.0
	await frames(400)
	G.time_scale = 1.0
	await shot("hunt_mapa")
	await G.debug_set_level(40)
	await B.request("debug_force", {"recruit": 2})
	await G.set_current_hunt("w1_s3_fogo_2")
	G.save.debug_unlock_all = true
	hs.load_current_hunt()
	G.time_scale = 4.0
	await frames(300)
	G.time_scale = 1.0
	await G.flush_claims()
	await shot("hunt_adultos")
	hs.world.debug_spawn("planta_3_3", 6)
	await frames(90)
	await shot("hunt_cercado")
	await G.debug_grant(250000, 800)
	main.goto("hub")
	await shot("hub")
	main.goto("hunts")
	await shot("selecao_hunts")
	main.goto("party")
	await shot("grupo")
	main.goto("monster", {"uid": G.main_monster().uid})
	await shot("monstro")
	main.goto("collection")
	await shot("colecao")
	main.goto("inventory")
	await shot("inventario")
	main.goto("market")
	await frames(10)
	await shot("market")
	main.goto("altar")
	await shot("altar")
	main.goto("rankings")
	await frames(10)
	await shot("rankings")
	main.goto("challenges")
	await shot("desafios")
	main.goto("daily")
	await frames(10)
	await shot("chefe_diario")
	main.toast(Loc.t("Recrutado: %s (qualidade %s)!") % ["Marolinho", "87% " + Loc.tx(DataDB.quality_grade(87).name)], UI.C_GOOD)
	main.goto("party")
	await frames(3)
	await shot("grupo_toast")
	await G.debug_set_level(215)
	await G.set_current_hunt("w2_210_1")
	hs.load_current_hunt()
	main.goto("hunt")
	G.time_scale = 3.0
	await frames(240)
	G.time_scale = 1.0
	await shot("mundo2_corrompido")
	await G.debug_set_level(45)
	hs.world.refresh_party()
	hs.start_challenge(DataDB.challenge_for_level(40))
	await frames(260)
	await shot("desafio_boss")
	quit()
