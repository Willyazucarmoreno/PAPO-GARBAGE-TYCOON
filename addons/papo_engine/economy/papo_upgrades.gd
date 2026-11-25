class_name PapoUpgrades
extends RefCounted
## Niveles de mejora con coste exponencial.

var levels: Dictionary = {}


static func cost(base: float, growth: float, level: int) -> float:
	return floor(base * pow(growth, level))


func lvl(id: String) -> int:
	return int(levels.get(id, 0))


func buy(id: String, def: Dictionary, wallet: PapoWallet, currency: String = "money") -> bool:
	if lvl(id) >= int(def.get("max", 999)):
		return false
	if not wallet.spend(currency, cost(float(def["base"]), float(def["growth"]), lvl(id))):
		return false
	levels[id] = lvl(id) + 1
	return true
