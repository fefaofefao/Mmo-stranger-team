class_name AmbientFx
extends Node2D
## Clima e luz de cada bioma: partículas que dão vida ao mapa (brasas, neve, folhas, vagalumes,
## faíscas, bolhas, poeira, penas) e uma luz ambiente suave. Fica presa à câmera.

const KINDS := {
	"ember": {"color": Color(1.0, 0.55, 0.15), "amount": 26, "vel": Vector2(0, -22), "spread": 25.0, "life": 4.0, "size": 2, "glow": true},
	"snow": {"color": Color(1, 1, 1, 0.9), "amount": 46, "vel": Vector2(-6, 24), "spread": 18.0, "life": 7.0, "size": 2, "glow": false},
	"leaf": {"color": Color(0.55, 0.8, 0.35), "amount": 10, "vel": Vector2(12, 16), "spread": 35.0, "life": 7.0, "size": 3, "glow": false},
	"petal": {"color": Color(1.0, 0.75, 0.85), "amount": 10, "vel": Vector2(10, 12), "spread": 40.0, "life": 7.0, "size": 2, "glow": false},
	"firefly": {"color": Color(0.85, 1.0, 0.45), "amount": 16, "vel": Vector2(0, -4), "spread": 180.0, "life": 6.0, "size": 2, "glow": true},
	"spore": {"color": Color(0.75, 0.55, 1.0), "amount": 18, "vel": Vector2(0, -6), "spread": 180.0, "life": 6.0, "size": 2, "glow": true},
	"spark": {"color": Color(1.0, 0.95, 0.45), "amount": 14, "vel": Vector2(0, 0), "spread": 180.0, "life": 0.6, "size": 2, "glow": true},
	"bubble": {"color": Color(0.8, 0.95, 1.0, 0.75), "amount": 18, "vel": Vector2(0, -18), "spread": 15.0, "life": 5.0, "size": 3, "glow": false},
	"dust": {"color": Color(0.95, 0.85, 0.7, 0.5), "amount": 14, "vel": Vector2(8, -2), "spread": 60.0, "life": 7.0, "size": 2, "glow": false},
	"feather": {"color": Color(1, 1, 1, 0.85), "amount": 9, "vel": Vector2(26, 6), "spread": 20.0, "life": 6.0, "size": 3, "glow": false},
	"twinkle": {"color": Color(1, 1, 0.85), "amount": 14, "vel": Vector2(0, 0), "spread": 180.0, "life": 1.4, "size": 2, "glow": true},
	"wisp": {"color": Color(0.7, 0.5, 1.0, 0.8), "amount": 12, "vel": Vector2(0, -8), "spread": 120.0, "life": 5.0, "size": 3, "glow": true},
}

## Bioma -> [partícula, luz ambiente]
const BIOMES := {
	"praia": ["dust", Color(1, 0.98, 0.94)], "lago": ["petal", Color(0.98, 1, 0.98)], "recife": ["bubble", Color(0.85, 0.95, 1)],
	"vulcao": ["ember", Color(1, 0.88, 0.82)], "campo_lava": ["ember", Color(1, 0.86, 0.78)], "tundra": ["snow", Color(0.95, 0.98, 1)],
	"caverna_congelada": ["snow", Color(0.85, 0.92, 1)], "campo_grama": ["petal", Color(1, 1, 0.97)], "floresta_densa": ["leaf", Color(0.88, 0.95, 0.85)],
	"canion": ["dust", Color(1, 0.94, 0.86)], "caverna_rochosa": ["dust", Color(0.86, 0.84, 0.82)], "planalto_tempestade": ["spark", Color(0.86, 0.88, 0.95)],
	"ruinas_energizadas": ["spark", Color(0.9, 0.9, 1)], "picos": ["feather", Color(0.96, 0.98, 1)], "plataformas_nuvens": ["feather", Color(1, 1, 1)],
	"templo": ["twinkle", Color(1, 0.97, 0.9)], "campo_cristais": ["twinkle", Color(1, 1, 0.95)], "floresta_sombria": ["firefly", Color(0.74, 0.78, 0.88)],
	"cemiterio": ["wisp", Color(0.76, 0.76, 0.86)], "pantano": ["firefly", Color(0.86, 0.9, 0.82)], "fontes_termais": ["bubble", Color(1, 0.96, 0.94)],
	"deserto_cinzas": ["ember", Color(0.95, 0.88, 0.84)], "geleira_rochosa": ["snow", Color(0.9, 0.94, 1)], "cordilheira_ventosa": ["feather", Color(0.95, 0.97, 1)],
	"crepusculo": ["wisp", Color(0.86, 0.8, 0.95)], "brejo_sombrio": ["spore", Color(0.74, 0.76, 0.84)], "geleira_eterea": ["twinkle", Color(0.92, 0.96, 1)],
	"tempestade_luminosa": ["spark", Color(1, 1, 0.92)],
}

static var _tex := {}

var particles: CPUParticles2D
var modulate_node: CanvasModulate


func setup(world: Node2D, camera: Camera2D, biome_id: String, corrupted: bool) -> void:
	var cfg: Array = BIOMES.get(biome_id, ["dust", Color.WHITE])
	var kind: String = cfg[0]
	var light: Color = cfg[1]
	if corrupted:
		kind = "wisp"
		light = light * Color(0.86, 0.76, 0.96)
	modulate_node = CanvasModulate.new()
	modulate_node.color = light
	world.add_child(modulate_node)
	var k: Dictionary = KINDS[kind]
	particles = CPUParticles2D.new()
	particles.texture = _particle_tex(int(k.size), bool(k.glow))
	particles.amount = int(k.amount)
	particles.lifetime = float(k.life)
	particles.preprocess = float(k.life)
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(260, 420)
	var v: Vector2 = k.vel
	particles.direction = v.normalized() if v.length() > 0.1 else Vector2.UP
	particles.spread = float(k.spread)
	particles.initial_velocity_min = v.length() * 0.6
	particles.initial_velocity_max = v.length() * 1.2 + (6.0 if v.length() < 0.1 else 0.0)
	particles.gravity = Vector2.ZERO
	particles.color = k.color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	particles.color_ramp = ramp
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	if kind in ["leaf", "petal", "feather"]:
		particles.angular_velocity_min = -90
		particles.angular_velocity_max = 90
	if bool(k.glow):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particles.material = mat
	particles.z_index = 50
	camera.add_child(particles)


static func _particle_tex(size: int, glow: bool) -> Texture2D:
	var key := "%d_%s" % [size, glow]
	if _tex.has(key):
		return _tex[key]
	var s := size * 2 + 3
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := s / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var a := 0.0
			if d <= size * 0.6:
				a = 1.0
			elif glow and d <= c:
				a = 0.35 * (1.0 - (d - size * 0.6) / (c - size * 0.6))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t
