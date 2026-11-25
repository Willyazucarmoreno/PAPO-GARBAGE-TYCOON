extends Node
## Estado de PAPO Garbage Tycoon construido sobre PAPO-GAME-ENGINE.

signal changed
signal toast(text: String)
signal sold(amount: float, at: Vector3)
signal tier_changed
signal zones_changed
signal workers_changed
signal look_changed
signal leveled_up(level: int)
signal spawn_bonus_materials(count: int)
signal zone_clean_changed(zone: int)

const SAVE_PATH := "user://papo_save.json"
const SAVE_VERSION := 2
const CONFIG_PATH := "res://config/game_config.json"
const CONFIG_DEFAULTS := {
	"ads": {"max_daily": 10, "cooldown": 30, "app_id": "", "rewarded_id": ""},
	"offline_cap_hours": 8, "offline_factor_without_manager": 0.5,
	"force_event": "", "autosave_seconds": 10,
}
const CLEAN_PER_ITEM := 1.0 / 180.0

var cfg: Dictionary = {}
var wallet := PapoWallet.new(["money", "eco"])
var inv := PapoInventory.new(12)
var ups := PapoUpgrades.new()
var roster := PapoRoster.new()
var levels := PapoLevels.new()
var boosts := PapoBoosts.new()
var missions := PapoMissions.new()

var money: float:
	get: return wallet.get_v("money")
	set(v): wallet.values["money"] = v
var eco: int:
	get: return int(wallet.get_v("eco"))
	set(v): wallet.values["eco"] = float(v)
var bag: Array:
	get: return inv.counts
var bag_count: int:
	get: return inv.total
var workers: Array:
	get: return roster.list
var upgrades: Dictionary:
	get: return ups.levels

var tier: int = 0
var zones_unlocked: int = 1
var zone_clean: Array = []
var stats: Dictionary = {}
var claimed: Array = []
var pending_offline: float = 0.0
var offline_seconds: float = 0.0
var tutorial_done: bool = false
var last_sale: float = 0.0
var last_sale_time: float = -100.0
var daily_streak: int = 0
var daily_last: String = ""
var daily_extra_day: String = ""
var cosmetics_owned: Array = ["shirt_orange", "hat_green", "veh_default"]
var look: Dictionary = {"shirt": "shirt_orange", "hat": "hat_green", "vehicle": "veh_default"}
var event: Dictionary = {}
var settings: Dictionary = {"shadows": true, "vibration": true}

var _save_timer: float = 0.0
var _slow_timer: float = 0.0
var _bag_full_warned: bool = false
var _stat_reader: Callable


func _ready() -> void:
	cfg = PapoConfig.load_json(CONFIG_PATH, CONFIG_DEFAULTS)
	_stat_reader = stat_value
	levels.leveled_up.connect(_on_level_up)
	AdManager.reward_earned.connect(grant_ad_reward)
	AdManager.unavailable.connect(func(r: String) -> void: toast.emit(r))
	AdManager.cancelled.connect(func(k: String) -> void:
		if k == "offline":
			collect_offline())
	_reset_values()
	load_game()
	_refresh_periodic()


func _reset_values() -> void:
	wallet.values = {"money": 0.0, "eco": 0.0}
	inv.clear()
	ups.levels = {}
	for u in GameData.UPGRADES:
		ups.levels[u["id"]] = 0
	roster.list = []
	levels.level = 1
	levels.xp = 0.0
	boosts.timers = {}
	missions.periods = {}
	tier = 0
	zones_unlocked = 1
	zone_clean = []
	zone_clean.resize(GameData.ZONES.size())
	zone_clean.fill(0.0)
	stats = {"collected": 0, "earned": 0.0, "sales": 0, "ads": 0, "upgrades_bought": 0, "rare": 0}
	claimed = []
	pending_offline = 0.0
	tutorial_done = false
	daily_streak = 0
	daily_last = ""
	daily_extra_day = ""
	cosmetics_owned = ["shirt_orange", "hat_green", "veh_default"]
	look = {"shirt": "shirt_orange", "hat": "hat_green", "vehicle": "veh_default"}


# ---------------------------------------------------------------- cálculos

func lvl(id: String) -> int:
	return ups.lvl(id)


func tier_def() -> Dictionary:
	return GameData.TIERS[tier]


func capacity() -> int:
	return int(round(float(tier_def()["cap"]) * (1.0 + 0.10 * lvl("capacidad")) * boosts.mult("truck", 3.0)))


func move_speed() -> float:
	return float(tier_def()["speed"]) * (1.0 + 0.05 * lvl("velocidad")) * boosts.mult("speed", 2.0) * boosts.mult("truck", 1.3)


func collect_radius() -> float:
	return float(tier_def()["radius"]) * boosts.mult("truck", 1.4)


func count_workers(type_id: String) -> int:
	return roster.count(type_id)


func boost_mult() -> float:
	return boosts.mult("money", 2.0)


## Compatibilidad con la interfaz: segundos de "dinero x2".
var boost_time: float:
	get: return boosts.left("money")


func event_bonus() -> float:
	return float(event.get("bonus", 1.0))


func sell_multiplier() -> float:
	return float(tier_def()["sell"]) * (1.0 + 0.08 * lvl("precio")) \
		* (1.0 + 0.04 * roster.sum_levels("clasificador")) * boost_mult() * event_bonus()


func passive_income() -> float:
	var base := float(tier_def()["passive"]) + 3.0 * roster.sum_levels("operador")
	return base * (1.0 + 0.15 * lvl("produccion")) * (1.0 + 0.10 * roster.sum_levels("gerente")) \
		* boost_mult() * boosts.mult("production", 2.0)


func worker_speed_mult() -> float:
	return (1.0 + 0.08 * lvl("automatizacion")) * (1.0 + 0.08 * roster.sum_levels("supervisor"))


func worker_speed(w: Dictionary) -> float:
	var d := GameData.worker_def(w["type"])
	return float(d["speed"]) * (1.0 + 0.06 * (int(w["level"]) - 1)) * worker_speed_mult()


func worker_capacity(w: Dictionary) -> int:
	var d := GameData.worker_def(w["type"])
	return int(round(float(d["cap"]) * (1.0 + 0.15 * (int(w["level"]) - 1)) * (1.0 + 0.20 * lvl("almacen"))))


## Ingreso estimado por segundo de los recolectores (para ganancias offline).
func worker_income_estimate() -> float:
	var avg_price := 0.0
	var pool: Array = GameData.ZONES[zones_unlocked - 1]["pool"]
	for m in pool:
		avg_price += float(GameData.MATERIALS[int(m)]["price"])
	avg_price /= pool.size()
	var items_per_sec := 0.0
	for w in roster.list:
		if GameData.worker_def(w["type"])["kind"] == "collector" and not w.has("expires"):
			items_per_sec += worker_speed(w) / 14.0
	return items_per_sec * avg_price * sell_multiplier() / boost_mult() / event_bonus()


func bag_value() -> float:
	return inv.value(GameData.MATERIALS.map(func(m: Dictionary) -> float: return float(m["price"])))


func has_manager() -> bool:
	return count_workers("gerente") > 0


func sell_points_everywhere() -> bool:
	return tier >= GameData.TIER_SELL_POINTS_EVERYWHERE


func zone_trash_cap(zi: int, base: int) -> int:
	return int(round(lerpf(float(base), float(base) * 0.3, float(zone_clean[zi]))))


# ---------------------------------------------------------------- acciones

func add_money(v: float) -> void:
	wallet.add("money", v)
	stats["earned"] = float(stats["earned"]) + v


func add_eco(n: int) -> void:
	wallet.add("eco", n)


func add_to_bag(mat: int, zone: int = -1) -> bool:
	if inv.add(mat, 1, capacity()) == 0:
		return false
	stats["collected"] = int(stats["collected"]) + 1
	var price := float(GameData.MATERIALS[mat]["price"])
	if price >= 10.0:
		stats["rare"] = int(stats["rare"]) + 1
	levels.add_xp(1.0 + price * 0.2)
	_clean_zone(zone)
	_bag_full_warned = false
	if bag_count >= capacity():
		_on_bag_full()
	changed.emit()
	return true


func worker_collected(zone: int) -> void:
	_clean_zone(zone)


func _clean_zone(zone: int) -> void:
	if zone < 0 or zone >= zone_clean.size():
		return
	var before := int(float(zone_clean[zone]) * 20.0)
	zone_clean[zone] = minf(1.0, float(zone_clean[zone]) + CLEAN_PER_ITEM)
	if int(float(zone_clean[zone]) * 20.0) != before:
		zone_clean_changed.emit(zone)


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
	inv.clear()
	stats["sales"] = int(stats["sales"]) + 1
	last_sale = v
	last_sale_time = Time.get_ticks_msec() / 1000.0
	sold.emit(v, at)
	changed.emit()
	return v


func sale_x2_available() -> bool:
	return last_sale > 0.0 and Time.get_ticks_msec() / 1000.0 - last_sale_time < 12.0


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
	if c < 0.0 or not wallet.spend("money", c):
		return false
	tier += 1
	toast.emit("¡Nuevo: %s!" % GameData.TIERS[tier]["name"])
	tier_changed.emit()
	changed.emit()
	save_game()
	return true


func upgrade_cost(id: String) -> float:
	var d := GameData.upgrade_def(id)
	return PapoUpgrades.cost(float(d["base"]), float(d["growth"]), lvl(id))


func upgrade_maxed(id: String) -> bool:
	return lvl(id) >= int(GameData.upgrade_def(id)["max"])


func buy_upgrade(id: String) -> bool:
	if not ups.buy(id, GameData.upgrade_def(id), wallet):
		return false
	stats["upgrades_bought"] = int(stats["upgrades_bought"]) + 1
	changed.emit()
	return true


func hire_cost(type_id: String) -> float:
	return PapoRoster.hire_cost(float(GameData.worker_def(type_id)["cost"]), count_workers(type_id))


func can_hire(type_id: String) -> bool:
	return tier >= int(GameData.worker_def(type_id)["req_tier"]) and count_workers(type_id) < GameData.MAX_WORKERS_PER_TYPE


func hire(type_id: String) -> bool:
	if not can_hire(type_id) or not wallet.spend("money", hire_cost(type_id)):
		return false
	roster.add(type_id)
	toast.emit("Contratado: %s" % GameData.worker_def(type_id)["name"])
	workers_changed.emit()
	changed.emit()
	return true


func worker_level_cost(idx: int) -> float:
	var w: Dictionary = workers[idx]
	return PapoRoster.level_cost(float(GameData.worker_def(w["type"])["cost"]), int(w["level"]))


func level_up_worker(idx: int) -> bool:
	if idx < 0 or idx >= workers.size():
		return false
	var w: Dictionary = workers[idx]
	if int(w["level"]) >= GameData.WORKER_MAX_LEVEL or w.has("expires"):
		return false
	if not wallet.spend("money", worker_level_cost(idx)):
		return false
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
	if c < 0.0 or not wallet.spend("money", c):
		return false
	zones_unlocked += 1
	toast.emit("Zona desbloqueada: %s" % GameData.ZONES[zones_unlocked - 1]["name"])
	zones_changed.emit()
	changed.emit()
	save_game()
	return true


func buy_eco_boost() -> bool:
	if not wallet.spend("eco", GameData.BOOST_ECO_COST):
		return false
	boosts.add("money", GameData.BOOST_ECO_SECONDS)
	toast.emit("¡Dinero x2 activado!")
	changed.emit()
	return true


func eco_instant_cash_value() -> float:
	return maxf(100.0, passive_income() / boost_mult() * 300.0 + bag_value() * 3.0 + money * 0.05)


func buy_eco_cash() -> bool:
	if not wallet.spend("eco", 10):
		return false
	var v := eco_instant_cash_value()
	add_money(v)
	toast.emit("+$%s" % GameData.fmt(v))
	changed.emit()
	return true


# ---------------------------------------------------------------- personalización

func cosmetic(id: String) -> Dictionary:
	for c in GameData.COSMETICS:
		if c["id"] == id:
			return c
	return {}


func look_color(slot: String) -> Color:
	return cosmetic(look.get(slot, ""))["color"] if not cosmetic(look.get(slot, "")).is_empty() else Color(0, 0, 0, 0)


func buy_or_equip_cosmetic(id: String) -> bool:
	var c := cosmetic(id)
	if c.is_empty():
		return false
	if not cosmetics_owned.has(id):
		if not wallet.spend("eco", int(c["cost"])):
			return false
		cosmetics_owned.append(id)
	look[c["slot"]] = id
	look_changed.emit()
	changed.emit()
	return true


# ---------------------------------------------------------------- anuncios

## Llamado SOLO cuando el SDK (o el simulador) confirma la recompensa.
func grant_ad_reward(kind: String) -> void:
	stats["ads"] = int(stats["ads"]) + 1
	match kind:
		"eco":
			add_eco(GameData.AD_ECO_REWARD)
			toast.emit("+%d EcoCoins" % GameData.AD_ECO_REWARD)
		"production":
			boosts.add("production", 600.0)
			toast.emit("¡Producción x2 durante 10 minutos!")
		"speed":
			boosts.add("speed", 300.0)
			toast.emit("¡Velocidad x2 durante 5 minutos!")
		"truck":
			boosts.add("truck", 300.0)
			tier_changed.emit()
			toast.emit("¡Camión especial durante 5 minutos!")
		"temp_worker":
			roster.add("recolector", maxi(1, levels.level / 3), 600.0)
			workers_changed.emit()
			toast.emit("¡Recolector temporal contratado (10 min)!")
		"materials":
			spawn_bonus_materials.emit(14)
			toast.emit("¡Materiales valiosos a tu alrededor!")
		"sale_x2":
			if last_sale > 0.0:
				add_money(last_sale)
				toast.emit("Venta duplicada: +$%s" % GameData.fmt(last_sale))
				last_sale = 0.0
		"offline":
			add_money(pending_offline * 2.0)
			toast.emit("Ganancias offline x2: +$%s" % GameData.fmt(pending_offline * 2.0))
			pending_offline = 0.0
		"daily_extra":
			daily_extra_day = PapoConfig.day_key()
			_give_daily(daily_streak)
	changed.emit()
	save_game()


func collect_offline() -> void:
	if pending_offline > 0.0:
		add_money(pending_offline)
		pending_offline = 0.0
		changed.emit()


# ---------------------------------------------------------------- diario

func daily_available() -> bool:
	return daily_last != PapoConfig.day_key()


func daily_extra_available() -> bool:
	return not daily_available() and daily_extra_day != PapoConfig.day_key()


func claim_daily() -> bool:
	if not daily_available():
		return false
	var yesterday := PapoConfig.day_key(Time.get_unix_time_from_system() - 86400.0)
	daily_streak = (daily_streak % 7) + 1 if daily_last == yesterday else 1
	daily_last = PapoConfig.day_key()
	_give_daily(daily_streak)
	changed.emit()
	save_game()
	return true


func daily_reward_for(streak: int) -> Dictionary:
	var r: Dictionary = GameData.DAILY_REWARDS[clampi(streak, 1, 7) - 1]
	var cash := maxf(50.0 * streak, (passive_income() / boost_mult() + 2.0) * float(r["money_secs"]))
	return {"eco": int(r["eco"]), "money": cash}


func _give_daily(streak: int) -> void:
	var r := daily_reward_for(streak)
	add_eco(int(r["eco"]))
	add_money(float(r["money"]))
	toast.emit("Recompensa diaria: +%d Eco y $%s" % [int(r["eco"]), GameData.fmt(float(r["money"]))])


# ---------------------------------------------------------------- misiones y logros

func stat_value(stat: String) -> float:
	match stat:
		"tier": return float(tier)
		"workers": return float(roster.list.filter(func(w: Dictionary) -> bool: return not w.has("expires")).size())
		"zones": return float(zones_unlocked)
		"level": return float(levels.level)
		_: return float(stats.get(stat, 0))


func mission_scale() -> float:
	return 1.0 + tier * 0.6 + zones_unlocked * 0.3


func _refresh_periodic() -> void:
	var a := missions.refresh("daily", PapoConfig.day_key(), GameData.DAILY_TEMPLATES, 3, _stat_reader, mission_scale())
	var b := missions.refresh("weekly", PapoConfig.week_key(), GameData.WEEKLY_TEMPLATES, 3, _stat_reader, mission_scale() * 1.5)
	var ev := PapoEvents.active(GameData.EVENTS, str(cfg["force_event"]))
	var ev_changed: bool = ev.get("id", "") != event.get("id", "")
	event = ev
	if ev_changed and not event.is_empty():
		toast.emit("¡Evento %s! Ventas x%.2f" % [event["name"], float(event["bonus"])])
	if a or b or ev_changed:
		changed.emit()


func claim_mission(period: String, idx: int) -> bool:
	var r := missions.claim(period, idx, _stat_reader)
	if r <= 0:
		return false
	add_eco(r)
	toast.emit("Misión completada: +%d EcoCoins" % r)
	changed.emit()
	return true


func achievement_ready(a: Dictionary) -> bool:
	return not claimed.has(a["id"]) and stat_value(a["stat"]) >= float(a["goal"])


func claim_achievement(id: String) -> bool:
	for a in GameData.ACHIEVEMENTS:
		if a["id"] == id and achievement_ready(a):
			claimed.append(id)
			add_eco(int(a["reward"]))
			toast.emit("Logro: %s (+%d EcoCoins)" % [a["name"], int(a["reward"])])
			changed.emit()
			return true
	return false


func pending_achievements() -> int:
	var n := missions.ready_count(_stat_reader)
	for a in GameData.ACHIEVEMENTS:
		if achievement_ready(a):
			n += 1
	return n


func _on_level_up(l: int) -> void:
	add_eco(2)
	toast.emit("¡Nivel %d! +2 EcoCoins" % l)
	leveled_up.emit(l)


# ---------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	var pi := passive_income()
	if pi > 0.0:
		add_money(pi * delta)
	if boosts.tick(delta):
		if not boosts.active("truck"):
			tier_changed.emit()
		changed.emit()
	_slow_timer += delta
	if _slow_timer >= 1.0:
		_slow_timer = 0.0
		if roster.purge_expired():
			toast.emit("Terminó el trabajador temporal.")
			workers_changed.emit()
			changed.emit()
		_refresh_periodic()
	_save_timer += delta
	if _save_timer >= float(cfg["autosave_seconds"]):
		_save_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST]:
		save_game()


# ---------------------------------------------------------------- guardado

func save_game() -> void:
	PapoSave.write(SAVE_PATH, {
		"v": SAVE_VERSION, "time": Time.get_unix_time_from_system(),
		"wallet": wallet.to_dict(), "tier": tier, "upgrades": ups.levels, "workers": roster.list,
		"zones": zones_unlocked, "clean": zone_clean, "bag": inv.to_array(), "stats": stats,
		"claimed": claimed, "boosts": boosts.timers, "tutorial": tutorial_done,
		"level": levels.level, "xp": levels.xp, "missions": missions.periods,
		"daily": [daily_streak, daily_last, daily_extra_day],
		"cosmetics": cosmetics_owned, "look": look, "ads": AdManager.to_dict(), "settings": settings,
		"offline_rate": worker_income_estimate() + passive_income() / boost_mult() / boosts.mult("production", 2.0),
	})


func load_game() -> void:
	var d := PapoSave.read(SAVE_PATH)
	AdManager.setup(cfg["ads"], d.get("ads", {}))
	if d.is_empty():
		return
	if d.has("wallet"):
		wallet.from_dict(d["wallet"])
	else:  # guardado v1
		wallet.values = {"money": float(d.get("money", 0.0)), "eco": float(d.get("eco", 0))}
	tier = clampi(int(d.get("tier", 0)), 0, GameData.TIERS.size() - 1)
	var up: Dictionary = d.get("upgrades", {})
	for k in up.keys():
		if ups.levels.has(k):
			ups.levels[k] = int(up[k])
	roster.list = []
	for w in d.get("workers", []):
		if typeof(w) == TYPE_DICTIONARY and GameData.worker_index(str(w.get("type", ""))) >= 0:
			var e := {"type": str(w["type"]), "level": clampi(int(w.get("level", 1)), 1, GameData.WORKER_MAX_LEVEL)}
			if w.has("expires"):
				e["expires"] = float(w["expires"])
			roster.list.append(e)
	roster.purge_expired()
	zones_unlocked = clampi(int(d.get("zones", 1)), 1, GameData.ZONES.size())
	var cl: Array = d.get("clean", [])
	for i in mini(cl.size(), zone_clean.size()):
		zone_clean[i] = float(cl[i])
	inv.from_array(d.get("bag", []))
	var st: Dictionary = d.get("stats", {})
	for k in st.keys():
		stats[k] = st[k]
	for k in ["collected", "sales", "ads", "upgrades_bought", "rare"]:
		stats[k] = int(stats.get(k, 0))
	stats["earned"] = float(stats["earned"])
	claimed = (d.get("claimed", []) as Array).map(func(c: Variant) -> String: return str(c))
	var bt: Dictionary = d.get("boosts", {})
	for k in bt.keys():
		boosts.timers[k] = float(bt[k])
	if d.has("boost"):
		boosts.timers["money"] = float(d["boost"])
	tutorial_done = bool(d.get("tutorial", false))
	levels.level = int(d.get("level", 1))
	levels.xp = float(d.get("xp", 0.0))
	var mp: Dictionary = d.get("missions", {})
	missions.periods = mp
	var dl: Array = d.get("daily", [0, "", ""])
	daily_streak = int(dl[0])
	daily_last = str(dl[1])
	daily_extra_day = str(dl[2])
	var co: Array = d.get("cosmetics", [])
	for c in co:
		if not cosmetics_owned.has(str(c)):
			cosmetics_owned.append(str(c))
	var lk: Dictionary = d.get("look", {})
	for k in lk.keys():
		look[k] = str(lk[k])
	var se: Dictionary = d.get("settings", {})
	for k in se.keys():
		settings[k] = se[k]
	# Ganancias offline: pasivo + trabajadores, con tope configurable.
	var rate := float(d.get("offline_rate", passive_income()))
	var factor := 1.0 if has_manager() else float(cfg["offline_factor_without_manager"])
	var off := PapoOffline.compute(float(d.get("time", 0.0)), rate, float(cfg["offline_cap_hours"]) * 3600.0, factor)
	offline_seconds = off["seconds"]
	pending_offline = off["amount"] if float(off["amount"]) >= 1.0 else 0.0


func reset_game() -> void:
	_reset_values()
	PapoSave.erase(SAVE_PATH)
	save_game()
	get_tree().reload_current_scene()
