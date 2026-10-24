extends Node
## Autoload "Ads": banner inferior, rewarded opcionais e interstitial com limite de frequência.
## Com o plugin AdMob instalado (Android + build gradle) usa anúncios reais/de teste do Google;
## sem o plugin, usa um modo simulado (overlay "ANÚNCIO DE TESTE") para testar todo o fluxo.

signal banner_visibility_changed(visible: bool, height: float)
signal consent_finished

const BANNER_HEIGHT := 100.0  # ~50dp na resolução base (720 de largura)

var adapter: AdMobAdapter = null
var simulated := true
var banner_wanted := false
var ready_ads := false
var context := ""  # "challenge", "offline_summary", etc. bloqueiam interstitial
var _overlay_parent: Node = null
var _last_interstitial := -1e9


func _ready() -> void:
	DataDB.ensure_loaded()
	_last_interstitial = -float(DataDB.config.ads.interstitial_min_seconds) + 60.0


func ids() -> Dictionary:
	var cfg: Dictionary = DataDB.ads_cfg
	var real: Dictionary = cfg.get("real", {})
	if not cfg.get("use_test_ids", true) and str(real.get("banner", "")) != "":
		return real
	return cfg.get("android", {})


func init_ads(overlay_parent: Node) -> void:
	_overlay_parent = overlay_parent
	if AdMobAdapter.available():
		simulated = false
		adapter = AdMobAdapter.new()
		adapter.setup(ids(), bool(DataDB.ads_cfg.get("tag_for_under_age_of_consent", false)),
			DataDB.ads_cfg.get("test_device_ids", []), func(ok):
				ready_ads = ok
				if ok:
					adapter.load_rewarded()
					adapter.load_interstitial()
					if banner_wanted:
						adapter.show_banner()
				consent_finished.emit())
	else:
		simulated = true
		ready_ads = true
		if not Game.save.settings.get("consent_answered", false):
			await _simulated_consent()
		consent_finished.emit()


func _simulated_consent() -> void:
	var dlg := UI.dialog(_overlay_parent, Loc.t("Privacidade"),
		Loc.t("Este jogo exibe anúncios. Em produção, o formulário oficial de consentimento do Google (UMP) aparece aqui para usuários do EEE/Reino Unido.") + "\n\n" + Loc.t("[Modo simulado: plugin AdMob ausente]"),
		[Loc.t("Aceitar"), Loc.t("Recusar personalização")], "lock")
	var choice: int = await dlg.chosen
	Game.save.settings["consent_answered"] = true
	Game.save.settings["consent_personalized"] = choice == 0
	Game.save_local()


func show_banner() -> void:
	banner_wanted = true
	if adapter:
		adapter.show_banner()
	banner_visibility_changed.emit(true, BANNER_HEIGHT)


func hide_banner() -> void:
	banner_wanted = false
	if adapter:
		adapter.hide_banner()
	banner_visibility_changed.emit(false, 0.0)


## Interstitial: no máximo 1 a cada N minutos e nunca em desafio ou no resumo offline.
func maybe_interstitial() -> void:
	if context in ["challenge", "offline_summary"]:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_interstitial < float(DataDB.config.ads.interstitial_min_seconds):
		return
	_last_interstitial = now
	if adapter:
		adapter.show_interstitial()
	elif _overlay_parent:
		await _simulated_fullscreen(Loc.t("ANÚNCIO DE TESTE"), 2.0, true)


func can_interstitial_now() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return not context in ["challenge", "offline_summary"] and now - _last_interstitial >= float(DataDB.config.ads.interstitial_min_seconds)


## Anúncio premiado. Retorna true se a recompensa deve ser concedida.
func show_rewarded(reason: String) -> bool:
	if Game.save.get("vip", false):
		return true  # Passe VIP: recompensa sem assistir o vídeo
	if adapter:
		var result := [null]
		adapter.show_rewarded(func(ok): result[0] = ok)
		while result[0] == null:
			await get_tree().process_frame
		return result[0]
	return await _simulated_fullscreen(Loc.t("ANÚNCIO PREMIADO DE TESTE") + "\n" + reason, 3.0, false)


func _simulated_fullscreen(text: String, seconds: float, skippable: bool) -> bool:
	if _overlay_parent == null:
		return true
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, 0.92)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_parent.add_child(layer)
	var lbl := UI.label(text, 30, Color(1, 0.9, 0.5))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(lbl)
	var t := seconds
	while t > 0.0:
		lbl.text = "%s\n\n%d" % [text, int(ceil(t))]
		await get_tree().create_timer(0.25).timeout
		t -= 0.25
	layer.queue_free()
	return true
