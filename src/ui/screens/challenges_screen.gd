extends Screen
## Desafios (bosses) de nível 10 a 90.


func build() -> void:
	var b := make_layout(Loc.t("Desafios"), "skull")
	b.add_child(UI.label(Loc.t("Chefes com fases, invocações e áreas de dano — a IA desvia sozinha. Quem cai não revive (o próximo do grupo entra). A vitória dá recompensa garantida e libera o próximo bloco de hunts."), 17, UI.C_MUTED, true))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	for c in DataDB.challenges:
		var rec: Dictionary = Game.save.challenges.get(c.id, {})
		var lock := Game.challenge_lock_reason(c)
		var p := UI.card(rec.get("cleared", false), lock != "")
		var row := UI.hbox(10)
		p.add_child(row)
		row.add_child(UI.portrait_frame(c.boss_form, false, 76))
		var v := UI.vbox(3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var hr := UI.hbox(6)
		v.add_child(hr)
		hr.add_child(UI.pill(Loc.t("Nv %d") % int(c.level), UI.C_GOLD, 15))
		if c.get("world_boss", false):
			hr.add_child(UI.pill(Loc.t("Chefe de Mundo"), Color("#ff7a5a"), 15))
		var nl := UI.label(DataDB.challenge_name(c), 20, UI.C_GOLD if rec.get("cleared", false) else UI.C_TEXT)
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(nl)
		var mech: Array = []
		var m: Dictionary = c.mechanics
		if m.has("summon"):
			mech.append(Loc.t("invoca %s") % DataDB.form_name(m.summon.form))
		if m.has("aoe"):
			mech.append(Loc.t("áreas de dano"))
		mech.append(Loc.t("enfurece em 50%"))
		var tr := UI.hbox(6)
		tr.add_child(UI.icon("t_" + c.type, 24))
		var ml := UI.label(", ".join(mech), 15, UI.C_MUTED, true)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ml.custom_minimum_size.x = 100
		tr.add_child(ml)
		v.add_child(tr)
		var rw: Dictionary = c.rewards
		var rl := UI.label(Loc.t("Recompensa: %s ouro, Essência e item %s") % [UI.fmt(rw.gold), DataDB.rarity_name(rw.item_rarity)] + (" · " + Loc.t("abre o MUNDO 2") if c.get("unlocks", "") == "world2" else (" · " + Loc.t("abre o MUNDO 3") if c.get("unlocks", "") == "world3" else "")), 15, UI.C_TEXT, true)
		rl.custom_minimum_size.x = 100
		v.add_child(rl)
		if c.get("world_boss", false):
			var wl := UI.label(Loc.t("Prova de força do mundo: precisa de %d monstros fortes em campo. Não pode ser recrutado.") % int(c.get("min_fighters", 2)), 15, Color("#ffb08a"), true)
			wl.custom_minimum_size.x = 100
			v.add_child(wl)
		# linha de ação: estado à esquerda, botão à direita (sempre dentro da tela)
		var ar := UI.hbox(8)
		v.add_child(ar)
		var stl: Label
		if rec.get("cleared", false):
			stl = UI.label(Loc.t("Vencido · melhor tempo %s") % UI.fmt_time(float(rec.get("best", 0))), 15, UI.C_GOOD, true)
		elif lock != "":
			stl = UI.label(Loc.t(lock) if not lock.begins_with("Aguarde") else lock, 15, UI.C_BAD, true)
		else:
			stl = UI.label(Loc.t("Disponível"), 15, UI.C_GOOD)
		stl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stl.custom_minimum_size.x = 80
		stl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ar.add_child(stl)
		if lock == "":
			var cc: Dictionary = c
			var fb := UI.icon_button("sword", Loc.t("Lutar"), func(): _start(cc), 20, 56, "primary")
			fb.custom_minimum_size = Vector2(160, 56)
			ar.add_child(fb)
		else:
			ar.add_child(UI.icon("lock", 34))
		sc[1].add_child(p)


func _start(c: Dictionary) -> void:
	var fighting := Game.fighting_monsters().size()
	if not await main.confirm(Loc.t("Desafio %d") % int(c.level), Loc.t("Enfrentar %s com %d monstro(s) em campo?") % [DataDB.challenge_name(c), fighting], Loc.t("Lutar"), Loc.t("Voltar")):
		return
	var hs = main.ensure_hunt_screen()
	main.goto("hunt")
	hs.start_challenge(c)
