extends SceneTree
## Simulação de balanceamento: progressão de um jogador do nível 1 ao 300 usando o mesmo modelo
## de abates/hora do jogo (KillRate, validado contra o combate real no smoke test).
##   godot --headless --path . -s tools/balance_sim.gd
## Gera docs/RELATORIO_BALANCEAMENTO.md

const CHECKPOINTS := [5, 10, 16, 20, 30, 35, 50, 60, 80, 90, 100, 110, 130, 150, 180, 210, 240, 270, 300]
const STARTERS := ["fogo_1", "agua_1", "luz_1"]

var report: Array = []


func _initialize() -> void:
	DataDB.load_all()
	report.append("# Relatório de balanceamento (simulação 1 → 300)\n")
	report.append("Gerado por `tools/balance_sim.gd` com o modelo analítico `KillRate` (o mesmo do progresso offline e do servidor). ")
	report.append("O smoke test compara esse modelo com o combate real em tempo real (diferença típica < 10%).\n")
	report.append("**Premissas do jogador simulado:** escolhe sempre a hunt liberada com mais XP/h que não seja perigosa; ")
	report.append("vence cada Desafio ao atingir nível do desafio + 3; recruta 2 monstros extras (após ~500 e ~1000 abates); ")
	report.append("equipamento do tier do nível (Incomum até 40, Raro até 110, Épico até 210, Lendário depois) com aprimoramento crescente; ")
	report.append("estrelas no principal a cada 30 níveis (máx. 5). Sem boost de 2x XP.\n")
	var summary := {}
	for st in STARTERS:
		summary[st] = simulate(st)
	report.append("\n## Comparação entre iniciais (horas de jogo acumuladas)\n")
	var hdr := "| Nível |"
	var sep := "|---|"
	for st in STARTERS:
		hdr += " %s |" % DataDB.form(st + "_1").name
		sep += "---|"
	report.append(hdr)
	report.append(sep)
	for cp in CHECKPOINTS:
		var row := "| %d |" % cp
		for st in STARTERS:
			row += " %s |" % _h(summary[st].get(cp, -1.0))
		report.append(row)
	var ref: Dictionary = summary[STARTERS[0]]
	report.append("\n## Tempo de calendário estimado (%s)\n" % DataDB.form(STARTERS[0] + "_1").name)
	report.append("- **Casual**: 1h ativa + 1 sessão offline de 8h por dia ≈ %.1fh de caça/dia" % (1.0 + 8.0 * float(DataDB.config.offline.efficiency)))
	report.append("- **Dedicado**: 3h ativas + 2 sessões offline de 8h por dia ≈ %.1fh de caça/dia\n" % (3.0 + 16.0 * float(DataDB.config.offline.efficiency)))
	report.append("| Nível | Horas | Dias (casual) | Dias (dedicado) |")
	report.append("|---|---|---|---|")
	var casual := 1.0 + 8.0 * float(DataDB.config.offline.efficiency)
	var dedicated := 3.0 + 16.0 * float(DataDB.config.offline.efficiency)
	for cp in [16, 35, 80, 110, 150, 210, 240, 300]:
		var hrs: float = ref.get(cp, -1.0)
		report.append("| %d | %s | %.0f | %.0f |" % [cp, _h(hrs), hrs / casual, hrs / dedicated])
	var f := FileAccess.open("res://docs/RELATORIO_BALANCEAMENTO.md", FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	print("\n".join(report))
	quit()


func _h(hrs: float) -> String:
	if hrs < 0:
		return "-"
	if hrs < 1.0:
		return "%dmin" % int(hrs * 60)
	return "%.1fh" % hrs


func _gear(level: int, items: Dictionary, m: Dictionary) -> void:
	items.clear()
	m.equip = {}
	var tier := 1
	for tr in DataDB.item_tiers:
		if int(tr.level) <= level:
			tier = int(tr.tier)
	var rar := "incomum"
	if level >= 210:
		rar = "lendario"
	elif level >= 110:
		rar = "epico"
	elif level >= 40:
		rar = "raro"
	var enh := clampi(level / 30, 0, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = level
	var t: String = MonsterLogic.type_of(m)
	for s in DataDB.item_slots:
		var it := ItemLogic.create("%s_%s_t%d" % [s.id, t, tier], rar, rng, false, "%s_%s" % [m.uid, s.id])
		it.affixes = []
		it.enh = enh
		items[it.uid] = it
		m.equip[s.id] = it.uid


func simulate(starter: String) -> Dictionary:
	var main := MonsterLogic.create(starter, 1, false, "main")
	var party: Array = [main]
	var items := {}
	var hours := 0.0
	var kills := 0.0
	var cleared := {}
	var reached := {}
	var log_rows: Array = []
	var last_hunt := ""
	var recruits := [["planta_2", 500.0], ["terra_3", 1000.0]]
	report.append("\n## Inicial: %s\n" % DataDB.form(starter + "_1").name)
	report.append("| Nível | Horas acumuladas | Hunt escolhida | Abates/h | XP/h | Em campo |")
	report.append("|---|---|---|---|---|---|")
	while int(main.level) < 300 and hours < 200000.0:
		var lvl := int(main.level)
		for m in party:
			m.stars = mini(5, int(m.level) / 30)
		# desafios
		for c in DataDB.challenges:
			if lvl >= int(c.level) + 3:
				cleared[int(c.level)] = true
		# equipamento
		var all_items := {}
		for m in party:
			var its := {}
			_gear(int(m.level), its, m)
			all_items.merge(its)
		items = all_items
		var fighters: Array = []
		var nf := PartyLogic.fighting_count(lvl, party.size())
		for i in nf:
			fighters.append(MonsterLogic.compute_stats(party[i], items))
		# melhor hunt
		var best := {}
		var best_xph := 0.0
		var best_est := {}
		for h in DataDB.hunt_list:
			if lvl < int(h.unlock_level):
				continue
			var rc := int(h.get("requires_challenge", 0))
			if rc > 0 and not cleared.has(rc):
				continue
			var est := KillRate.estimate(fighters, h)
			if est.deaths_per_hour > 4.0 or est.kills_per_hour < 60:
				continue
			var xph := KillRate.xp_per_hour(fighters, h, lvl)
			if xph > best_xph:
				best_xph = xph
				best = h
				best_est = est
		if best.is_empty():
			best = DataDB.hunt_list[0]
			best_est = KillRate.estimate(fighters, best)
			best_xph = max(1.0, KillRate.xp_per_hour(fighters, best, lvl))
		var need := Formulas.xp_to_next(lvl) - float(main.xp)
		var dt := need / best_xph
		hours += dt
		var k: float = best_est.kills_per_hour * dt
		kills += k
		var base_xp := Formulas.xp_for_kill(int(best.level)) * float(best.get("xp_mult", 1.0))
		var shares := PartyLogic.split_xp(party, base_xp * k, int(best.level))
		for i in party.size():
			MonsterLogic.add_xp(party[i], shares[i] if i > 0 else need + 0.001)
		for r in recruits.duplicate():
			if kills >= float(r[1]):
				party.append(MonsterLogic.create(r[0], 1, false, "r%d" % party.size()))
				recruits.erase(r)
		if CHECKPOINTS.has(int(main.level)) and not reached.has(int(main.level)):
			reached[int(main.level)] = hours
			report.append("| %d | %s | %s (Nv %d) | %s | %s | %d |" % [int(main.level), _h(hours), best.name, int(best.level), UI.fmt(best_est.kills_per_hour), UI.fmt(best_xph), nf])
	return reached
