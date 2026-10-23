extends Screen
## Loja de diamantes (dinheiro real via Google Play). Diamantes compram bônus e monstros no Market.


func build() -> void:
	var b := make_layout(Loc.t("Diamantes"), "diamond")
	var head := UI.panel("panel_gold")
	b.add_child(head)
	var hv := UI.hbox(10)
	head.add_child(hv)
	hv.add_child(UI.icon("diamond", 64))
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(col)
	col.add_child(UI.label(Loc.t("Você tem %s diamantes") % UI.fmt(Game.save.get("diamonds", 0)), 24, Color("#7fe8ff")))
	col.add_child(UI.label(Loc.t("Use em Bônus (2x XP, shiny, recrutamento, drop, ouro) e para comprar monstros de outros jogadores no Market."), 16, UI.C_MUTED, true))
	if int(Game.save.get("purchases", 0)) == 0 and float(DataDB.iap.get("first_purchase_bonus", 0)) > 0:
		var fb := UI.card(true)
		fb.add_child(UI.label(Loc.t("Primeira compra: diamantes em DOBRO!"), 20, UI.C_GOLD))
		b.add_child(fb)
	if Billing.simulated:
		b.add_child(UI.label(Loc.t("[Modo de teste: compras simuladas, sem cobrança]"), 15, UI.C_BAD))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	for pr in Billing.products():
		if pr.get("kind", "") == "no_ads":
			sc[1].add_child(_no_ads_card(pr))
	var g := UI.grid(2, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc[1].add_child(g)
	for pr in Billing.products():
		if pr.get("kind", "") != "no_ads":
			g.add_child(_pack(pr))
	sc[1].add_child(UI.label(Loc.t("Pagamento processado pelo Google Play. Diamantes não podem ser trocados por ouro nem por dinheiro."), 14, UI.C_MUTED, true))
	if not Billing.prices_updated.is_connected(rebuild):
		Billing.prices_updated.connect(rebuild)


## "Sem anúncios": compra única que remove os anúncios em tela cheia (o banner continua).
func _no_ads_card(pr: Dictionary) -> Control:
	var owned: bool = Game.save.get("no_ads", false)
	var p := UI.card(not owned)
	var h := UI.hbox(10)
	p.add_child(h)
	h.add_child(UI.icon("lock" if not owned else "check", 52))
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	col.add_child(UI.label(Loc.t("Sem anúncios"), 22, UI.C_GOLD))
	col.add_child(UI.label(Loc.t("Remove os anúncios em tela cheia para sempre. O banner continua e os anúncios premiados (bônus de 15 min) seguem opcionais."), 15, UI.C_MUTED, true))
	if owned:
		h.add_child(UI.pill(Loc.t("Ativo"), UI.C_GOOD, 18))
	else:
		var pid: String = pr.id
		var bt := UI.button(Billing.price_text(pr), func(): _buy(pid), 20, 58, "primary")
		bt.custom_minimum_size = Vector2(170, 58)
		h.add_child(bt)
	return p


func _pack(pr: Dictionary) -> Control:
	var p := UI.card(str(pr.get("tag", "")) != "")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	p.add_child(v)
	var ic := UI.icon("diamond", 40 + mini(40, int(pr.diamonds) / 300))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var al := UI.label(UI.fmt(int(pr.diamonds)), 26, Color("#7fe8ff"))
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(al)
	var bonus := int(pr.get("bonus", 0))
	var bl := UI.label(Loc.t("+%s de bônus") % UI.fmt(bonus) if bonus > 0 else " ", 16, UI.C_GOOD)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bl)
	if str(pr.get("tag", "")) != "":
		var t := UI.pill(Loc.t(pr.tag), UI.C_GOLD, 14)
		t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(t)
	var pid: String = pr.id
	var bt := UI.button(Billing.price_text(pr), func(): _buy(pid), 20, 58, "primary")
	v.add_child(bt)
	return p


func _buy(pid: String) -> void:
	var r: Dictionary = await Billing.buy(pid)
	if r.get("ok", false) and r.get("no_ads", false):
		toast(Loc.t("Sem anúncios ativado! Obrigado pelo apoio!"), UI.C_GOOD, "check")
	elif r.get("ok", false):
		toast(Loc.t("+%s diamantes! Obrigado pelo apoio!") % UI.fmt(r.diamonds_gained), Color("#7fe8ff"), "diamond")
		Game.save.purchases = int(Game.save.get("purchases", 0)) + 1
	elif str(r.get("error", "")) != "":
		toast(Loc.t(r.error), UI.C_BAD)
	rebuild()
