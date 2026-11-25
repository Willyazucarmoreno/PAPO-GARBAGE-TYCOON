class_name Worker
extends Node3D
## Trabajador automático. Los recolectores (recolector, conductor, robot)
## buscan basura, la cargan y la venden. El resto trabaja en el centro de
## reciclaje (bonificaciones pasivas) con una animación de trabajo.

enum State { SEEK, RETURN, STATION }

var world: World
var index: int = 0

var _state: int = State.SEEK
var _target: Node3D = null
var _load: int = 0
var _load_value: float = 0.0
var _t: float = 0.0
var _body: Node3D
var _label: Label3D
var _type: String = ""
var _home: Vector3


func _ready() -> void:
	_t = randf() * 10.0
	_build()


func _data() -> Dictionary:
	return GameState.workers[index] if index < GameState.workers.size() else {}


func _build() -> void:
	var w := _data()
	if w.is_empty():
		return
	_type = w["type"]
	var d := GameData.worker_def(_type)
	var model := AssetLib.instance("worker_" + _type)
	if model:
		_body = model
		add_child(model)
	else:
		_body = Node3D.new()
		add_child(_body)
		match _type:
			"robot":
				AssetLib.box(_body, Vector3(0.8, 0.8, 0.6), Color("95a5a6"), Vector3(0, 0.9, 0), 0.8)
				AssetLib.box(_body, Vector3(0.55, 0.45, 0.45), Color("bdc3c7"), Vector3(0, 1.6, 0), 0.8)
				AssetLib.box(_body, Vector3(0.4, 0.1, 0.05), Color("00e5ff"), Vector3(0, 1.62, 0.24))
				AssetLib.cyl(_body, 0.3, 0.3, 0.3, Color("2d3436"), Vector3(0, 0.3, 0), 10).rotation_degrees.z = 90
				AssetLib.cyl(_body, 0.02, 0.02, 0.4, Color("e74c3c"), Vector3(0, 2.0, 0), 4)
			"conductor":
				AssetLib.box(_body, Vector3(1.6, 1.0, 1.2), Color("2a6fdb"), Vector3(0, 0.9, 0.9))
				AssetLib.box(_body, Vector3(1.6, 1.4, 2.2), Color("ecf0f1"), Vector3(0, 1.1, -0.8))
				AssetLib.box(_body, Vector3(1.4, 0.4, 0.05), Color("bfe6ff"), Vector3(0, 1.2, 1.51))
				for wx in [-0.8, 0.8]:
					for wz in [1.0, -1.2]:
						AssetLib.cyl(_body, 0.35, 0.35, 0.25, Color("222222"), Vector3(wx, 0.35, wz), 8).rotation_degrees.z = 90
			_:
				AssetLib.humanoid(_body, d["color"], Color("2c3e50"), Color.from_hsv(0.08, 0.35, randf_range(0.45, 0.95)), d["color"].darkened(0.3))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 34
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position = Vector3(0, 2.3, 0)
	_label.modulate = Color(1, 1, 1, 0.8)
	add_child(_label)
	if d["kind"] != "collector":
		_state = State.STATION
		var c: Vector3 = world.zone_center(0)
		var slot := index % 8
		_home = c + Vector3(-1.0 - (slot % 4) * 1.7, 0, 6.5 + float(slot / 4) * 1.7)
		_home = world.resolve_obstacles(_home, 0.4)
		position = _home


func _process(delta: float) -> void:
	var w := _data()
	if w.is_empty() or _body == null:
		return
	_t += delta
	_label.text = "%s Nv%d%s" % [GameData.worker_def(_type)["name"], int(w["level"]), " (temp.)" if w.has("expires") else ""]
	match _state:
		State.STATION:
			_body.rotation.y = sin(_t * 1.5) * 0.6
			_body.position.y = absf(sin(_t * 4.0)) * 0.08
		State.SEEK:
			_seek(delta, w)
		State.RETURN:
			_return(delta, w)


func _move_to(p: Vector3, delta: float, w: Dictionary) -> bool:
	var to := Vector3(p.x - position.x, 0, p.z - position.z)
	var dist := to.length()
	var spd := GameState.worker_speed(w)
	if dist < 0.4:
		return true
	var step := minf(dist, spd * delta)
	var np := position + to / dist * step
	np = world.resolve_obstacles(np, 0.4)
	position = np
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
	if _type != "conductor" and _type != "robot":
		_body.position.y = absf(sin(_t * 10.0)) * 0.1
	if AssetLib.has_model("worker_" + _type):
		AssetLib.play_anim(_body, ["Walking_A", "Walk", "Run"])
	return dist < 0.4


func _seek(delta: float, w: Dictionary) -> void:
	if _target == null or not is_instance_valid(_target) or not world.trash.has(_target):
		_target = world.nearest_free_trash(position, GameState.zones_unlocked)
		if _target == null:
			return
		_target.set_meta("claimed", true)
	if _move_to(_target.position, delta, w):
		var mat := int(_target.get_meta("mat"))
		GameState.worker_collected(int(_target.get_meta("zone")))
		_load += 1
		_load_value += float(GameData.MATERIALS[mat]["price"])
		world.take_trash(_target, self)
		_target = null
		if _load >= GameState.worker_capacity(w):
			_state = State.RETURN


func _return(delta: float, w: Dictionary) -> void:
	var sp: Vector3 = world.nearest_sell_point(position)
	if _move_to(sp, delta, w) or position.distance_to(sp) < world.SELL_RADIUS * 0.7:
		GameState.worker_deposit(_load_value, position)
		_load = 0
		_load_value = 0.0
		_state = State.SEEK
