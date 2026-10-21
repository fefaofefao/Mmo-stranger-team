class_name AdMobAdapter
extends RefCounted
## Adaptador para o plugin "Godot AdMob" da Poing Studios (API v3.x, Godot 4).
## O plugin é acessado dinamicamente (por nome de classe global) para que o projeto compile e rode
## mesmo sem o addon instalado — nesse caso Ads usa o modo simulado (ver PENDENCIAS.md).

var ids: Dictionary = {}
var banner = null
var interstitial = null
var rewarded = null
var initialized := false
var consent_ok := true
var _classes := {}


static func available() -> bool:
	return Engine.has_singleton("PoingGodotAdMob") and _find_class("MobileAds") != ""


static func _find_class(n: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == n:
			return c["path"]
	return ""


func _cls(n: String):
	if not _classes.has(n):
		var p := _find_class(n)
		_classes[n] = load(p) if p != "" else null
	return _classes[n]


func _const(cls_name: String, path: Array):
	var s = _cls(cls_name)
	if s == null:
		return null
	var v = s.get_script_constant_map()
	for k in path:
		if v is Dictionary and v.has(k):
			v = v[k]
		else:
			return s.get(path[0]) if path.size() == 1 else null
	return v


func setup(p_ids: Dictionary, under_age: bool, test_devices: Array, on_ready: Callable) -> void:
	ids = p_ids
	# 1) consentimento GDPR via UMP
	var ump = _cls("UserMessagingPlatform")
	var params_cls = _cls("ConsentRequestParameters")
	if ump and params_cls:
		var params = params_cls.new()
		params.tag_for_under_age_of_consent = under_age
		var info = ump.consent_information
		info.update(params, func():
			ump.load_and_show_consent_form_if_required(func(_err = null):
				_init_ads(test_devices, on_ready)),
			func(_err = null):
				_init_ads(test_devices, on_ready))
	else:
		_init_ads(test_devices, on_ready)


func _init_ads(test_devices: Array, on_ready: Callable) -> void:
	var mobile_ads = _cls("MobileAds")
	if mobile_ads == null:
		on_ready.call(false)
		return
	var rc_cls = _cls("RequestConfiguration")
	if rc_cls and not test_devices.is_empty():
		var rc = rc_cls.new()
		rc.test_device_ids = test_devices
		mobile_ads.set_request_configuration(rc)
	mobile_ads.initialize()
	initialized = true
	on_ready.call(true)


func show_banner() -> void:
	if not initialized:
		return
	if banner == null:
		var adview = _cls("AdView")
		var adsize = _cls("AdSize")
		var req = _cls("AdRequest")
		if adview == null or adsize == null or req == null:
			return
		var bottom = _const("AdPosition", ["Values", "BOTTOM"])
		banner = adview.new(ids.banner, adsize.BANNER, bottom if bottom != null else 1)
		banner.load_ad(req.new())
	banner.show()


func hide_banner() -> void:
	if banner:
		banner.hide()


func load_interstitial() -> void:
	var loader_cls = _cls("InterstitialAdLoader")
	var cb_cls = _cls("InterstitialAdLoadCallback")
	var req = _cls("AdRequest")
	if loader_cls == null or cb_cls == null:
		return
	var cb = cb_cls.new()
	cb.on_ad_loaded = func(ad): interstitial = ad
	cb.on_ad_failed_to_load = func(_e): interstitial = null
	loader_cls.new().load(ids.interstitial, req.new(), cb)


func show_interstitial() -> bool:
	if interstitial == null:
		load_interstitial()
		return false
	interstitial.show()
	interstitial = null
	load_interstitial()
	return true


func load_rewarded() -> void:
	var loader_cls = _cls("RewardedAdLoader")
	var cb_cls = _cls("RewardedAdLoadCallback")
	var req = _cls("AdRequest")
	if loader_cls == null or cb_cls == null:
		return
	var cb = cb_cls.new()
	cb.on_ad_loaded = func(ad): rewarded = ad
	cb.on_ad_failed_to_load = func(_e): rewarded = null
	loader_cls.new().load(ids.rewarded, req.new(), cb)


## on_reward(bool) é chamado quando o usuário ganha a recompensa (true) ou o anúncio falha (false).
func show_rewarded(on_reward: Callable) -> void:
	if rewarded == null:
		load_rewarded()
		on_reward.call(false)
		return
	var listener_cls = _cls("OnUserEarnedRewardListener")
	var listener = listener_cls.new() if listener_cls else null
	var earned := [false]
	if listener:
		listener.on_user_earned_reward = func(_item): earned[0] = true
	var fsc_cls = _cls("FullScreenContentCallback")
	if fsc_cls:
		var fsc = fsc_cls.new()
		fsc.on_ad_dismissed_full_screen_content = func(): on_reward.call(earned[0])
		fsc.on_ad_failed_to_show_full_screen_content = func(_e): on_reward.call(false)
		rewarded.full_screen_content_callback = fsc
	rewarded.show(listener)
	rewarded = null
	load_rewarded()
