class_name Player
extends Node3D
## Jugador: movimiento con joystick/teclado relativo a la cámara isométrica,
## recogida automática por proximidad, venta en puntos verdes y vehículo
## visual según la progresión.

var world: World
var joystick: VirtualJoystick

var _visual: Node3D
var _model: Node3D
var _vehicle: Node3D
var _walk_t: float = 0.0
var _moving: bool = false
var _facing: float = 0.0

# Ejes de pantalla proyectados al suelo (cámara a 45°).
const SCREEN_RIGHT := Vector3(0.70710678, 0, -0.70710678)
const SCREEN_UP := Vector3(-0.70710678, 0, -0.70710678)


func _ready() -> void:
	rebuild_visual()
	GameState.look_changed.connect(rebuild_visual)


func rebuild_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_model = AssetLib.instance("player")
	var rider_h := 0.0
	var truck := GameState.boosts.active("truck")
	_vehicle = _build_vehicle(9 if truck else GameState.tier, Color("f1c40f") if truck else GameState.look_color("vehicle"))
	if _vehicle:
		_visual.add_child(_vehicle)
		rider_h = float(_vehicle.get_meta("seat", 0.0))
	if _model:
		_model.position.y = rider_h
		_visual.add_child(_model)
	else:
		var body := AssetLib.humanoid(_visual, GameState.look_color("shirt"), Color("2c3e50"), Color("e0ac69"), GameState.look_color("hat"))
		body.position.y = rider_h
		_model = body
	# Bolsa / mochila visibles al inicio
	if GameState.tier == 0 and _vehicle == null:
		AssetLib.sphere(_model, 0.28, Color("2d3436"), Vector3(0.5, 0.55, 0.1), 6)
	elif GameState.tier == 1:
		AssetLib.box(_model, Vector3(0.5, 0.6, 0.3), Color("2980b9"), Vector3(0, 1.0, -0.35))


func _build_vehicle(t: int, paint: Color = Color(0, 0, 0, 0)) -> Node3D:
	if t < 2:
		return null
	var key := ["", "", "cart", "bicycle", "tricycle", "motorcycle", "pickup", "van", "small_truck", "garbage_truck"]
	var k: String = key[mini(t, 9)]
	var v := Node3D.new()
	var m := AssetLib.instance(k)
	if m:
		v.add_child(m)
		v.set_meta("seat", 0.0 if t == 2 else 0.6)
		return v
	match mini(t, 9):
		2:  # carrito de mano
			AssetLib.box(v, Vector3(0.9, 0.6, 0.9), Color("95a5a6"), Vector3(0, 0.6, 0.9), 0.5)
			AssetLib.cyl(v, 0.15, 0.15, 0.1, Color("222222"), Vector3(-0.4, 0.15, 0.9)).rotation_degrees.z = 90
			AssetLib.cyl(v, 0.15, 0.15, 0.1, Color("222222"), Vector3(0.4, 0.15, 0.9)).rotation_degrees.z = 90
			v.set_meta("seat", 0.0)
		3, 4:  # bicicleta / triciclo
			var frame := paint if paint.a > 0.0 else (Color("e74c3c") if t == 3 else Color("16a085"))
			AssetLib.box(v, Vector3(0.1, 0.1, 1.4), frame, Vector3(0, 0.55, 0))
			AssetLib.cyl(v, 0.35, 0.35, 0.08, Color("222222"), Vector3(0, 0.35, 0.65), 10).rotation_degrees.z = 90
			if t == 3:
				AssetLib.cyl(v, 0.35, 0.35, 0.08, Color("222222"), Vector3(0, 0.35, -0.65), 10).rotation_degrees.z = 90
			else:
				AssetLib.cyl(v, 0.3, 0.3, 0.08, Color("222222"), Vector3(-0.45, 0.3, -0.65), 10).rotation_degrees.z = 90
				AssetLib.cyl(v, 0.3, 0.3, 0.08, Color("222222"), Vector3(0.45, 0.3, -0.65), 10).rotation_degrees.z = 90
				AssetLib.box(v, Vector3(1.0, 0.5, 0.8), Color("7f8c8d"), Vector3(0, 0.7, -0.9))
			v.set_meta("seat", 0.25)
		5:  # moto
			AssetLib.box(v, Vector3(0.35, 0.45, 1.5), paint if paint.a > 0.0 else Color("c0392b"), Vector3(0, 0.6, 0))
			AssetLib.cyl(v, 0.32, 0.32, 0.15, Color("222222"), Vector3(0, 0.32, 0.7), 10).rotation_degrees.z = 90
			AssetLib.cyl(v, 0.32, 0.32, 0.15, Color("222222"), Vector3(0, 0.32, -0.7), 10).rotation_degrees.z = 90
			AssetLib.box(v, Vector3(0.7, 0.5, 0.5), Color("34495e"), Vector3(0, 0.9, -0.85))
			v.set_meta("seat", 0.35)
		_:  # camioneta, furgoneta, camiones
			var specs := {6: [Vector3(1.9, 0.9, 3.6), Color("2980b9")], 7: [Vector3(2.0, 1.8, 4.0), Color("ecf0f1")],
				8: [Vector3(2.2, 2.0, 4.8), Color("f39c12")], 9: [Vector3(2.4, 2.4, 5.6), Color("27ae60")]}
			var s: Array = specs[mini(t, 9)]
			var size: Vector3 = s[0]
			var col: Color = paint if paint.a > 0.0 else s[1]
			AssetLib.box(v, Vector3(size.x, 1.1, 1.4), col.darkened(0.1), Vector3(0, 1.0, size.z * 0.5 - 0.7))
			AssetLib.box(v, Vector3(size.x * 0.9, 0.5, 0.05), Color("bfe6ff"), Vector3(0, 1.3, size.z * 0.5 + 0.01))
			AssetLib.box(v, Vector3(size.x, size.y, size.z - 1.5), col, Vector3(0, 0.55 + size.y * 0.5, -0.75))
			if t >= 9:
				AssetLib.box(v, Vector3(size.x + 0.05, 0.3, 0.3), Color("f1c40f"), Vector3(0, 1.6, -0.75))
			for wx in [-size.x * 0.5, size.x * 0.5]:
				for wz in [size.z * 0.35, -size.z * 0.35]:
					AssetLib.cyl(v, 0.42, 0.42, 0.3, Color("222222"), Vector3(wx, 0.42, wz), 10).rotation_degrees.z = 90
			v.set_meta("seat", -10.0)  # oculto dentro de la cabina
	return v


func _input_vector() -> Vector2:
	var v := Vector2.ZERO
	if joystick != null:
		v = joystick.output
	var k := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	if Input.is_physical_key_pressed(KEY_D): k.x += 1
	if Input.is_physical_key_pressed(KEY_A): k.x -= 1
	if Input.is_physical_key_pressed(KEY_S): k.y += 1
	if Input.is_physical_key_pressed(KEY_W): k.y -= 1
	if k.length() > 0.1:
		v = k.limit_length(1.0)
	return v


func _physics_process(delta: float) -> void:
	var iv := _input_vector()
	_moving = iv.length() > 0.08
	if _moving:
		var dir := SCREEN_RIGHT * iv.x + SCREEN_UP * (-iv.y)
		var step := dir * GameState.move_speed() * delta
		var np := world.resolve_obstacles(position + step, 0.45)
		if world.is_walkable(np):
			position = np
		else:
			# Deslizar por los ejes
			var px := world.resolve_obstacles(position + Vector3(step.x, 0, 0), 0.45)
			var pz := world.resolve_obstacles(position + Vector3(0, 0, step.z), 0.45)
			if world.is_walkable(px):
				position = px
			elif world.is_walkable(pz):
				position = pz
			else:
				_maybe_locked_hint(np)
		_facing = atan2(dir.x, dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _facing, clampf(delta * 12.0, 0.0, 1.0))
	_animate(delta)
	_collect()
	_check_sell()


var _hint_cd: float = 0.0
func _maybe_locked_hint(p: Vector3) -> void:
	if _hint_cd > 0.0:
		return
	_hint_cd = 3.0
	var z: int = world.zone_at(p)
	if z >= GameState.zones_unlocked:
		GameState.toast.emit("Zona bloqueada. Desbloquéala en el menú Zonas.")


func _animate(delta: float) -> void:
	_hint_cd = maxf(0.0, _hint_cd - delta)
	if _model == null:
		return
	if AssetLib.has_model("player"):
		AssetLib.play_anim(_model, ["Running_A", "Walking_A", "Run", "Walk"] if _moving else ["Idle", "Idle_A"])
		return
	if _moving:
		_walk_t += delta * (6.0 + GameState.move_speed())
		_model.position.y = (float(_vehicle.get_meta("seat", 0.0)) if _vehicle else 0.0) + absf(sin(_walk_t)) * (0.12 if _vehicle == null else 0.03)
		_model.rotation.z = sin(_walk_t) * 0.06
	else:
		_walk_t += delta * 2.0
		_model.position.y = (float(_vehicle.get_meta("seat", 0.0)) if _vehicle else 0.0) + sin(_walk_t) * 0.02
		_model.rotation.z = 0.0


func _collect() -> void:
	if GameState.bag_count >= GameState.capacity():
		return
	var r2 := GameState.collect_radius() * GameState.collect_radius()
	var picked: Array = []
	for t in world.trash:
		var tn: Node3D = t
		var d := Vector2(tn.position.x - position.x, tn.position.z - position.z).length_squared()
		if d <= r2:
			picked.append(tn)
	for tn in picked:
		if GameState.add_to_bag(int(tn.get_meta("mat")), int(tn.get_meta("zone"))):
			world.take_trash(tn, self)
		else:
			break


func _check_sell() -> void:
	if GameState.bag_count <= 0:
		return
	for s in world.sell_points:
		var sp: Vector3 = s
		if Vector2(sp.x - position.x, sp.z - position.z).length() <= world.SELL_RADIUS:
			GameState.sell_bag(sp)
			return
