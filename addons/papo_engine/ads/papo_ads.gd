class_name PapoAds
extends Node
## Anuncios recompensados VOLUNTARIOS (AdMob vía plugin o modo simulado).
## - Límite diario y enfriamiento configurables.
## - La recompensa solo se entrega cuando el SDK confirma "earned".
## - Cada solicitud tiene un id único: nunca se recompensa dos veces.
## - Sin anuncio disponible, el juego sigue normalmente (señal `unavailable`).

signal reward_earned(kind: String)
signal simulated_requested(request_id: int, kind: String)
signal unavailable(reason: String)
signal consent_needed
signal cancelled(kind: String)

var cfg: Dictionary = {"max_daily": 10, "cooldown": 30.0, "rewarded_id": "", "app_id": ""}
var day: String = ""
var count_today: int = 0
var cooldown: float = 0.0
var consent: String = "unknown"   # unknown | personalized | non_personalized

var _plugin: Object = null
var _loaded: bool = false
var _next_id: int = 1
var _pending_id: int = 0
var _pending_kind: String = ""
var _done_ids: Dictionary = {}


func setup(config: Dictionary, saved: Dictionary) -> void:
	for k in config.keys():
		cfg[k] = config[k]
	day = str(saved.get("day", ""))
	count_today = int(saved.get("count", 0))
	consent = str(saved.get("consent", "unknown"))
	_roll_day()
	if Engine.has_singleton("AdMob"):
		_plugin = Engine.get_singleton("AdMob")
		_bind_plugin()


func to_dict() -> Dictionary:
	return {"day": day, "count": count_today, "consent": consent}


func is_real() -> bool:
	return _plugin != null


func remaining_today() -> int:
	_roll_day()
	return maxi(0, int(cfg["max_daily"]) - count_today)


func can_show() -> bool:
	return remaining_today() > 0 and cooldown <= 0.0 and _pending_id == 0


func set_consent(value: String) -> void:
	consent = value
	if _plugin and _plugin.has_method("set_personalized_ads"):
		_plugin.call("set_personalized_ads", value == "personalized")


## Solicita un anuncio. Devuelve false si no se puede mostrar.
func request(kind: String) -> bool:
	if consent == "unknown":
		consent_needed.emit()
		return false
	if remaining_today() <= 0:
		unavailable.emit("Límite diario de anuncios alcanzado. ¡Vuelve mañana!")
		return false
	if cooldown > 0.0:
		unavailable.emit("Espera %ds para otro anuncio." % int(ceil(cooldown)))
		return false
	if _pending_id != 0:
		return false
	_pending_id = _next_id
	_next_id += 1
	_pending_kind = kind
	if _plugin:
		if _loaded and _plugin.has_method("show_rewarded_ad"):
			_plugin.call("show_rewarded_ad")
		else:
			_clear_pending()
			_load()
			unavailable.emit("No hay anuncios disponibles ahora. Puedes seguir jugando.")
			return false
	else:
		simulated_requested.emit(_pending_id, kind)
	return true


## Confirmación del SDK (o del simulador) de que corresponde recompensa.
func confirm_reward(request_id: int) -> void:
	if request_id != _pending_id or _done_ids.has(request_id):
		return
	_done_ids[request_id] = true
	var k := _pending_kind
	count_today += 1
	cooldown = float(cfg["cooldown"])
	_clear_pending()
	reward_earned.emit(k)


func cancel(request_id: int) -> void:
	if request_id == _pending_id and request_id != 0:
		var k := _pending_kind
		_clear_pending()
		cancelled.emit(k)


func _clear_pending() -> void:
	_pending_id = 0
	_pending_kind = ""


func _roll_day() -> void:
	var today := PapoConfig.day_key()
	if day != today:
		day = today
		count_today = 0


func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)


# ---------------- puente con plugin AdMob (singleton "AdMob")

func _bind_plugin() -> void:
	var map := {"rewarded_ad_loaded": "_on_loaded", "user_earned_rewarded": "_on_earned",
		"rewarded_ad_closed": "_on_closed", "rewarded_ad_failed_to_load": "_on_failed"}
	for s in map.keys():
		if _plugin.has_signal(s):
			_plugin.connect(s, Callable(self, map[s]))
	if _plugin.has_method("initialize"):
		_plugin.call("initialize")
	set_consent(consent)
	_load()


func _load() -> void:
	if _plugin and _plugin.has_method("load_rewarded_ad"):
		_plugin.call("load_rewarded_ad", cfg["rewarded_id"])


func _on_loaded(_a = null) -> void:
	_loaded = true


func _on_earned(_a = null, _b = null) -> void:
	_loaded = false
	confirm_reward(_pending_id)
	_load()


func _on_closed(_a = null) -> void:
	cancel(_pending_id)
	_load()


func _on_failed(_a = null, _b = null) -> void:
	_loaded = false
