class_name HubArt
extends RefCounted
## Ilustração pixel art do Hub (gerada por código; substituível por res://assets/ui/hub.png).

static var _tex: Texture2D


static func texture() -> Texture2D:
	if _tex:
		return _tex
	if ResourceLoader.exists("res://assets/ui/hub.png"):
		_tex = load("res://assets/ui/hub.png")
		return _tex
	# cenário panorâmico baixo (os monstros do grupo são desenhados por cima, grandes, pela tela do Hub)
	var w := 240
	var h := 76
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / h
		var c := Color("#1e2a52").lerp(Color("#f0a060"), clampf(t * 1.5, 0, 1))
		for x in w:
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 26:
		img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, 22), Color(1, 1, 0.9, rng.randf_range(0.4, 1)))
	SpriteFactory.ellipse(img, 196, 20, 7, 7, Color("#fff0c0"))
	for x in w:
		var mh := int(20 + 8 * sin(x * 0.05) + 5 * sin(x * 0.13 + 1.0))
		for y in range(h - mh - 18, h):
			img.set_pixel(x, y, Color("#3a3550"))
		var mh2 := int(12 + 5 * sin(x * 0.08 + 2.0))
		for y in range(h - mh2 - 18, h):
			img.set_pixel(x, y, Color("#2e4a40"))
	SpriteFactory.rect(img, 0, h - 18, w, 18, Color("#4a7a3a"))
	SpriteFactory.rect(img, 0, h - 18, w, 2, Color("#6a9a4a"))
	SpriteFactory.rect(img, 0, h - 8, w, 8, Color("#8a6a45"))
	_house(img, 6, h - 18, 26, 18, Color("#7a5a3a"), Color("#a83a2a"))
	_house(img, 44, h - 18, 22, 15, Color("#8a7a5a"), Color("#3a6aa8"))
	_house(img, 172, h - 18, 30, 20, Color("#9a8a6a"), Color("#d8a83a"))
	SpriteFactory.rect(img, 214, h - 26, 20, 8, Color("#8a8a9a"))
	SpriteFactory.rect(img, 219, h - 40, 10, 14, Color("#aaaaba"))
	SpriteFactory.ellipse(img, 224, h - 45, 5, 5, Color("#b05cff"))
	SpriteFactory.ellipse(img, 224, h - 45, 2, 2, Color("#f0d0ff"))
	_tex = ImageTexture.create_from_image(img)
	return _tex


static func _house(img: Image, x: int, base_y: int, w: int, h: int, wall: Color, roof: Color) -> void:
	SpriteFactory.rect(img, x, base_y - h, w, h, wall)
	SpriteFactory.tri(img, Vector2(x - 3, base_y - h), Vector2(x + w + 3, base_y - h), Vector2(x + w / 2.0, base_y - h - 9), roof)
	SpriteFactory.rect(img, x + w / 2.0 - 3, base_y - 8, 6, 8, Color("#3a2a1a"))
	SpriteFactory.rect(img, x + 3, base_y - h + 4, 4, 4, Color("#ffe8a0"))
	SpriteFactory.rect(img, x + w - 7, base_y - h + 4, 4, 4, Color("#ffe8a0"))


static var _title_tex: Texture2D


## Cena vertical da tela inicial (180x320, ampliada 4x): céu do anoitecer, lua, montanhas em camadas,
## vila com janelas acesas e colina gramada onde os monstros desfilam.
static func title_texture() -> Texture2D:
	if _title_tex:
		return _title_tex
	if ResourceLoader.exists("res://assets/ui/title.png"):
		_title_tex = load("res://assets/ui/title.png")
		return _title_tex
	var w := 180
	var h := 320
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var top := Color("#0d1030")
	var mid := Color("#3a2a6a")
	var low := Color("#f08a5a")
	for y in h:
		var t := float(y) / 200.0
		var c := top.lerp(mid, clampf(t * 1.4, 0, 1)) if t < 0.7 else mid.lerp(low, clampf((t - 0.7) / 0.35, 0, 1))
		for x in w:
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 90:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, 150)
		var a := rng.randf_range(0.3, 1.0)
		img.set_pixel(x, y, Color(1, 1, 0.92, a))
		if a > 0.92:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				SpriteFactory._px(img, x + d.x, y + d.y, Color(1, 1, 0.9, 0.45))
	# lua com halo
	for r in range(26, 12, -2):
		SpriteFactory.ellipse(img, 132, 58, r, r, Color(1, 0.95, 0.8, 0.035))
	SpriteFactory.ellipse(img, 132, 58, 12, 12, Color("#fff4cc"))
	SpriteFactory.ellipse(img, 128, 55, 3, 2, Color("#efe2b0"))
	SpriteFactory.ellipse(img, 136, 62, 2, 2, Color("#efe2b0"))
	# montanhas em 3 camadas
	var layers := [[Color("#3a3366"), 175, 38.0, 0.03], [Color("#2b2850"), 195, 30.0, 0.05], [Color("#1f2a3a"), 215, 22.0, 0.08]]
	for L in layers:
		for x in w:
			var mh := int(float(L[2]) * (0.6 + 0.4 * sin(x * float(L[3]) + float(L[1]))) + 6 * sin(x * 0.17 + float(L[1])))
			for y in range(int(L[1]) - mh, h):
				img.set_pixel(x, y, L[0])
	# vila na encosta
	var houses := [[18, 222, 16, 12, Color("#5a3f2a"), Color("#9a3a2a")], [40, 226, 12, 9, Color("#6a5a40"), Color("#3a5a9a")],
		[128, 224, 18, 13, Color("#6a5a40"), Color("#c89a3a")], [152, 228, 12, 9, Color("#5a3f2a"), Color("#9a3a2a")]]
	for hh in houses:
		_house(img, hh[0], hh[1], hh[2], hh[3], hh[4], hh[5])
	# torre do altar com brilho
	SpriteFactory.rect(img, 96, 196, 8, 30, Color("#6a6a80"))
	for r in range(10, 3, -2):
		SpriteFactory.ellipse(img, 100, 192, r, r, Color(0.75, 0.4, 1.0, 0.06))
	SpriteFactory.ellipse(img, 100, 192, 4, 4, Color("#c58aff"))
	# colina gramada em primeiro plano
	for x in w:
		var gy := int(244 + 6 * sin(x * 0.035 + 1.2))
		for y in range(gy, h):
			var c := Color("#3f7a35") if y < gy + 3 else Color("#2f5f2a").lerp(Color("#1a2a18"), clampf(float(y - gy) / 70.0, 0, 1))
			img.set_pixel(x, y, c)
		if x % 3 == 0:
			SpriteFactory._px(img, x, gy - 1, Color("#5a9a45"))
	_title_tex = ImageTexture.create_from_image(img)
	return _title_tex
