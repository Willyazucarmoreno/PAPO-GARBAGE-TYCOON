class_name World
extends Node3D
## Mundo: zonas, decoración procedural low poly, basura, puntos de venta,
## cámara isométrica, jugador y trabajadores.

const ZONE_SIZE := 40.0
const TRASH_PER_ZONE := 22
const SPAWN_INTERVAL := 0.35
const SELL_RADIUS := 3.2

const PlayerScript := preload("res://scripts/world/player.gd")
const WorkerScript := preload("res://scripts/world/worker.gd")
const UIScript := preload("res://scripts/ui/ui.gd")

var trash: Array = []                 # Array[Node3D]
var zone_trash_count: PackedInt32Array = PackedInt32Array()
var zone_nodes: Array = []
var obstacles: Array = []             # [Vector3 pos, float radius]
var sell_points: Array = []           # Array[Vector3]
var sell_nodes: Array = []

var player: Player
var camera: Camera3D
var ui: GameUI
var workers_root: Node3D
var trash_root: Node3D
var sell_root: Node3D

var _trash_meshes: Array = []
var _spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _cam_zoom: float = 19.0


func _ready() -> void:
	_rng.randomize()
	zone_trash_count.resize(GameData.ZONES.size())
	_build_environment()
	_build_trash_meshes()
	trash_root = _child("Trash")
	sell_root = _child("SellPoints")
	workers_root = _child("Workers")
	for i in GameData.ZONES.size():
		zone_nodes.append(null)
		_build_zone(i)
	_rebuild_sell_points()

	player = PlayerScript.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	player.position = zone_center(0) + Vector3(0, 0, 6)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _cam_zoom
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	_update_camera(1.0)

	ui = UIScript.new()
	ui.world = self
	add_child(ui)
	player.joystick = ui.joystick

	for i in GameState.zones_unlocked:
		for _k in GameState.zone_trash_cap(i, TRASH_PER_ZONE):
			_spawn_trash_in(i)
	_sync_workers()
	GameState.zone_clean_changed.connect(_update_dirt)
	GameState.spawn_bonus_materials.connect(_spawn_bonus)

	GameState.zones_changed.connect(_on_zones_changed)
	GameState.tier_changed.connect(_on_tier_changed)
	GameState.workers_changed.connect(_sync_workers)
	GameState.sold.connect(_on_sold)

	if "--smoke" in OS.get_cmdline_user_args():
		var smoke: Node = load("res://tests/smoke.gd").new()
		smoke.set("world", self)
		add_child(smoke)


func _child(n: String) -> Node3D:
	var c := Node3D.new()
	c.name = n
	add_child(c)
	return c


# ----------------------------------------------------------- geometría

func zone_center(i: int) -> Vector3:
	var row := i / 3
	var c := i % 3
	var col := c if row % 2 == 0 else 2 - c
	return Vector3((col - 1) * ZONE_SIZE, 0.0, -row * ZONE_SIZE)


func zone_at(p: Vector3) -> int:
	for i in GameData.ZONES.size():
		var c := zone_center(i)
		if absf(p.x - c.x) <= ZONE_SIZE * 0.5 and absf(p.z - c.z) <= ZONE_SIZE * 0.5:
			return i
	return -1


func is_walkable(p: Vector3) -> bool:
	var z := zone_at(p)
	return z >= 0 and z < GameState.zones_unlocked


## Empuja un punto fuera de los obstáculos (colisión circular barata).
func resolve_obstacles(p: Vector3, r: float) -> Vector3:
	var out := p
	for o in obstacles:
		var op: Vector3 = o[0]
		var orad: float = o[1]
		var d := Vector2(out.x - op.x, out.z - op.z)
		var min_d := orad + r
		var l := d.length()
		if l < min_d:
			if l < 0.001:
				d = Vector2(1, 0)
				l = 1.0
			var push := d / l * min_d
			out.x = op.x + push.x
			out.z = op.z + push.y
	return out


func nearest_sell_point(p: Vector3) -> Vector3:
	var best := sell_points[0] as Vector3
	var bd := INF
	for s in sell_points:
		var sp: Vector3 = s
		var d := sp.distance_squared_to(p)
		if d < bd:
			bd = d
			best = sp
	return best


# ----------------------------------------------------------- entorno

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("6fb7e6")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe9f2")
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = bool(GameState.settings.get("shadows", true))
	sun.name = "Sun"
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

	# Agua alrededor del mapa
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	water.mesh = pm
	water.material_override = AssetLib.mat(Color("3d9be0"))
	water.position = Vector3(0, -0.6, -60)
	add_child(water)


func _build_zone(i: int) -> void:
	if zone_nodes[i] != null:
		(zone_nodes[i] as Node3D).queue_free()
	var zd: Dictionary = GameData.ZONES[i]
	var root := Node3D.new()
	root.name = "Zone%d" % i
	add_child(root)
	zone_nodes[i] = root
	var c := zone_center(i)
	root.position = c
	var unlocked := i < GameState.zones_unlocked
	var gcol: Color = zd["ground"]
	if not unlocked:
		gcol = gcol.darkened(0.45)
	AssetLib.box(root, Vector3(ZONE_SIZE - 0.3, 0.5, ZONE_SIZE - 0.3), gcol, Vector3(0, -0.25, 0))
	# Calles en cruz
	if zd["decor"] not in ["beach", "island", "landfill"]:
		var road := Color("55585c") if unlocked else Color("2f3133")
		AssetLib.box(root, Vector3(ZONE_SIZE - 0.3, 0.06, 4.0), road, Vector3(0, 0.02, 0))
		AssetLib.box(root, Vector3(4.0, 0.06, ZONE_SIZE - 0.3), road, Vector3(0, 0.02, 0))
		for k in range(-4, 5):
			AssetLib.box(root, Vector3(1.2, 0.07, 0.18), Color("f5f5f5"), Vector3(k * 4.0, 0.03, 0))
	_remove_obstacles_near(c)
	_decorate(root, i, zd["decor"], unlocked)
	if unlocked:
		var dirt := Node3D.new()
		dirt.name = "Dirt"
		root.add_child(dirt)
		_update_dirt(i)
		if not GameState.event.is_empty():
			_event_deco(root, i)
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = not unlocked
	lbl.font_size = 96 if unlocked else 120
	lbl.outline_size = 18
	lbl.pixel_size = 0.012
	if unlocked:
		lbl.text = zd["name"]
		lbl.position = Vector3(0, 5.5, -ZONE_SIZE * 0.42)
		lbl.modulate = Color(1, 1, 1, 0.85)
	else:
		lbl.text = "%s\nBloqueado: $%s" % [zd["name"], GameData.fmt(float(zd["cost"]))]
		lbl.position = Vector3(0, 6.0, 0)
		lbl.modulate = Color("ffd54a")
	root.add_child(lbl)


func _remove_obstacles_near(c: Vector3) -> void:
	var keep: Array = []
	for o in obstacles:
		var op: Vector3 = o[0]
		if absf(op.x - c.x) > ZONE_SIZE * 0.5 or absf(op.z - c.z) > ZONE_SIZE * 0.5:
			keep.append(o)
	obstacles = keep


func _add_obstacle(root: Node3D, local: Vector3, r: float) -> void:
	obstacles.append([root.position + local, r])


## Posiciones libres en los 4 cuadrantes (fuera de las calles).
func _lot(rng: RandomNumberGenerator) -> Vector3:
	var sx := 1.0 if rng.randf() < 0.5 else -1.0
	var sz := 1.0 if rng.randf() < 0.5 else -1.0
	return Vector3(sx * rng.randf_range(5.5, ZONE_SIZE * 0.5 - 3.0), 0, sz * rng.randf_range(5.5, ZONE_SIZE * 0.5 - 3.0))


func _decorate(root: Node3D, zi: int, kind: String, unlocked: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + zi * 7919
	var dim := 1.0 if unlocked else 0.55
	match kind:
		"houses":
			for k in 8:
				_house(root, _lot(rng), rng, dim)
			for k in 10:
				_tree(root, _lot(rng), rng, dim)
			_recycling_center(root, Vector3(-8, 0, 10))
		"park":
			for k in 22:
				_tree(root, _lot(rng), rng, dim)
			for k in 4:
				var p := _lot(rng)
				AssetLib.box(root, Vector3(2.0, 0.5, 0.6), Color("8b5a2b") * dim, p + Vector3(0, 0.45, 0))
				_add_obstacle(root, p, 1.0)
			AssetLib.cyl(root, 3.0, 3.2, 0.4, Color("3f9de0") * dim, Vector3(9, 0.2, 9), 12)
			_add_obstacle(root, Vector3(9, 0, 9), 3.2)
		"market":
			for k in 12:
				_stall(root, _lot(rng), rng, dim)
			for k in 5:
				_tree(root, _lot(rng), rng, dim)
		"mall":
			_building(root, Vector3(-10, 0, -10), Vector3(12, 6, 10), Color("e0e4e8") * dim, Color("4aa3df") * dim)
			_building(root, Vector3(10, 0, 10), Vector3(12, 5, 10), Color("f4e3c1") * dim, Color("e67e22") * dim)
			for k in 8:
				_car(root, _lot(rng), rng, dim)
			for k in 6:
				_tree(root, _lot(rng), rng, dim)
		"city":
			for k in 9:
				var p := _lot(rng)
				var h := rng.randf_range(6.0, 16.0)
				_building(root, p, Vector3(5, h, 5), Color.from_hsv(rng.randf(), 0.15, 0.85) * dim, Color("9fd3f5") * dim)
			for k in 5:
				_car(root, _lot(rng), rng, dim)
		"beach":
			AssetLib.box(root, Vector3(ZONE_SIZE - 0.3, 0.1, 12), Color("4fb3e8") * dim, Vector3(0, 0.03, -14))
			for k in 10:
				var p := _lot(rng)
				if p.z < -8:
					p.z = -p.z
				_palm(root, p, dim)
			for k in 6:
				var p := _lot(rng)
				if p.z < -8:
					p.z = -p.z
				AssetLib.cyl(root, 0.0, 1.4, 0.7, Color.from_hsv(rng.randf(), 0.7, 0.95) * dim, p + Vector3(0, 2.2, 0), 8)
				AssetLib.cyl(root, 0.05, 0.05, 2.2, Color("eeeeee") * dim, p + Vector3(0, 1.1, 0), 4)
		"industrial":
			for k in 5:
				var p := _lot(rng)
				_building(root, p, Vector3(7, rng.randf_range(4, 7), 6), Color("9c8f7a") * dim, Color("5d6d7e") * dim)
				AssetLib.cyl(root, 0.6, 0.8, 9.0, Color("7b7d7d") * dim, p + Vector3(2.5, 4.5, 2.0), 8)
			for k in 6:
				_barrel(root, _lot(rng), rng, dim)
		"landfill":
			for k in 9:
				var p := _lot(rng)
				var r := rng.randf_range(2.0, 4.0)
				AssetLib.cyl(root, r * 0.3, r, r * 0.9, Color.from_hsv(0.08, 0.4, rng.randf_range(0.35, 0.55)) * dim, p + Vector3(0, r * 0.45, 0), 7)
				_add_obstacle(root, p, r * 0.9)
			for k in 6:
				_barrel(root, _lot(rng), rng, dim)
		"airport":
			AssetLib.box(root, Vector3(8, 0.08, ZONE_SIZE - 2), Color("3b3d40") * dim, Vector3(-12, 0.04, 0))
			_building(root, Vector3(10, 0, -10), Vector3(12, 5, 8), Color("dfe6e9") * dim, Color("74b9ff") * dim)
			AssetLib.cyl(root, 0.6, 0.8, 10, Color("dfe6e9") * dim, Vector3(12, 5, 10), 8)
			AssetLib.box(root, Vector3(2.4, 1.6, 2.4), Color("74b9ff") * dim, Vector3(12, 10.6, 10))
			_add_obstacle(root, Vector3(12, 0, 10), 1.2)
			_plane(root, Vector3(-12, 0, -8), dim)
		"port":
			AssetLib.box(root, Vector3(ZONE_SIZE - 0.3, 0.1, 10), Color("3d8fd1") * dim, Vector3(0, 0.03, -15))
			for k in 10:
				var p := _lot(rng)
				if p.z < -8:
					p.z = -p.z
				AssetLib.box(root, Vector3(2.4, 2.4, 5.5), Color.from_hsv(rng.randf(), 0.65, 0.8) * dim, p + Vector3(0, 1.2, 0))
				_add_obstacle(root, p, 2.6)
			AssetLib.box(root, Vector3(14, 3, 4), Color("c0392b") * dim, Vector3(-6, 1.0, -16))
		"island":
			AssetLib.box(root, Vector3(ZONE_SIZE - 0.3, 0.1, 9), Color("41b6e6") * dim, Vector3(0, 0.03, 15))
			AssetLib.box(root, Vector3(ZONE_SIZE - 0.3, 0.1, 9), Color("41b6e6") * dim, Vector3(0, 0.03, -15))
			for k in 14:
				var p := _lot(rng)
				p.z = clampf(p.z, -9, 9)
				_palm(root, p, dim)
		"future":
			for k in 9:
				var p := _lot(rng)
				var h := rng.randf_range(8.0, 20.0)
				_building(root, p, Vector3(4.5, h, 4.5), Color("2d3561") * dim, Color("00f5d4") * dim)
				AssetLib.sphere(root, 0.6, Color("f72585") * dim, p + Vector3(0, h + 0.8, 0), 6)
			for k in 6:
				_tree(root, _lot(rng), rng, dim)
	if not unlocked:
		_fence(root)


func _house(root: Node3D, p: Vector3, rng: RandomNumberGenerator, dim: float) -> void:
	var m := AssetLib.instance("house_%d" % (rng.randi() % 3 + 1))
	if m:
		m.position = p
		root.add_child(m)
	else:
		var wall := Color.from_hsv(rng.randf(), 0.25, 0.95) * dim
		AssetLib.box(root, Vector3(4, 3, 4), wall, p + Vector3(0, 1.5, 0))
		var roof := AssetLib.prism(root, Vector3(4.6, 1.8, 4.4), Color.from_hsv(rng.randf_range(0.0, 0.08), 0.65, 0.75) * dim, p + Vector3(0, 3.9, 0))
		roof.rotation_degrees.y = 90 if rng.randf() < 0.5 else 0
		AssetLib.box(root, Vector3(0.9, 1.6, 0.1), Color("6d4c41") * dim, p + Vector3(0, 0.8, 2.01))
		AssetLib.box(root, Vector3(0.8, 0.8, 0.1), Color("bfe6ff") * dim, p + Vector3(1.2, 1.9, 2.01))
	_add_obstacle(root, p, 2.6)


func _tree(root: Node3D, p: Vector3, rng: RandomNumberGenerator, dim: float) -> void:
	var m := AssetLib.instance("tree_%d" % (rng.randi() % 2 + 1))
	if m:
		m.position = p
		root.add_child(m)
	else:
		var s := rng.randf_range(0.8, 1.3)
		AssetLib.cyl(root, 0.18 * s, 0.25 * s, 1.4 * s, Color("7a4e2d") * dim, p + Vector3(0, 0.7 * s, 0), 6)
		if rng.randf() < 0.5:
			AssetLib.cyl(root, 0.0, 1.3 * s, 2.4 * s, Color("2e8b57") * dim, p + Vector3(0, 2.4 * s, 0), 7)
		else:
			AssetLib.sphere(root, 1.1 * s, Color("3cb043") * dim, p + Vector3(0, 2.2 * s, 0), 6)
	_add_obstacle(root, p, 0.7)


func _palm(root: Node3D, p: Vector3, dim: float) -> void:
	AssetLib.cyl(root, 0.15, 0.25, 3.5, Color("a0784e") * dim, p + Vector3(0, 1.75, 0), 6)
	for k in 5:
		var leaf := AssetLib.box(root, Vector3(0.4, 0.08, 2.2), Color("2fae4f") * dim, p + Vector3(0, 3.5, 0))
		leaf.rotation_degrees = Vector3(18, k * 72.0, 0)
		leaf.position += Vector3(sin(deg_to_rad(k * 72.0)), 0, cos(deg_to_rad(k * 72.0))) * 0.9
	_add_obstacle(root, p, 0.5)


func _stall(root: Node3D, p: Vector3, rng: RandomNumberGenerator, dim: float) -> void:
	AssetLib.box(root, Vector3(2.6, 1.0, 1.6), Color("a1662f") * dim, p + Vector3(0, 0.5, 0))
	for k in 3:
		AssetLib.sphere(root, 0.22, Color.from_hsv(rng.randf(), 0.8, 0.9) * dim, p + Vector3(-0.8 + k * 0.8, 1.15, 0), 6)
	var roof := AssetLib.prism(root, Vector3(3.0, 0.7, 2.0), Color.from_hsv(rng.randf(), 0.6, 0.95) * dim, p + Vector3(0, 2.4, 0))
	roof.rotation_degrees.y = 90
	AssetLib.cyl(root, 0.05, 0.05, 2.0, Color("dddddd") * dim, p + Vector3(-1.2, 1.0, 0.7), 4)
	AssetLib.cyl(root, 0.05, 0.05, 2.0, Color("dddddd") * dim, p + Vector3(1.2, 1.0, 0.7), 4)
	_add_obstacle(root, p, 1.6)


func _building(root: Node3D, p: Vector3, size: Vector3, wall: Color, glass: Color) -> void:
	AssetLib.box(root, size, wall, p + Vector3(0, size.y * 0.5, 0))
	var floors := int(size.y / 2.0)
	for f in floors:
		AssetLib.box(root, Vector3(size.x * 0.85, 0.7, 0.05), glass, p + Vector3(0, 1.2 + f * 2.0, size.z * 0.5 + 0.03))
	AssetLib.box(root, Vector3(size.x + 0.2, 0.3, size.z + 0.2), wall.darkened(0.2), p + Vector3(0, size.y + 0.15, 0))
	_add_obstacle(root, p, maxf(size.x, size.z) * 0.6)


func _car(root: Node3D, p: Vector3, rng: RandomNumberGenerator, dim: float) -> void:
	var m := AssetLib.instance("car")
	var body := Node3D.new()
	body.position = p
	body.rotation_degrees.y = 90.0 * (rng.randi() % 4)
	root.add_child(body)
	if m:
		body.add_child(m)
	else:
		AssetLib.box(body, Vector3(1.8, 0.7, 3.4), Color.from_hsv(rng.randf(), 0.7, 0.85) * dim, Vector3(0, 0.6, 0))
		AssetLib.box(body, Vector3(1.6, 0.6, 1.8), Color("bfe6ff") * dim, Vector3(0, 1.2, -0.2))
		for wx in [-0.9, 0.9]:
			for wz in [-1.1, 1.1]:
				var w := AssetLib.cyl(body, 0.32, 0.32, 0.25, Color("222222"), Vector3(wx, 0.32, wz), 8)
				w.rotation_degrees.z = 90
	_add_obstacle(root, p, 1.7)


func _barrel(root: Node3D, p: Vector3, rng: RandomNumberGenerator, dim: float) -> void:
	AssetLib.cyl(root, 0.45, 0.45, 1.1, Color.from_hsv(rng.randf_range(0.0, 0.15), 0.7, 0.7) * dim, p + Vector3(0, 0.55, 0), 8, 0.3)
	_add_obstacle(root, p, 0.5)


func _plane(root: Node3D, p: Vector3, dim: float) -> void:
	var w := Color("f5f6fa") * dim
	AssetLib.cyl(root, 0.8, 0.8, 10, w, p + Vector3(0, 1.6, 0), 8).rotation_degrees.x = 90
	AssetLib.box(root, Vector3(12, 0.25, 2.0), w, p + Vector3(0, 1.6, 0.5))
	AssetLib.box(root, Vector3(0.25, 2.2, 1.5), Color("e84118") * dim, p + Vector3(0, 2.8, 4.4))
	_add_obstacle(root, p + Vector3(0, 0, -3), 1.5)
	_add_obstacle(root, p + Vector3(0, 0, 3), 1.5)
	_add_obstacle(root, p, 1.5)


func _fence(root: Node3D) -> void:
	var h := ZONE_SIZE * 0.5 - 0.4
	var col := Color("e1b12c")
	for side in 4:
		var horizontal := side < 2
		var sgn := -1.0 if side % 2 == 0 else 1.0
		var pos := Vector3(0, 0.6, sgn * h) if horizontal else Vector3(sgn * h, 0.6, 0)
		var size := Vector3(ZONE_SIZE - 0.8, 0.25, 0.25) if horizontal else Vector3(0.25, 0.25, ZONE_SIZE - 0.8)
		AssetLib.box(root, size, col, pos)
		AssetLib.box(root, size, Color("2f3640"), pos + Vector3(0, 0.45, 0))


func _recycling_center(root: Node3D, p: Vector3) -> void:
	var m := AssetLib.instance("recycling_center")
	if m:
		m.position = p
		root.add_child(m)
	else:
		AssetLib.box(root, Vector3(7, 3.5, 5), Color("27ae60"), p + Vector3(0, 1.75, 0))
		AssetLib.box(root, Vector3(7.4, 0.4, 5.4), Color("1e8449"), p + Vector3(0, 3.7, 0))
		AssetLib.box(root, Vector3(2.6, 2.2, 0.1), Color("2c3e50"), p + Vector3(0, 1.1, 2.52))
		for k in 3:
			var cols := [Color("2980b9"), Color("f1c40f"), Color("7f8c8d")]
			AssetLib.box(root, Vector3(1.0, 1.3, 1.0), cols[k], p + Vector3(4.4, 0.65, -1.6 + k * 1.6))
	var lbl := Label3D.new()
	lbl.text = "CENTRO DE RECICLAJE PAPO"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 64
	lbl.outline_size = 14
	lbl.pixel_size = 0.012
	lbl.position = p + Vector3(0, 5.0, 0)
	root.add_child(lbl)
	_add_obstacle(root, p, 3.4)


# ----------------------------------------------------------- venta

func _rebuild_sell_points() -> void:
	for n in sell_nodes:
		(n as Node3D).queue_free()
	sell_nodes.clear()
	sell_points.clear()
	_add_sell_point(zone_center(0) + Vector3(-8, 0, 16.0))
	if GameState.sell_points_everywhere():
		for i in range(1, GameState.zones_unlocked):
			_add_sell_point(zone_center(i) + Vector3(-5, 0, 5))


func _add_sell_point(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	sell_root.add_child(n)
	var pad := AssetLib.cyl(n, SELL_RADIUS, SELL_RADIUS, 0.12, Color(0.18, 0.85, 0.4, 0.75), Vector3(0, 0.07, 0), 16)
	pad.material_override = AssetLib.mat(Color(0.18, 0.85, 0.4, 0.75), 0.0, true)
	AssetLib.cyl(n, 0.08, 0.08, 2.6, Color("ecf0f1"), Vector3(SELL_RADIUS - 0.3, 1.3, 0), 6)
	AssetLib.box(n, Vector3(1.6, 0.8, 0.08), Color("27ae60"), Vector3(SELL_RADIUS - 0.3, 2.5, 0))
	var lbl := Label3D.new()
	lbl.text = "VENDER"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 72
	lbl.outline_size = 14
	lbl.pixel_size = 0.01
	lbl.position = Vector3(0, 1.4, 0)
	n.add_child(lbl)
	sell_points.append(p)
	sell_nodes.append(n)


func _on_sold(amount: float, at: Vector3) -> void:
	if at == Vector3.ZERO:
		at = player.position
	float_text("+$%s" % GameData.fmt(amount), at + Vector3(0, 2.5, 0), Color("7CFC00"))


## Manchas de suciedad que desaparecen al limpiar la zona.
func _update_dirt(zi: int) -> void:
	if zone_nodes[zi] == null or zi >= GameState.zones_unlocked:
		return
	var dirt: Node3D = (zone_nodes[zi] as Node3D).get_node_or_null("Dirt")
	if dirt == null:
		return
	var want := int(ceil((1.0 - float(GameState.zone_clean[zi])) * 14.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + zi * 131
	while dirt.get_child_count() > want:
		var c := dirt.get_child(dirt.get_child_count() - 1)
		dirt.remove_child(c)
		c.queue_free()
	for k in range(dirt.get_child_count(), want):
		var p := Vector3(rng.randf_range(-17, 17), 0.03, rng.randf_range(-17, 17))
		for _s in k:
			p = Vector3(rng.randf_range(-17, 17), 0.03, rng.randf_range(-17, 17))
		var d := AssetLib.cyl(dirt, rng.randf_range(1.0, 2.2), rng.randf_range(1.2, 2.6), 0.04, Color(0.32, 0.25, 0.15, 0.55), p, 7)
		d.material_override = AssetLib.mat(Color(0.32, 0.25, 0.15, 0.55))


func _event_deco(root: Node3D, zi: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + zi
	var ec: Color = GameState.event.get("color", Color.WHITE)
	for k in 6:
		var p := _lot(rng)
		match str(GameState.event.get("deco", "")):
			"pumpkin":
				AssetLib.sphere(root, 0.6, Color("ff7f11"), p + Vector3(0, 0.5, 0), 8)
				AssetLib.cyl(root, 0.06, 0.08, 0.3, Color("2d6a4f"), p + Vector3(0, 1.15, 0), 5)
			"xmas":
				AssetLib.cyl(root, 0.0, 1.2, 2.6, Color("1b5e20"), p + Vector3(0, 1.5, 0), 7)
				AssetLib.sphere(root, 0.22, Color("ffd166"), p + Vector3(0, 2.9, 0), 6)
				AssetLib.sphere(root, 0.15, ec, p + Vector3(0.5, 1.2, 0.4), 6)
			"fireworks":
				AssetLib.cyl(root, 0.08, 0.08, 3.0, Color("dddddd"), p + Vector3(0, 1.5, 0), 5)
				var s := AssetLib.sphere(root, 0.45, Color.from_hsv(rng.randf(), 0.8, 1.0), p + Vector3(0, 3.2, 0), 6)
				s.material_override = AssetLib.mat(s.material_override.albedo_color, 0.0, true)
			"earth":
				AssetLib.sphere(root, 0.7, Color("2a9d8f"), p + Vector3(0, 0.9, 0), 8)
				AssetLib.box(root, Vector3(0.6, 0.1, 0.5), Color("52b788"), p + Vector3(0.2, 1.5, 0.2))


func _spawn_bonus(count: int) -> void:
	var zi := clampi(world_zone(player.position), 0, GameState.zones_unlocked - 1)
	var pool: Array = GameData.ZONES[GameState.zones_unlocked - 1]["pool"]
	for k in count:
		var mat := int(pool[mini(pool.size() - 1, pool.size() / 2 + _rng.randi() % maxi(1, pool.size() - pool.size() / 2))])
		var p := player.position + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
		if not is_walkable(p):
			p = player.position
		_add_trash(mat, zi, resolve_obstacles(p, 0.4))


func world_zone(p: Vector3) -> int:
	return maxi(0, zone_at(p))


func float_text(t: String, at: Vector3, col: Color) -> void:
	PapoUI.float_text_3d(self, t, at, col)



# ----------------------------------------------------------- basura

func _build_trash_meshes() -> void:
	for i in GameData.MATERIALS.size():
		var col: Color = GameData.MATERIALS[i]["color"]
		var mesh: Mesh
		match i:
			0:  # papel
				var b := BoxMesh.new(); b.size = Vector3(0.5, 0.06, 0.4); mesh = b
			1:  # cartón
				var b := BoxMesh.new(); b.size = Vector3(0.55, 0.45, 0.55); mesh = b
			2, 4:  # plástico / vidrio: botella
				var c := CylinderMesh.new(); c.top_radius = 0.07; c.bottom_radius = 0.16; c.height = 0.6; c.radial_segments = 7; mesh = c
			3:  # orgánico
				var s := SphereMesh.new(); s.radius = 0.28; s.height = 0.45; s.radial_segments = 6; s.rings = 3; mesh = s
			5, 8:  # lata / batería
				var c := CylinderMesh.new(); c.top_radius = 0.13; c.bottom_radius = 0.13; c.height = 0.38; c.radial_segments = 8; mesh = c
			6:  # hierro
				var b := BoxMesh.new(); b.size = Vector3(0.7, 0.2, 0.2); mesh = b
			7:  # cobre: bobina
				var t := TorusMesh.new(); t.inner_radius = 0.12; t.outer_radius = 0.28; t.rings = 8; t.ring_segments = 5; mesh = t
			9:  # electrónicos
				var b := BoxMesh.new(); b.size = Vector3(0.6, 0.12, 0.45); mesh = b
			_:  # plata / oro: lingote
				var p := PrismMesh.new(); p.size = Vector3(0.6, 0.25, 0.3); mesh = p
		var m := AssetLib.mat(col, 0.7 if i in [5, 6, 7, 10, 11] else 0.0, i >= 10)
		if i == 4:
			m = AssetLib.mat(Color(col.r, col.g, col.b, 0.75), 0.2)
		mesh.surface_set_material(0, m)
		_trash_meshes.append(mesh)


func _pick_material(zi: int) -> int:
	var pool: Array = GameData.ZONES[zi]["pool"]
	var total := 0.0
	for k in pool.size():
		total += 1.0 / (1.0 + k * 0.9)
	var r := _rng.randf() * total
	for k in pool.size():
		r -= 1.0 / (1.0 + k * 0.9)
		if r <= 0.0:
			return int(pool[k])
	return int(pool[0])


func _spawn_trash_in(zi: int) -> void:
	var c := zone_center(zi)
	var p := Vector3.ZERO
	for _attempt in 8:
		p = c + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * (ZONE_SIZE * 0.5 - 1.5)
		if resolve_obstacles(p, 0.4).distance_to(p) < 0.01:
			break
	_add_trash(_pick_material(zi), zi, p)


func _add_trash(mat: int, zi: int, p: Vector3) -> void:
	var t := MeshInstance3D.new()
	t.mesh = _trash_meshes[mat]
	t.position = p + Vector3(0, 0.2, 0)
	t.rotation.y = _rng.randf() * TAU
	t.set_meta("mat", mat)
	t.set_meta("zone", zi)
	t.set_meta("claimed", false)
	trash_root.add_child(t)
	trash.append(t)
	zone_trash_count[zi] += 1


## Retira la basura `t` del mapa (animación hacia `to`).
func take_trash(t: Node3D, to: Node3D) -> void:
	var idx := trash.find(t)
	if idx < 0:
		return
	trash.remove_at(idx)
	var zi: int = t.get_meta("zone")
	zone_trash_count[zi] = maxi(0, zone_trash_count[zi] - 1)
	var tw := t.create_tween()
	tw.tween_property(t, "position", to.position + Vector3(0, 1.2, 0), 0.18)
	tw.parallel().tween_property(t, "scale", Vector3.ONE * 0.2, 0.18)
	tw.tween_callback(t.queue_free)


func nearest_free_trash(p: Vector3, max_zone: int) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for t in trash:
		var tn: Node3D = t
		if tn.get_meta("claimed") or int(tn.get_meta("zone")) >= max_zone:
			continue
		var d := tn.position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = tn
	return best


# ----------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		var lowest := -1
		var low_ratio := 1.0
		for i in GameState.zones_unlocked:
			var r := float(zone_trash_count[i]) / float(maxi(1, GameState.zone_trash_cap(i, TRASH_PER_ZONE)))
			if r < low_ratio:
				low_ratio = r
				lowest = i
		if lowest >= 0:
			_spawn_trash_in(lowest)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if player == null or camera == null:
		return
	var target_zoom := 19.0 + GameState.tier * 0.6
	_cam_zoom = lerpf(_cam_zoom, target_zoom, clampf(delta * 2.0, 0.0, 1.0))
	camera.size = _cam_zoom
	var offset := Vector3(1, 1.15, 1).normalized() * 40.0
	var target := player.position + offset
	camera.position = camera.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0)) if delta < 1.0 else target
	camera.look_at(camera.position - offset, Vector3.UP)


func _on_zones_changed() -> void:
	for i in GameData.ZONES.size():
		_build_zone(i)
	_rebuild_sell_points()
	var zi := GameState.zones_unlocked - 1
	while zone_trash_count[zi] < GameState.zone_trash_cap(zi, TRASH_PER_ZONE):
		_spawn_trash_in(zi)


func _on_tier_changed() -> void:
	_rebuild_sell_points()
	player.rebuild_visual()


func set_shadows(on: bool) -> void:
	($Sun as DirectionalLight3D).shadow_enabled = on


func _sync_workers() -> void:
	var existing := workers_root.get_children()
	# Reconstruir si cambia el número; los niveles se leen en vivo.
	if existing.size() == GameState.workers.size():
		return
	for c in existing:
		workers_root.remove_child(c)
		c.queue_free()
	for i in GameState.workers.size():
		var w := WorkerScript.new()
		w.world = self
		w.index = i
		workers_root.add_child(w)
		w.position = sell_points[0] + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
