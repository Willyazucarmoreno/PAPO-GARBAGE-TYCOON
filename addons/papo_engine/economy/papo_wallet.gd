class_name PapoWallet
extends RefCounted
## Monedas virtuales genéricas (sin valor real).

signal changed(id: String, value: float)

var values: Dictionary = {}


func _init(ids: Array = []) -> void:
	for id in ids:
		values[id] = 0.0


func get_v(id: String) -> float:
	return float(values.get(id, 0.0))


func add(id: String, amount: float) -> void:
	values[id] = get_v(id) + amount
	changed.emit(id, values[id])


func can_pay(id: String, amount: float) -> bool:
	return get_v(id) >= amount


func spend(id: String, amount: float) -> bool:
	if not can_pay(id, amount):
		return false
	add(id, -amount)
	return true


func to_dict() -> Dictionary:
	return values.duplicate()


func from_dict(d: Dictionary) -> void:
	for k in d.keys():
		values[k] = float(d[k])
