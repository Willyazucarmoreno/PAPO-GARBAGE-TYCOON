class_name PapoFormat
extends RefCounted
## Formato de números para la interfaz.

static func num(v: float) -> String:
	var a := absf(v)
	if a >= 1e12: return "%.2fT" % (v / 1e12)
	if a >= 1e9: return "%.2fB" % (v / 1e9)
	if a >= 1e6: return "%.2fM" % (v / 1e6)
	if a >= 1e4: return "%.1fK" % (v / 1e3)
	if a >= 100.0 or fmod(v, 1.0) == 0.0: return "%d" % int(v)
	return "%.1f" % v


static func time(secs: float) -> String:
	var s := int(secs)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]
