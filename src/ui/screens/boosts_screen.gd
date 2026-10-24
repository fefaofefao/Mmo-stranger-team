extends Screen
## Bônus temporários: 2x XP, 2x shiny, 2x recrutamento, 2x drop, 2x ouro.
## Cada um: 8 h por diamantes ou 15 min assistindo a um anúncio (acumula).

const NAMES := {
	"xp": ["2x XP", "Todos os monstros do grupo ganham o dobro de XP."],
	"shiny": ["2x Shiny", "Dobra a chance de aparecer monstro shiny na caçada."],
	"recruit": ["2x Recrutamento", "Dobra a chance de recrutar o monstro abatido."],
	"drop": ["2x Drop", "Dobra a chance de itens caírem."],
	"gold": ["2x Ouro", "Dobra o ouro de cada abate."],
}

var busy := false
var timers := {}


func build() -> void:
	var b := make_layout(Loc.t("Bônus"), "boost")
	var cfg: Dictionary = DataDB.config.boosts
	var top := UI.hbox(8)
	b.add_child(top)
	var dl := UI.chip("diamond", UI.fmt(Game.save.get("diamonds", 0)), Color("#7fe8ff"), 20)
	top.add_child(dl)
	top.add_child(UI.hspace())
	top.add_child(UI.icon_button("plus", Loc.t("Diamantes"), func(): main.goto("diamonds"), 18, 56))
	b.add_child(UI.label(Loc.t("Diamantes: %d horas. Anúncio: %d minutos grátis (acumula até %d min).") % [int(cfg.diamond_hours), int(cfg.ad_minutes), int(cfg.ad_max_minutes)], 16, UI.C_MUTED, true))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	timers.clear()
	for k in cfg.kinds:
		sc[1].add_child(_card(k, cfg))
	# pacote
	var p := UI.card(true)
	var row := UI.hbox(10)
	p.add_child(row)
	row.add_child(UI.icon("crown", 48))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UI.label(Loc.t("Pacote completo"), 22, UI.C_GOLD))
	v.add_child(UI.label(Loc.t("Todos os 5 bônus por %d horas.") % int(cfg.diamond_hours), 16, UI.C_MUTED, true))
	var bb := UI.icon_button("diamond", UI.fmt(cfg.bundle_price), func(): _buy("all", int(cfg.bundle_price)), 20, 60, "primary")
	bb.custom_minimum_size = Vector2(150, 60)
	row.add_child(bb)
	sc[1].add_child(p)
	_tick()


func _card(k: String, cfg: Dictionary) -> Control:
	var kc: Dictionary = cfg.kinds[k]
	var active := Game.boost_active(k)
	var p := UI.card(active)
	var row := UI.hbox(10)
	p.add_child(row)
	row.add_child(UI.icon(kc.icon, 48))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UI.label(Loc.t(NAMES[k][0]), 22, UI.C_GOLD if active else UI.C_TEXT))
	v.add_child(UI.label(Loc.t(NAMES[k][1]), 15, UI.C_MUTED, true))
	var tl := UI.label("", 16, UI.C_GOOD)
	v.add_child(tl)
	timers[k] = tl
	var bc := UI.vbox(6)
	row.add_child(bc)
	var bd := UI.icon_button("diamond", "%s · %dh" % [UI.fmt(kc.price), int(cfg.diamond_hours)], func(): _buy(k, int(kc.price)), 17, 54, "primary")
	bd.custom_minimum_size = Vector2(170, 54)
	bc.add_child(bd)
	var vip: bool = Game.save.get("vip", false)
	var ba := UI.icon_button("vip" if vip else "play", (Loc.t("VIP · %d min") if vip else Loc.t("Anúncio · %d min")) % int(cfg.ad_minutes), func(): _ad(k), 17, 54, "ad")
	ba.custom_minimum_size = Vector2(170, 54)
	bc.add_child(ba)
	return p


func _process(_d: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_tick()


func _tick() -> void:
	for k in timers:
		var l: Label = timers[k]
		if not is_instance_valid(l):
			continue
		var left := Game.boost_remaining(k)
		l.text = Loc.t("Ativo: %s restantes") % UI.fmt_time(left) if left > 0 else Loc.t("Inativo")
		l.add_theme_color_override("font_color", UI.C_GOOD if left > 0 else UI.C_MUTED)


func _buy(k: String, price: int) -> void:
	if busy:
		return
	if int(Game.save.get("diamonds", 0)) < price:
		if await main.confirm(Loc.t("Diamantes insuficientes"), Loc.t("Você precisa de %s diamantes. Ver pacotes de diamantes?") % UI.fmt(price), Loc.t("Ver pacotes"), Loc.t("Agora não")):
			main.goto("diamonds")
		return
	var nm: String = Loc.t("Pacote completo") if k == "all" else Loc.t(NAMES[k][0])
	if not await main.confirm(nm, Loc.t("Ativar %s por %d horas por %s diamantes?") % [nm, int(DataDB.config.boosts.diamond_hours), UI.fmt(price)]):
		return
	busy = true
	var r: Dictionary = await Game.buy_boost(k)
	busy = false
	toast(Loc.t("%s ativado!") % nm if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOOD if r.get("ok", false) else UI.C_BAD, "boost")
	rebuild()


func _ad(k: String) -> void:
	if busy:
		return
	busy = true
	var r: Dictionary = await Game.ad_boost(k)
	busy = false
	if r.get("ok", false):
		toast(Loc.t("+%d min de %s!") % [int(DataDB.config.boosts.ad_minutes), Loc.t(NAMES[k][0])], UI.C_GOOD, "boost")
	elif str(r.get("error", "")) != "":
		toast(Loc.t(r.error), UI.C_BAD)
	rebuild()
