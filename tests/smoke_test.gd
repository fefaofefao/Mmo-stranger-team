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
	print("== time: quantos lutam acompanham o nível (inclusive ao subir naturalmente)")
	G.save.debug_unlock_all = true
	while G.save.party.size() < 3:
		var rec := {"server_id": "dbg%d" % G.save.party.size(), "form": "planta_1_1", "shiny": false, "quality": 30}
		G.add_recruit(rec, false)
	await G.debug_set_level(200)
	await G.set_current_hunt("w2_190_0")
	hs.load_current_hunt()
	w = hs.world
	await frames(2)
	await sim_seconds(w, 2.0)
	check(w.alive_on_field() == 2, "nível 200: 2 monstros caçando no mapa (%d)" % w.alive_on_field())
	# sobe do 209 para o 210 com XP de abates: o 3º precisa entrar sozinho
	await G.debug_set_level(209)
	var mm = G.main_monster()
	mm.xp = Formulas.xp_to_next(209) - 1.0
	G.on_kill(DataDB.hunts["w2_190_0"], DataDB.hunts["w2_190_0"].monsters[0].form, 190, "", false, w.participants)
	await sim_seconds(w, 1.5)
	check(int(G.main_level()) >= 210 and w.alive_on_field() == 3, "ao chegar no 210 o 3º entra em campo (%d)" % w.alive_on_field())
	print("== time: revezamento quando alguém cai")
	await G.debug_set_level(50)
	await G.set_current_hunt("w1_s3_fogo_1")
	hs.load_current_hunt()
	w = hs.world
	await sim_seconds(w, 1.0)
	check(w.alive_on_field() == 1, "nível 50: 1 em campo")
	var first: Creature = w.party[0]
	var first_uid: String = first.mon_uid
	w.deal_damage(null, first, 0.0, true, first.max_hp * 2.0)
	await sim_seconds(w, 0.6)
	check(w.fallen.has(first_uid), "principal caído")
	check(w.alive_on_field() == 1 and w.party.filter(func(c): return c.alive)[0].mon_uid != first_uid, "o próximo do grupo entrou no lugar")
	var xp_before := float(G.monster(first_uid).xp)
	var lvl_before := int(G.monster(first_uid).level)
	G.on_kill(w.hunt, w.hunt.monsters[0].form, int(w.hunt.level), "", false, w.participants)
	check(int(G.monster(first_uid).level) > lvl_before or float(G.monster(first_uid).xp) > xp_before, "caído continua ganhando XP como participante")
	for c in w.party.duplicate():
		if c.alive:
			w.deal_damage(null, c, 0.0, true, c.max_hp * 2.0)
	await sim_seconds(w, 0.3)
	var guard := 0
	while w.alive_on_field() > 0 and guard < 5:
		for c in w.party.duplicate():
			if c.alive:
				w.deal_damage(null, c, 0.0, true, c.max_hp * 2.0)
		await sim_seconds(w, 0.3)
		guard += 1
	check(w.team_revive_remaining() > 0.0, "todos caíram: time aguarda renascer")
	await sim_seconds(w, float(DataDB.config.combat.revive_seconds) + 0.5)
	check(w.alive_on_field() == 1 and w.fallen.is_empty(), "time renasceu junto")
	print("== chefe diário")
	var ds: Dictionary = await G.daily_status()
	check(ds.get("ok", false) and int(ds.entries) == 3, "status do chefe diário")
	var dst: Dictionary = await G.daily_start()
	check(dst.get("ok", false), "entrada consumida")
	hs.start_daily(dst)
	await frames(3)
	var dd := [false, false]
	hs.world.challenge_finished.connect(func(won, _s): dd[0] = true; dd[1] = won)
	await sim_seconds(hs.world, 125.0)
	check(dd[0], "luta do chefe diário terminou (vitória: %s, dano %d%%)" % [dd[1], int(hs.world.boss_damage_fraction() * 100)])
	await frames(10)
	for ch in main.overlay.get_children():
		if ch is UIDialog:
			ch._choose(0)
	await frames(5)
	var ds2: Dictionary = await G.daily_status()
	check(int(ds2.used) == 1, "1 entrada usada")
	print("== mundo 3")
	await G.debug_set_level(215)
	await G.set_current_hunt("w3_210_0")
	hs.load_current_hunt()
	await frames(2)
	await sim_seconds(hs.world, 1.0)
	check(hs.world.alive_on_field() == min(3, G.save.party.size()), "monstros em campo no nível 215: %d" % hs.world.alive_on_field())
	await sim_seconds(hs.world, 30.0)
	print("== shiny de demonstração do tutorial")
	var wd = hs.world
	var demo = wd.spawn_demo_shiny()
	check(demo != null and demo.shiny and demo.demo, "shiny de demonstração apareceu")
	var pk: int = G.pending_kills.size()
	var kills_before: int = int(G.save.stats.kills)
	await sim_seconds(wd, 5.0)
	check(is_instance_valid(demo) and demo.alive, "ninguém ataca o shiny de demonstração")
	wd._on_death(demo, wd.party[0])
	check(G.pending_kills.size() <= pk + 200 and int(G.save.stats.kills) >= kills_before, "abate do demo não vira pedido ao servidor")
	var found := false
	for k in G.pending_kills:
		if k.get("ticket", "") == "" and k.form == demo.form_id and false:
			found = true
	check(not found, "demo sem ticket de shiny")
	# status da caça: conta abates/XP/shiny da hunt atual e zera ao trocar de hunt
	print("-- status da caça")
	var hid: String = G.save.current_hunt
	var hh: Dictionary = DataDB.hunts[hid]
	var hk0 := int(G.hunt_session_stats().kills)
	G.on_kill(hh, hh.monsters[0].form, int(hh.level), "", true, [])
	G.hunt_session_tick(60.0)
	var hst: Dictionary = G.hunt_session_stats()
	check(int(hst.kills) == hk0 + 1 and float(hst.xp) > 0.0 and int(hst.shinies) >= 1, "status conta abate, XP e shiny")
	check(float(hst.kills_per_hour) > 0.0 and float(hst.seconds) >= 60.0, "status calcula média por hora")
	var other := ""
	for h2 in DataDB.hunt_list:
		if h2.id != hid and int(h2.world) == 1:
			other = h2.id
			break
	await G.set_current_hunt(other)
	check(int(G.hunt_session_stats().kills) == 0 and float(G.hunt_session_stats().seconds) == 0.0, "status zera ao trocar de hunt")
	G.save.current_hunt = hid
	# Passe VIP: anúncio premiado sai sem vídeo
	G.save.vip = true
	var okv: bool = await root.get_node("Ads").show_rewarded("teste")
	check(okv, "VIP ganha a recompensa do anúncio na hora")
	G.save.vip = false
	G.save_local()
	print("\n==== smoke test: %d falhas ====" % failures)
	quit(1 if failures > 0 else 0)
