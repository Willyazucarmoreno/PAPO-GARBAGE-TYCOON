class_name PapoOffline
extends RefCounted
## Cálculo de ganancias sin conexión (idle).

static func compute(last_unix: float, rate_per_sec: float, cap_seconds: float, factor: float = 1.0) -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var secs := clampf(now - last_unix, 0.0, cap_seconds) if last_unix > 0.0 else 0.0
	return {"seconds": secs, "amount": rate_per_sec * secs * factor}
