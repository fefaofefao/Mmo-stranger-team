extends Screen
## Rankings globais e semanais.

var cat := 0
var period := "global"
var challenge_idx := 0
var data: Dictionary = {}
var loaded_key := ""


func build() -> void:
	var b := make_layout(Loc.t("Rankings"), "trophy")
	var cats := [["level", Loc.t("Nível")], ["collection", Loc.t("Coleção")], ["shinies", Loc.t("Shinies")], ["stars", Loc.t("Estrelas")], ["challenge", Loc.t("Desafios")]]
	var names: Array = []
	for c in cats:
		names.append(c[1])
	b.add_child(tabs(names, cat, func(i): cat = i; rebuild()))
	b.add_child(tabs([Loc.t("Global"), Loc.t("Semanal")], 0 if period == "global" else 1, func(i): period = "global" if i == 0 else "weekly"; rebuild()))
	var key: String = cats[cat][0]
	if key == "challenge":
		var cn: Array = []
		for c in DataDB.challenges:
			cn.append(str(int(c.level)))
		b.add_child(tabs(cn, challenge_idx, func(i): challenge_idx = i; rebuild()))
		key = "challenge_" + DataDB.challenges[challenge_idx].id
	var full_key := key + "|" + period
	if loaded_key != full_key:
		b.add_child(empty_note(Loc.t("Carregando..."), "clock"))
		_load(key, full_key)
		return
	var is_time: bool = data.get("is_time", false)
	if int(data.get("my_rank", -1)) > 0:
		var me := UI.card(true)
		var mr := UI.hbox(8)
		me.add_child(mr)
		mr.add_child(UI.icon("user", 34))
		mr.add_child(UI.expand(UI.label(Loc.t("Sua posição: #%d") % int(data.my_rank), 22, UI.C_GOLD)))
		mr.add_child(UI.label(_fmt(float(data.my_value), is_time), 22, UI.C_GOLD))
		b.add_child(me)
	var sc := UI.scroll(4)
	b.add_child(sc[0])
	for e in data.get("entries", []):
		var p := UI.card(e.me)
		var row := UI.hbox(8)
		p.add_child(row)
		var rk := int(e.rank)
		if rk <= 3:
			var medal := UI.icon("trophy", 30)
			medal.modulate = [Color(1, 0.85, 0.3), Color(0.85, 0.85, 0.9), Color(0.85, 0.55, 0.3)][rk - 1]
			row.add_child(medal)
		else:
			var rl := UI.label("#%d" % rk, 20, UI.C_MUTED)
			rl.custom_minimum_size = Vector2(46, 0)
			row.add_child(rl)
		row.add_child(UI.expand(UI.label(e.name, 20, UI.C_GOLD if e.me else UI.C_TEXT)))
		row.add_child(UI.label(_fmt(float(e.value), is_time), 20, UI.C_GOLD if e.me else UI.C_TEXT))
		sc[1].add_child(p)
	if data.get("entries", []).is_empty():
		sc[1].add_child(empty_note(Loc.t("Ninguém pontuou ainda."), "trophy"))


func _fmt(v: float, is_time: bool) -> String:
	return UI.fmt_time(v) if is_time else UI.fmt(v)


func _load(key: String, full_key: String) -> void:
	await Game.cloud_sync()
	var r: Dictionary = await Backend.request("rankings", {"category": key, "period": period})
	data = r if r.get("ok", false) else {}
	loaded_key = full_key
	if is_inside_tree():
		rebuild()
