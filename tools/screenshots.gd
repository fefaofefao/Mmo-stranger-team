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
	G.save.settings.tutorial_done = true
	var all_tips := {}
	for k in ["hub", "hunts", "party", "monster", "depot", "altar", "collection", "inventory", "shop", "market", "rankings", "challenges", "daily", "boosts"]:
		all_tips[k] = true
	G.save.settings.tips_seen = all_tips
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
	hs._run_tutorial()
	await frames(100)
	await shot("tutorial")
	for ch in main.overlay.get_children():
		if ch is Tutorial:
			ch._show(2)
	await frames(30)
	await shot("tutorial_shiny")
	for ch in main.overlay.get_children():
		if ch is Tutorial:
			ch._finish()
	await G.debug_set_level(40)
	G.main_monster().train = 15
	await B.request("debug_force", {"recruit": 2})
	await G.set_current_hunt("w1_s3_fogo_2")
	G.save.debug_unlock_all = true
	# progresso de Marcos de Caça para o painel e a Coleção
	var hk := [320, 1300, 60, 4100]
	var hi := 0
	for mm in DataDB.hunts["w1_s3_fogo_2"].monsters:
		G.save.collection[mm.form] = {"seen": true, "kills": hk[hi % hk.size()], "recruited": false, "shiny": false}
		hi += 1
	for fid in ["agua_1_1", "gelo_2_1", "planta_1_2", "terra_3_1", "vento_2_2", "luz_1_1", "sombra_2_1", "eletrico_1_1"]:
		G.save.collection[fid] = {"seen": true, "kills": 1100, "recruited": false, "shiny": false}
	G.invalidate_bonuses()
	hs.load_current_hunt()
	G.time_scale = 4.0
	await frames(300)
	G.time_scale = 1.0
	await G.flush_claims()
	await shot("hunt_adultos")
	hs.world.debug_spawn("planta_3_3", 6)
	await frames(90)
	await shot("hunt_cercado")
	var sp = load("res://src/ui/hunt_stats_panel.gd").open(main)
	await frames(10)
	await shot("hunt_status")
	sp.queue_free()
	await frames(2)
	await G.debug_grant(250000, 800)
	main.goto("hub")
	await shot("hub")
	main.goto("hunts")
	await shot("selecao_hunts")
	main.current.type_filter = "fogo"
	main.current.rebuild()
	await shot("hunts_filtro_fogo")
	main.goto("hunt")
	var pk = load("res://src/ui/monster_picker.gd").open(main.overlay, Loc.t("Trocar %s") % MonsterLogic.display_name(G.main_monster()), G.main_monster())
	await shot("troca_rapida")
	pk._close("")
	main.goto("party")
	await shot("grupo")
	main.goto("monster", {"uid": G.main_monster().uid})
	await shot("monstro")
	var ms = main.current
	await frames(3)
	ms._scroll.scroll_vertical = 900
	await frames(3)
	ms.choosing_slot = "garra"
	ms._rebuild_here()
	await frames(6)
	await shot("monstro_trocar_equip")
	main.goto("shop")
	await frames(20)
	await shot("loja")
	G.save.settings.tips_seen.erase("depot")
	main.goto("depot")
	await frames(5)
	await shot("dica_depot")
	for ch in main.overlay.get_children():
		if ch is UIDialog:
			ch._choose(0)
	main.goto("collection")
	await shot("colecao")
	# itens e monstros no Depot para mostrar as ações em lote
	var irng := RandomNumberGenerator.new()
	irng.seed = 7
	var rars := ["comum", "comum", "incomum", "comum", "raro", "incomum", "epico", "comum"]
	var bases := DataDB.item_bases.keys()
	for i in rars.size():
		G.add_item(ItemLogic.create(bases[(i * 37) % bases.size()], rars[i], irng, rars[i] in ["comum", "incomum"]), false)
	var fams := ["planta_2", "terra_3", "vento_1", "luz_2"]
	for i in fams.size():
		G.add_recruit({"server_id": "shot_m%d" % i, "family": fams[i], "form": fams[i] + "_1", "shiny": i == 3, "stars": 0, "quality": [12, 35, 64, 81][i]}, false)
	main.goto("inventory")
	main.current._select_upto(1)
	await shot("inventario")
	main.goto("market")
	await frames(10)
	await shot("market")
	main.current.filters.kind = "monster"
	main.current.loaded_tab = -1
	main.current.rebuild()
	await frames(20)
	await shot("market_monstros")
	await G.debug_grant(0, 0, 1350)
	await G.buy_boost("shiny")
	await G.ad_boost("xp")
	main.goto("boosts")
	await frames(10)
	await shot("bonus")
	main.goto("diamonds")
	await frames(5)
	await shot("diamantes")
	main.goto("altar")
	main.current._select_quality(G.depot_monsters(), 101)
	await shot("altar")
	main.current.tab = 1
	main.current.rebuild()
	await frames(3)
	await shot("altar_aprimorar")
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
	var dlg = main.dialog(Loc.t("Bem-vindo de volta!"), "Fogarito +3 níveis\n1.234 abates\n+45.6k ouro", [Loc.t("Dobrar ▶"), Loc.t("Coletar")], "chest")
	await shot("dialogo")
	dlg._choose(1)
	await G.debug_set_level(150)
	await G.set_current_hunt("w2_150_1")
	hs.load_current_hunt()
	main.goto("hunt")
	G.time_scale = 3.0
	await frames(200)
	G.time_scale = 1.0
	await shot("mundo2_abismo")
	await G.debug_set_level(215)
	await G.set_current_hunt("w3_210_1")
	hs.load_current_hunt()
	main.goto("hunt")
	G.time_scale = 3.0
	await frames(240)
	G.time_scale = 1.0
	hs._cycle_camera()
	await frames(30)
	await shot("mundo3_astral")
	main.goto("hunts")
	main.current.tab = 4
	main.current.rebuild()
	await shot("hunts_mundo3")
	main.goto("challenges")
	await frames(3)
	for scn in main.current.find_children("*", "ScrollContainer", true, false):
		scn.scroll_vertical = 100000
	await frames(3)
	await shot("desafios_chefes_de_mundo")
	await G.debug_set_level(45)
	hs.world.refresh_party()
	hs.start_challenge(DataDB.challenge_for_level(40))
	await frames(260)
	await shot("desafio_boss")
	quit()
