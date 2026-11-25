class_name PapoConfig
extends RefCounted
## Lee un JSON de configuración y lo fusiona sobre valores por defecto.

static func load_json(path: String, defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge(out, parsed)
	return out


static func _merge(a: Dictionary, b: Dictionary) -> void:
	for k in b.keys():
		if a.has(k) and typeof(a[k]) == TYPE_DICTIONARY and typeof(b[k]) == TYPE_DICTIONARY:
			_merge(a[k], b[k])
		else:
			a[k] = b[k]


## Fecha local "AAAA-MM-DD" y clave semanal "AAAA-Wnn".
static func day_key(unix: float = -1.0) -> String:
	var d := Time.get_date_dict_from_unix_time(int(unix if unix >= 0.0 else Time.get_unix_time_from_system()))
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func week_key(unix: float = -1.0) -> String:
	var t := int(unix if unix >= 0.0 else Time.get_unix_time_from_system())
	# Semanas empezando en lunes (1970-01-01 fue jueves).
	return "W%d" % int(floor((t / 86400.0 + 3.0) / 7.0))
