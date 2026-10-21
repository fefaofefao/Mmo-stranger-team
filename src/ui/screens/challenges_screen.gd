extends Screen
## Desafios (bosses) de nível 10 a 90.


func build() -> void:
	var b := make_layout("Desafios")
	b.add_child(UI.label("Chefes únicos com fases, invocações e áreas de dano — a IA do grupo tenta desviar sozinha. Monstros derrotados NÃO revivem durante o desafio. Vitória: recompensa garantida e libera o próximo bloco de hunts.", 19, UI.C_MUTED, true))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	for c in DataDB.challenges:
		var p := UI.panel()
		var row := UI.hbox(10)
		p.add_child(row)
		row.add_child(UI.portrait(c.boss_form, false, 84))
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var rec: Dictionary = Game.save.challenges.get(c.id, {})
		v.add_child(UI.label("Nv %d · %s" % [int(c.level), c.name], 22, UI.C_GOLD if rec.get("cleared", false) else UI.C_TEXT))
		var mech: Array = []
		var m: Dictionary = c.mechanics
		if m.has("summon"):
			mech.append("invoca %s" % DataDB.form(m.summon.form).name)
		if m.has("aoe"):
			mech.append("áreas de dano")
		mech.append("enfurece em 50%")
		v.add_child(UI.label("%s · %s" % [DataDB.type_name(c.type), ", ".join(mech)], 18, UI.C_MUTED, true))
		var rw: Dictionary = c.rewards
		v.add_child(UI.label("Recompensa: %s ouro, Essência, item %s%s" % [UI.fmt(rw.gold), DataDB.rarity(rw.item_rarity).name, " · abre o MUNDO 2" if c.get("unlocks", "") == "world2" else ""], 18, UI.C_TEXT, true))
		if rec.get("cleared", false):
			v.add_child(UI.label("✓ Vencido · melhor tempo %s" % UI.fmt_time(float(rec.get("best", 0))), 18, UI.C_GOOD))
		var lock := Game.challenge_lock_reason(c)
		if lock == "":
			var cc: Dictionary = c
			row.add_child(UI.small_button("Desafiar", func(): _start(cc)))
		else:
			var l := UI.label(lock, 18, UI.C_BAD)
			l.custom_minimum_size = Vector2(150, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(l)
		sc[1].add_child(p)


func _start(c: Dictionary) -> void:
	var fighting := Game.fighting_monsters().size()
	if not await main.confirm("Desafio %d" % int(c.level), "Enfrentar %s com %d monstro(s) em campo?" % [c.name, fighting], "Lutar", "Voltar"):
		return
	var hs = main.ensure_hunt_screen()
	main.goto("hunt")
	hs.start_challenge(c)
