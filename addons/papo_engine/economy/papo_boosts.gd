class_name PapoBoosts
extends RefCounted
## Potenciadores temporales por clave (segundos restantes).

var timers: Dictionary = {}


func add(key: String, seconds: float) -> void:
	timers[key] = float(timers.get(key, 0.0)) + seconds


func active(key: String) -> bool:
	return float(timers.get(key, 0.0)) > 0.0


func left(key: String) -> float:
	return float(timers.get(key, 0.0))


func mult(key: String, value: float) -> float:
	return value if active(key) else 1.0


## Devuelve true si algún potenciador terminó en este tick.
func tick(delta: float) -> bool:
	var ended := false
	for k in timers.keys():
		var t: float = timers[k]
		if t > 0.0:
			t = maxf(0.0, t - delta)
			timers[k] = t
			if t == 0.0:
				ended = true
	return ended
