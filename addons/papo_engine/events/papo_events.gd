class_name PapoEvents
extends RefCounted
## Eventos de calendario. Evento: {"id","name","from":[mes,dia],"to":[mes,dia], ...}.
## Rangos que cruzan año (p. ej. 30/12 → 6/1) están soportados.

static func active(events: Array, force_id: String = "", unix: float = -1.0) -> Dictionary:
	if force_id != "":
		for e in events:
			if e["id"] == force_id:
				return e
	var d := Time.get_date_dict_from_unix_time(int(unix if unix >= 0.0 else Time.get_unix_time_from_system()))
	var today := int(d["month"]) * 100 + int(d["day"])
	for e in events:
		var a := int(e["from"][0]) * 100 + int(e["from"][1])
		var b := int(e["to"][0]) * 100 + int(e["to"][1])
		if (a <= b and today >= a and today <= b) or (a > b and (today >= a or today <= b)):
			return e
	return {}
