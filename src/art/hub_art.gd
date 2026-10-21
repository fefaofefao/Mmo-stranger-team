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
	var w := 240
	var h := 120
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# céu em faixas
	for y in h:
		var t := float(y) / h
		var c := Color("#2a3a6a").lerp(Color("#e89a5a"), clampf(t * 1.6, 0, 1))
		for x in w:
			img.set_pixel(x, y, c)
	# montanhas
	for x in w:
		var mh := int(30 + 12 * sin(x * 0.05) + 8 * sin(x * 0.13 + 1.0))
		for y in range(h - mh - 30, h):
			img.set_pixel(x, y, Color("#3a3550"))
	# chão
	SpriteFactory.rect(img, 0, h - 28, w, 28, Color("#4a7a3a"))
	SpriteFactory.rect(img, 0, h - 14, w, 14, Color("#8a6a45"))
	# prédios: depot, loja, market, altar
	_house(img, 18, h - 28, 34, 26, Color("#7a5a3a"), Color("#a83a2a"))
	_house(img, 70, h - 28, 30, 22, Color("#8a7a5a"), Color("#3a6aa8"))
	_house(img, 122, h - 28, 40, 30, Color("#9a8a6a"), Color("#d8a83a"))
	# altar
	SpriteFactory.rect(img, 186, h - 40, 26, 12, Color("#8a8a9a"))
	SpriteFactory.rect(img, 192, h - 60, 14, 20, Color("#aaaaba"))
	SpriteFactory.ellipse(img, 199, h - 66, 6, 6, Color("#b05cff"))
	SpriteFactory.ellipse(img, 199, h - 66, 3, 3, Color("#f0d0ff"))
	# estrelas
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 30:
		img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, 30), Color(1, 1, 0.9, rng.randf_range(0.4, 1)))
	# pequenos monstros
	for i in 3:
		var fid: String = ["fogo_1_1", "agua_1_1", "planta_1_1"][i]
		var fr: Image = SpriteFactory.generate_sheet(fid).get_region(Rect2i(0, 0, 48, 48))
		fr.resize(24, 24, Image.INTERPOLATE_NEAREST)
		img.blend_rect(fr, Rect2i(0, 0, 24, 24), Vector2i(40 + i * 60, h - 36))
	_tex = ImageTexture.create_from_image(img)
	return _tex


static func _house(img: Image, x: int, base_y: int, w: int, h: int, wall: Color, roof: Color) -> void:
	SpriteFactory.rect(img, x, base_y - h, w, h, wall)
	SpriteFactory.tri(img, Vector2(x - 3, base_y - h), Vector2(x + w + 3, base_y - h), Vector2(x + w / 2.0, base_y - h - 12), roof)
	SpriteFactory.rect(img, x + w / 2.0 - 3, base_y - 10, 6, 10, Color("#3a2a1a"))
	SpriteFactory.rect(img, x + 4, base_y - h + 5, 5, 5, Color("#ffe8a0"))
	SpriteFactory.rect(img, x + w - 9, base_y - h + 5, 5, 5, Color("#ffe8a0"))
