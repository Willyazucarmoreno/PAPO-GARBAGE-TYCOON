class_name PapoLevels
extends RefCounted
## Nivel y experiencia con curva exponencial.

signal leveled_up(level: int)

var level: int = 1
var xp: float = 0.0
var base: float = 40.0
var growth: float = 1.32


func need() -> float:
	return floor(base * pow(growth, level - 1))


func add_xp(v: float) -> int:
	xp += v
	var gained := 0
	while xp >= need():
		xp -= need()
		level += 1
		gained += 1
		leveled_up.emit(level)
	return gained


func progress() -> float:
	return clampf(xp / need(), 0.0, 1.0)
