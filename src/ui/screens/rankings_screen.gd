extends Screen
## Rankings globais e semanais.

const CATS := [["level", "Nível"], ["collection", "Coleção"], ["shinies", "Shinies"], ["stars", "Estrelas"], ["challenge", "Desafios"]]
var cat := 0
var period := "global"
var challenge_idx := 0
var data: Dictionary = {}
var loaded_key := ""


func build() -> void:
	var b := make_layout("Rankings")
	var names: Array = []
	for c in CATS:
		names.append(c[1])
	b.add_child(tabs(names, cat, func(i): cat = i; rebuild()))
	b.add_child(tabs(["Global", "Semanal"], 0 if period == "global" else 1, func(i): period = "global" if i == 0 else "weekly"; rebuild()))
	var key: String = CATS[cat][0]
	if key == "challenge":
		var cn: Array = []
		for c in DataDB.challenges:
			cn.append(str(int(c.level)))
		b.add_child(tabs(cn, challenge_idx, func(i): challenge_idx = i; rebuild()))
		key = "challenge_" + DataDB.challenges[challenge_idx].id
	var full_key := key + "|" + period
	var sc := UI.scroll(4)
	b.add_child(sc[0])
	if loaded_key != full_key:
		sc[1].add_child(UI.label("Carregando...", 20, UI.C_MUTED))
		_load(key, full_key)
		return
	var is_time: bool = data.get("is_time", false)
	if int(data.get("my_rank", -1)) > 0:
		b.add_child(UI.label("Sua posição: #%d (%s)" % [int(data.my_rank), _fmt(float(data.my_value), is_time)], 22, UI.C_GOLD))
	for e in data.get("entries", []):
		var row := UI.hbox(8)
		var col := UI.C_GOLD if e.me else UI.C_TEXT
		var rk := UI.label("#%d" % int(e.rank), 20, col)
		rk.custom_minimum_size = Vector2(70, 0)
		row.add_child(rk)
		row.add_child(UI.expand(UI.label(e.name, 20, col)))
		row.add_child(UI.label(_fmt(float(e.value), is_time), 20, col))
		sc[1].add_child(row)
	if data.get("entries", []).is_empty():
		sc[1].add_child(UI.label("Ninguém pontuou ainda.", 20, UI.C_MUTED))


func _fmt(v: float, is_time: bool) -> String:
	return UI.fmt_time(v) if is_time else UI.fmt(v)


func _load(key: String, full_key: String) -> void:
	await Game.cloud_sync()
	var r: Dictionary = await Backend.request("rankings", {"category": key, "period": period})
	data = r if r.get("ok", false) else {}
	loaded_key = full_key
	if is_inside_tree():
		rebuild()
