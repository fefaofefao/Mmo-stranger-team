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
