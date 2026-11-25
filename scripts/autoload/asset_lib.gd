extends Node
## Carga modelos GLB/GLTF (KayKit, Quaternius, Kenney…) si existen en
## res://assets/models/. Si no, devuelve una geometría low poly procedural,
## así el juego funciona siempre y mejora al añadir los paquetes.
## Ver docs/ASSETS.md para la lista de nombres de archivo esperados.

const MODEL_DIR := "res://assets/models/"

var _scene_cache: Dictionary = {}
var _mat_cache: Dictionary = {}


func has_model(key: String) -> bool:
	return _find_path(key) != ""


func _find_path(key: String) -> String:
	for ext in [".glb", ".gltf", ".tscn"]:
		var p: String = MODEL_DIR + key + ext
		if ResourceLoader.exists(p):
			return p
	return ""


## Devuelve una instancia del modelo `key` o null si no existe.
func instance(key: String) -> Node3D:
	var p := _find_path(key)
	if p == "":
		return null
	if not _scene_cache.has(p):
		_scene_cache[p] = load(p)
	var ps: PackedScene = _scene_cache[p]
	return ps.instantiate() as Node3D if ps else null


func mat(c: Color, metallic: float = 0.0, emission: bool = false) -> StandardMaterial3D:
	var key := "%s_%.2f_%s" % [c.to_html(), metallic, emission]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85 if metallic < 0.1 else 0.35
	m.metallic = metallic
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.6
	_mat_cache[key] = m
	return m


# ------------------------------------------------ primitivas low poly

func box(parent: Node3D, size: Vector3, c: Color, pos: Vector3, metallic: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(c, metallic)
	mi.position = pos
	parent.add_child(mi)
	return mi


func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, c: Color, pos: Vector3, seg: int = 8, metallic: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat(c, metallic)
	mi.position = pos
	parent.add_child(mi)
	return mi


func sphere(parent: Node3D, r: float, c: Color, pos: Vector3, seg: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = maxi(3, seg / 2)
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func prism(parent: Node3D, size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Personaje humanoide simple (fallback si no hay modelo KayKit).
func humanoid(parent: Node3D, shirt: Color, pants: Color = Color("34495e"), skin: Color = Color("f1c27d"), hat: Color = Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	parent.add_child(root)
	cyl(root, 0.14, 0.14, 0.6, pants, Vector3(-0.13, 0.3, 0), 6)
	cyl(root, 0.14, 0.14, 0.6, pants, Vector3(0.13, 0.3, 0), 6)
	box(root, Vector3(0.6, 0.65, 0.36), shirt, Vector3(0, 0.92, 0))
	cyl(root, 0.09, 0.09, 0.55, shirt, Vector3(-0.38, 0.95, 0), 6)
	cyl(root, 0.09, 0.09, 0.55, shirt, Vector3(0.38, 0.95, 0), 6)
	sphere(root, 0.27, skin, Vector3(0, 1.5, 0), 8)
	box(root, Vector3(0.06, 0.06, 0.02), Color.BLACK, Vector3(-0.1, 1.55, 0.26))
	box(root, Vector3(0.06, 0.06, 0.02), Color.BLACK, Vector3(0.1, 1.55, 0.26))
	if hat.a > 0.0:
		cyl(root, 0.29, 0.29, 0.12, hat, Vector3(0, 1.72, 0), 8)
		box(root, Vector3(0.36, 0.04, 0.22), hat, Vector3(0, 1.67, 0.3))
	return root


## Intenta reproducir una animación por nombre en un modelo importado.
func play_anim(model: Node, names: Array) -> void:
	var ap := _find_anim_player(model)
	if ap == null:
		return
	for n in names:
		if ap.has_animation(n):
			if ap.current_animation != n:
				ap.play(n, 0.2)
			return


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null
