extends Node
## Estado de la partida, economía, guardado automático y ganancias offline.

signal changed
signal toast(text: String)
signal sold(amount: float, at: Vector3)
signal tier_changed
signal zones_changed
signal workers_changed

const SAVE_PATH := "user://papo_save.json"
const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 10.0
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0

var money: float = 0.0
var eco: int = 0
var tier: int = 0
var upgrades: Dictionary = {}
var workers: Array = []          # [{"type": String, "level": int}]
var zones_unlocked: int = 1
var bag: Array = []              # cantidad por material
var bag_count: int = 0
var stats: Dictionary = {"collected": 0, "earned": 0.0, "sales": 0, "ads": 0}
var claimed: Array = []
var boost_time: float = 0.0
var ad_cooldown: float = 0.0
var pending_offline: float = 0.0
var tutorial_done: bool = false

var _save_timer: float = 0.0
var _bag_full_warned: bool = false


func _ready() -> void:
	_reset_values()
	load_game()


func _reset_values() -> void:
	money = 0.0
	eco = 0
	tier = 0
	upgrades = {}
	for u in GameData.UPGRADES:
		upgrades[u["id"]] = 0
	workers = []
	zones_unlocked = 1
	bag = []
	bag.resize(GameData.MATERIALS.size())
	bag.fill(0)
	bag_count = 0
	stats = {"collected": 0, "earned": 0.0, "sales": 0, "ads": 0}
	claimed = []
	boost_time = 0.0
	ad_cooldown = 0.0
	pending_offline = 0.0
	tutorial_done = false


# ---------------------------------------------------------------- cálculos

func lvl(id: String) -> int:
	return int(upgrades.get(id, 0))


func tier_def() -> Dictionary:
	return GameData.TIERS[tier]


func capacity() -> int:
	return int(round(float(tier_def()["cap"]) * (1.0 + 0.10 * lvl("capacidad"))))


func move_speed() -> float:
	return float(tier_def()["speed"]) * (1.0 + 0.05 * lvl("velocidad"))


func collect_radius() -> float:
	return float(tier_def()["radius"])


func _sum_levels(kind_id: String) -> int:
	var s := 0
	for w in workers:
		if w["type"] == kind_id:
			s += int(w["level"])
	return s


func count_workers(type_id: String) -> int:
	var c := 0
	for w in workers:
		if w["type"] == type_id:
			c += 1
	return c


func boost_mult() -> float:
	return 2.0 if boost_time > 0.0 else 1.0


func sell_multiplier() -> float:
	return float(tier_def()["sell"]) * (1.0 + 0.08 * lvl("precio")) \
		* (1.0 + 0.04 * _sum_levels("clasificador")) * boost_mult()


func passive_income() -> float:
	var base := float(tier_def()["passive"]) + 3.0 * _sum_levels("operador")
	return base * (1.0 + 0.15 * lvl("produccion")) * (1.0 + 0.10 * _sum_levels("gerente")) * boost_mult()


func worker_speed_mult() -> float:
	return (1.0 + 0.08 * lvl("automatizacion")) * (1.0 + 0.08 * _sum_levels("supervisor"))


func worker_capacity_mult() -> float:
	return 1.0 + 0.20 * lvl("almacen")


func worker_speed(w: Dictionary) -> float:
	var d := GameData.worker_def(w["type"])
	return float(d["speed"]) * (1.0 + 0.06 * (int(w["level"]) - 1)) * worker_speed_mult()


func worker_capacity(w: Dictionary) -> int:
	var d := GameData.worker_def(w["type"])
	return int(round(float(d["cap"]) * (1.0 + 0.15 * (int(w["level"]) - 1)) * worker_capacity_mult()))


func bag_value() -> float:
	var v := 0.0
	for i in bag.size():
		v += float(bag[i]) * float(GameData.MATERIALS[i]["price"])
	return v


func has_manager() -> bool:
	return count_workers("gerente") > 0


func sell_points_everywhere() -> bool:
	return tier >= GameData.TIER_SELL_POINTS_EVERYWHERE


# ---------------------------------------------------------------- acciones

func add_money(v: float) -> void:
	money += v
	stats["earned"] = float(stats["earned"]) + v


func add_to_bag(mat: int) -> bool:
	if bag_count >= capacity():
		return false
	bag[mat] = int(bag[mat]) + 1
	bag_count += 1
	stats["collected"] = int(stats["collected"]) + 1
	_bag_full_warned = false
	if bag_count >= capacity():
		_on_bag_full()
	changed.emit()
	return true


func _on_bag_full() -> void:
	if lvl("automatizacion") >= 1:
		var v := sell_bag(Vector3.ZERO, 0.8)
		toast.emit("Venta remota automática: +$%s" % GameData.fmt(v))
	elif not _bag_full_warned:
		_bag_full_warned = true
		toast.emit("¡Carga llena! Ve a un punto de venta verde.")


func sell_bag(at: Vector3, factor: float = 1.0) -> float:
	if bag_count <= 0:
		return 0.0
	var v := bag_value() * sell_multiplier() * factor
	add_money(v)
	bag.fill(0)
	bag_count = 0
	stats["sales"] = int(stats["sales"]) + 1
	sold.emit(v, at)
	changed.emit()
	return v


func worker_deposit(raw_value: float, at: Vector3) -> void:
	var v := raw_value * sell_multiplier()
	add_money(v)
	sold.emit(v, at)
	changed.emit()


func next_tier_cost() -> float:
	if tier + 1 >= GameData.TIERS.size():
		return -1.0
	return float(GameData.TIERS[tier + 1]["cost"])


func buy_next_tier() -> bool:
	var c := next_tier_cost()
	if c < 0.0 or money < c:
		return false
	money -= c
	tier += 1
	toast.emit("¡Nuevo: %s!" % GameData.TIERS[tier]["name"])
	tier_changed.emit()
	changed.emit()
	save_game()
	return true


func upgrade_cost(id: String) -> float:
	var d := GameData.upgrade_def(id)
	return floor(float(d["base"]) * pow(float(d["growth"]), lvl(id)))


func upgrade_maxed(id: String) -> bool:
	return lvl(id) >= int(GameData.upgrade_def(id)["max"])


func buy_upgrade(id: String) -> bool:
	if upgrade_maxed(id):
		return false
	var c := upgrade_cost(id)
	if money < c:
		return false
	money -= c
	upgrades[id] = lvl(id) + 1
	changed.emit()
	return true


func hire_cost(type_id: String) -> float:
	var d := GameData.worker_def(type_id)
	return floor(float(d["cost"]) * pow(1.4, count_workers(type_id)))


func can_hire(type_id: String) -> bool:
	var d := GameData.worker_def(type_id)
	return tier >= int(d["req_tier"]) and count_workers(type_id) < GameData.MAX_WORKERS_PER_TYPE


func hire(type_id: String) -> bool:
	if not can_hire(type_id):
		return false
	var c := hire_cost(type_id)
	if money < c:
		return false
	money -= c
	workers.append({"type": type_id, "level": 1})
	toast.emit("Contratado: %s" % GameData.worker_def(type_id)["name"])
	workers_changed.emit()
	changed.emit()
	return true


func worker_level_cost(idx: int) -> float:
	var w: Dictionary = workers[idx]
	var d := GameData.worker_def(w["type"])
	return floor(float(d["cost"]) * 0.6 * pow(1.55, int(w["level"])))


func level_up_worker(idx: int) -> bool:
	if idx < 0 or idx >= workers.size():
		return false
	var w: Dictionary = workers[idx]
	if int(w["level"]) >= GameData.WORKER_MAX_LEVEL:
		return false
	var c := worker_level_cost(idx)
	if money < c:
		return false
	money -= c
	w["level"] = int(w["level"]) + 1
	workers_changed.emit()
	changed.emit()
	return true


func next_zone_cost() -> float:
	if zones_unlocked >= GameData.ZONES.size():
		return -1.0
	return float(GameData.ZONES[zones_unlocked]["cost"])


func unlock_next_zone() -> bool:
	var c := next_zone_cost()
	if c < 0.0 or money < c:
		return false
	money -= c
	zones_unlocked += 1
	toast.emit("Zona desbloqueada: %s" % GameData.ZONES[zones_unlocked - 1]["name"])
	zones_changed.emit()
	changed.emit()
	save_game()
	return true


func buy_eco_boost() -> bool:
	if eco < GameData.BOOST_ECO_COST:
		return false
	eco -= GameData.BOOST_ECO_COST
	boost_time += GameData.BOOST_ECO_SECONDS
	toast.emit("¡Dinero x2 activado!")
	changed.emit()
	return true


func eco_instant_cash_value() -> float:
	return maxf(100.0, passive_income() / boost_mult() * 300.0 + bag_value() * 3.0 + money * 0.05)


func buy_eco_cash() -> bool:
	if eco < 10:
		return false
	eco -= 10
	var v := eco_instant_cash_value()
	add_money(v)
	toast.emit("+$%s" % GameData.fmt(v))
	changed.emit()
	return true


## Recompensa tras ver un anuncio voluntario completo.
func grant_ad_reward(kind: String) -> void:
	stats["ads"] = int(stats["ads"]) + 1
	ad_cooldown = GameData.AD_COOLDOWN
	match kind:
		"eco":
			eco += GameData.AD_ECO_REWARD
			toast.emit("+%d EcoCoins" % GameData.AD_ECO_REWARD)
		"boost":
			boost_time += GameData.AD_BOOST_SECONDS
			toast.emit("¡Dinero x2 durante 3 minutos!")
		"cash":
			var v := eco_instant_cash_value()
			add_money(v)
			toast.emit("+$%s" % GameData.fmt(v))
		"offline":
			add_money(pending_offline)
			toast.emit("Ganancias offline duplicadas: +$%s" % GameData.fmt(pending_offline))
			pending_offline = 0.0
	changed.emit()
	save_game()


func collect_offline() -> void:
	if pending_offline > 0.0:
		add_money(pending_offline)
		pending_offline = 0.0
		changed.emit()


# ---------------------------------------------------------------- logros

func stat_value(stat: String) -> float:
	match stat:
		"tier":
			return float(tier)
		"workers":
			return float(workers.size())
		"zones":
			return float(zones_unlocked)
		_:
			return float(stats.get(stat, 0))


func achievement_ready(a: Dictionary) -> bool:
	return not claimed.has(a["id"]) and stat_value(a["stat"]) >= float(a["goal"])


func claim_achievement(id: String) -> bool:
	for a in GameData.ACHIEVEMENTS:
		if a["id"] == id and achievement_ready(a):
			claimed.append(id)
			eco += int(a["reward"])
			toast.emit("Logro: %s (+%d EcoCoins)" % [a["name"], int(a["reward"])])
			changed.emit()
			return true
	return false


func pending_achievements() -> int:
	var n := 0
	for a in GameData.ACHIEVEMENTS:
		if achievement_ready(a):
			n += 1
	return n


# ---------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	var pi := passive_income()
	if pi > 0.0:
		add_money(pi * delta)
	if boost_time > 0.0:
		boost_time = maxf(0.0, boost_time - delta)
		if boost_time == 0.0:
			changed.emit()
	if ad_cooldown > 0.0:
		ad_cooldown = maxf(0.0, ad_cooldown - delta)
	_save_timer += delta
	if _save_timer >= AUTOSAVE_SECONDS:
		_save_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()


# ---------------------------------------------------------------- guardado

func save_game() -> void:
	var data := {
		"v": SAVE_VERSION,
		"time": Time.get_unix_time_from_system(),
		"money": money, "eco": eco, "tier": tier,
		"upgrades": upgrades, "workers": workers,
		"zones": zones_unlocked, "bag": bag, "stats": stats,
		"claimed": claimed, "boost": boost_time, "tutorial": tutorial_done,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Guardado corrupto, se ignora.")
		return
	var d: Dictionary = parsed
	money = float(d.get("money", 0.0))
	eco = int(d.get("eco", 0))
	tier = clampi(int(d.get("tier", 0)), 0, GameData.TIERS.size() - 1)
	var up: Dictionary = d.get("upgrades", {})
	for k in up.keys():
		if upgrades.has(k):
			upgrades[k] = int(up[k])
	workers = []
	for w in d.get("workers", []):
		if typeof(w) == TYPE_DICTIONARY and GameData.worker_index(str(w.get("type", ""))) >= 0:
			workers.append({"type": str(w["type"]), "level": clampi(int(w.get("level", 1)), 1, GameData.WORKER_MAX_LEVEL)})
	zones_unlocked = clampi(int(d.get("zones", 1)), 1, GameData.ZONES.size())
	var b: Array = d.get("bag", [])
	bag_count = 0
	for i in mini(b.size(), bag.size()):
		bag[i] = int(b[i])
		bag_count += int(b[i])
	var st: Dictionary = d.get("stats", {})
	for k in st.keys():
		stats[k] = st[k]
	stats["collected"] = int(stats["collected"])
	stats["sales"] = int(stats["sales"])
	stats["ads"] = int(stats["ads"])
	stats["earned"] = float(stats["earned"])
	claimed = []
	for c in d.get("claimed", []):
		claimed.append(str(c))
	boost_time = float(d.get("boost", 0.0))
	tutorial_done = bool(d.get("tutorial", false))
	# Ganancias offline
	var elapsed := clampf(Time.get_unix_time_from_system() - float(d.get("time", 0.0)), 0.0, OFFLINE_CAP_SECONDS)
	var saved_boost := boost_time
	boost_time = 0.0
	var rate := passive_income()
	boost_time = saved_boost
	var factor := 1.0 if has_manager() else 0.3
	pending_offline = rate * elapsed * factor
	if pending_offline < 1.0:
		pending_offline = 0.0


func reset_game() -> void:
	_reset_values()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_game()
	get_tree().reload_current_scene()
