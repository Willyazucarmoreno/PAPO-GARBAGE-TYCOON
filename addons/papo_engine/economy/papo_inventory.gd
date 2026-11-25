class_name PapoInventory
extends RefCounted
## Inventario por índices con capacidad total.

var counts: Array = []
var total: int = 0


func _init(slots: int = 0) -> void:
	counts.resize(slots)
	counts.fill(0)


func add(i: int, n: int = 1, capacity: int = 1 << 30) -> int:
	var room := maxi(0, capacity - total)
	var added := mini(n, room)
	counts[i] = int(counts[i]) + added
	total += added
	return added


func value(prices: Array) -> float:
	var v := 0.0
	for i in counts.size():
		v += float(counts[i]) * float(prices[i])
	return v


func clear() -> void:
	counts.fill(0)
	total = 0


func to_array() -> Array:
	return counts.duplicate()


func from_array(a: Array) -> void:
	clear()
	for i in mini(a.size(), counts.size()):
		counts[i] = int(a[i])
		total += int(a[i])
