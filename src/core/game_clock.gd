class_name GameClock
extends RefCounted
## Relógio do jogo. Em build debug o "acelerar tempo" soma um deslocamento, para que o servidor mock
## e os timers baseados em data (boosts, cooldowns, offline) avancem junto.

static var offset := 0.0


static func now() -> float:
	return Time.get_unix_time_from_system() + offset
