class_name PapoRoster
extends RefCounted
## Plantilla de trabajadores genérica: [{type, level, expires?}].

var list: Array = []


func count(type_id: String) -> int:
	var c := 0
	for w in list:
		if w["type"] == type_id and not w.has("expires"):
			c += 1
	return c


func sum_levels(type_id: String) -> int:
	var s := 0
	for w in list:
		if w["type"] == type_id:
			s += int(w["level"])
	return s


static func hire_cost(base: float, owned: int, growth: float = 1.4) -> float:
	return floor(base * pow(growth, owned))


static func level_cost(base: float, level: int) -> float:
	return floor(base * 0.6 * pow(1.55, level))


func add(type_id: String, level: int = 1, temp_seconds: float = 0.0) -> Dictionary:
	var w := {"type": type_id, "level": level}
	if temp_seconds > 0.0:
		w["expires"] = Time.get_unix_time_from_system() + temp_seconds
	list.append(w)
	return w


## Elimina temporales caducados; devuelve true si hubo cambios.
func purge_expired() -> bool:
	var now := Time.get_unix_time_from_system()
	var before := list.size()
	list = list.filter(func(w: Dictionary) -> bool: return not w.has("expires") or float(w["expires"]) > now)
	return list.size() != before
