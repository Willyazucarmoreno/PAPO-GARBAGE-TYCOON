class_name PapoMissions
extends RefCounted
## Misiones periódicas (diarias/semanales) generadas por fecha.
## Plantilla: {"id","text" (con %s para la meta),"stat","goal","reward"}.
## stat_reader: Callable(stat:String) -> float (contador acumulado).

var periods: Dictionary = {}


func refresh(period: String, key: String, templates: Array, count: int, stat_reader: Callable, scale: float = 1.0) -> bool:
	if periods.has(period) and periods[period].get("key", "") == key:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(period + key)
	var pool := templates.duplicate()
	var list: Array = []
	for i in mini(count, pool.size()):
		var t: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var goal := ceilf(float(t["goal"]) * scale)
		list.append({"id": t["id"], "text": String(t["text"]) % PapoFormat.num(goal), "stat": t["stat"],
			"goal": goal, "base": stat_reader.call(t["stat"]), "reward": int(t["reward"]), "claimed": false})
	periods[period] = {"key": key, "list": list}
	return true


func list(period: String) -> Array:
	return periods.get(period, {}).get("list", [])


func progress(m: Dictionary, stat_reader: Callable) -> float:
	return clampf(float(stat_reader.call(m["stat"])) - float(m["base"]), 0.0, float(m["goal"]))


func is_ready(m: Dictionary, stat_reader: Callable) -> bool:
	return not m["claimed"] and progress(m, stat_reader) >= float(m["goal"])


func claim(period: String, idx: int, stat_reader: Callable) -> int:
	var l := list(period)
	if idx < 0 or idx >= l.size() or not is_ready(l[idx], stat_reader):
		return 0
	l[idx]["claimed"] = true
	return int(l[idx]["reward"])


func ready_count(stat_reader: Callable) -> int:
	var n := 0
	for p in periods.keys():
		for m in list(p):
			if is_ready(m, stat_reader):
				n += 1
	return n
