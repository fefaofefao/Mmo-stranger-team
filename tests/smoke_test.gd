extends SceneTree
## Teste de integração headless: roda o jogo real (cena principal) com o servidor mock.
##   godot --headless --path . -s tests/smoke_test.gd
## Usa um perfil de dados isolado (apaga save e servidor mock locais antes de começar).

var main
var failures := 0
var G
var B


func _initialize() -> void:
	for f in ["user://save.json", "user://mock_server.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		failures += 1
		printerr("FALHOU: ", msg)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func sim_seconds(world, seconds: float) -> void:
	var steps := int(seconds / 0.05)
	for i in steps:
		world.step(0.05)
		if i % 40 == 0:
			await process_frame


func _run() -> void:
	G = root.get_node("Game")
	B = root.get_node("Backend")
	G.load_local()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	G.save.settings.consent_answered = true
	print("== sessão")
	await G.start_session()
	check(not G.has_starter(), "save novo sem inicial")
	await G.choose_starter("fogo_1")
	check(G.has_starter(), "inicial escolhido")
	check(G.save.current_hunt != "", "hunt inicial definida: %s" % G.save.current_hunt)
	main.goto("hunt")
	await frames(3)
	var hs = main.hunt_screen
	var w = hs.world
	check(w.party.size() == 1, "1 monstro em campo")
	print("== combate")
	var t0 := Time.get_ticks_msec()
	await sim_seconds(w, 240.0)
	var kills := int(G.save.stats.kills)
	check(kills > 5, "abates em 4 min simulados: %d" % kills)
	var m = G.main_monster()
	check(int(m.level) > 1, "subiu de nível: %d" % int(m.level))
	print("   (%d abates, nível %d, %d ms)" % [kills, int(m.level), Time.get_ticks_msec() - t0])
	await G.flush_claims()
	check(int(G.save.gold) > 0, "ouro creditado pelo servidor: %d" % int(G.save.gold))
	# coerência: abates reais vs modelo analítico
	var est := KillRate.estimate(G.fighter_stats(), DataDB.hunts[G.save.current_hunt])
	print("   modelo: %.0f abates/h · real: %.0f abates/h" % [est.kills_per_hour, kills / 240.0 * 3600.0])
	print("== desempenho (40 inimigos)")
	for i in 40:
		w.spawn_enemy(DataDB.hunts[G.save.current_hunt].monsters[0].form, 3, w.nav.nearest_free(w.map.start + Vector2i(randi_range(-8, 8), randi_range(-8, 8)), 10))
	var t1 := Time.get_ticks_usec()
	for i in 200:
		w.step(0.05)
	var per_step := (Time.get_ticks_usec() - t1) / 200.0
	print("   %.2f ms por passo de simulação com %d inimigos" % [per_step / 1000.0, w.alive_enemy_count()])
	check(per_step < 8000.0, "passo de simulação rápido o bastante")
	print("== telas")
	for scr in main.SCREENS.keys():
		if scr in ["title", "starter"]:
			continue
		var p := {}
		if scr == "monster":
			p = {"uid": m.uid}
		main.goto(scr, p)
		await frames(4)
		check(main.current != null and main.current.get_child_count() > 0, "tela %s abre" % scr)
	main.goto("hunt")
	hs.load_current_hunt()
	w = hs.world
	await frames(2)
	print("== recrutamento / altar / estrelas / market")
	await B.request("debug_force", {"recruit": 2, "drop": "epico"})
	var k0 := int(G.save.stats.kills)
	await sim_seconds(w, 120.0)
	print("   abates nesse trecho: %d" % (int(G.save.stats.kills) - k0))
	await G.flush_claims()
	var dep = G.depot_monsters()
	check(G.save.monsters.size() >= 2, "recrutou monstros (total %d)" % G.save.monsters.size())
	var epic := 0
	for it in G.save.items.values():
		if it.rarity == "epico" and not it.bound:
			epic += 1
	check(epic >= 1, "drop Épico forçado veio do servidor")
	await G.debug_grant(1000000, 5000)
	var r: Dictionary = await G.buy_star(m.uid)
	check(r.get("ok", false) and int(G.main_monster().stars) == 1, "comprou estrela")
	if G.save.party.size() > 1:
		G.remove_from_party(G.save.party[G.save.party.size() - 1])
	dep = G.depot_monsters()
	if not dep.is_empty():
		var before := int(G.save.essences[MonsterLogic.type_of(dep[0])])
		var rc: Dictionary = await G.convert_monster(dep[0].uid)
		check(rc.get("ok", false) and int(G.save.essences[rc.essence_type]) > before, "Altar converteu monstro em Essência")
	var tradable := ""
	for it in G.save.items.values():
		if not it.bound and it.loc != "equip":
			tradable = it.uid
	if tradable != "":
		var lr: Dictionary = await G.market_list_item(tradable, 999)
		check(lr.get("ok", false) and not G.save.items.has(tradable), "listou item no market")
		var my: Dictionary = await G.market_my()
		var cr: Dictionary = await G.market_cancel(my.listings[0].id)
		check(cr.get("ok", false) and G.save.items.has(tradable), "cancelou e recebeu o item de volta")
	var search: Dictionary = await B.request("market_search", {"filters": {"kind": "item"}})
	var gold_before := int(G.save.gold)
	var br: Dictionary = await G.market_buy(search.listings[0].id)
	check(br.get("ok", false) and int(G.save.gold) < gold_before, "comprou no market")
	print("== desafio 10")
	await G.debug_set_level(18)
	w.refresh_party()
	var c10: Dictionary = DataDB.challenge_for_level(10)
	hs.start_challenge(c10)
	await frames(3)
	var done := [false, false]
	w.challenge_finished.connect(func(won, _s): done[0] = true; done[1] = won)
	await sim_seconds(w, 230.0)
	check(done[0], "desafio terminou")
	print("   vitória: %s em %.0fs" % [done[1], w.elapsed])
	await frames(10)
	for ch in main.overlay.get_children():
		if ch is UIDialog:
			ch._choose(0)
	await frames(10)
	check(G.challenge_cleared("c10") == done[1], "registro do desafio")
	print("== offline")
	var st: Dictionary = B.impl.logic.p()
	st.last_seen_at = float(st.last_seen_at) - 3 * 3600.0
	var s: Dictionary = await G.claim_offline()
	check(int(s.get("kills", 0)) > 0, "progresso offline: %d abates em 3h" % int(s.get("kills", 0)))
	print("== mundo 2")
	G.save.debug_unlock_all = true
	await G.debug_set_level(215)
	await G.set_current_hunt("w2_210_0")
	hs.load_current_hunt()
	await frames(2)
	check(hs.world.party.size() == min(3, G.save.party.size()), "monstros em campo no nível 215: %d" % hs.world.party.size())
	await sim_seconds(hs.world, 30.0)
	G.save_local()
	print("\n==== smoke test: %d falhas ====" % failures)
	quit(1 if failures > 0 else 0)
