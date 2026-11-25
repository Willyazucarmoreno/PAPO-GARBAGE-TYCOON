extends Node
## Datos estáticos del juego: materiales, progresión, mejoras, trabajadores,
## zonas y logros. Todo el balance económico vive aquí.

var MATERIALS: Array = [
	{"id": "papel", "name": "Papel", "price": 1, "color": Color("f4f1e8")},
	{"id": "carton", "name": "Cartón", "price": 2, "color": Color("b07a45")},
	{"id": "plastico", "name": "Plástico", "price": 3, "color": Color("3d8fe0")},
	{"id": "organico", "name": "Residuos orgánicos", "price": 4, "color": Color("6b8e23")},
	{"id": "vidrio", "name": "Vidrio", "price": 5, "color": Color("5fd3a5")},
	{"id": "aluminio", "name": "Aluminio", "price": 10, "color": Color("c9d1d9")},
	{"id": "hierro", "name": "Hierro", "price": 15, "color": Color("5a5f66")},
	{"id": "cobre", "name": "Cobre", "price": 25, "color": Color("d9773a")},
	{"id": "baterias", "name": "Baterías", "price": 35, "color": Color("f2c230")},
	{"id": "electronicos", "name": "Electrónicos", "price": 50, "color": Color("2fa34a")},
	{"id": "plata", "name": "Plata", "price": 75, "color": Color("e8eef5")},
	{"id": "oro", "name": "Oro", "price": 100, "color": Color("ffcc33")},
]

## Progresión: índice 0 es el inicio (bolsa pequeña). 1..13 son desbloqueables.
## cap = capacidad de carga, speed = m/s, radius = radio de recogida,
## sell = multiplicador de venta, passive = $/s de ingreso pasivo.
var TIERS: Array = [
	{"name": "Bolsa pequeña", "cost": 0, "cap": 10, "speed": 4.5, "radius": 1.6, "sell": 1.0, "passive": 0.0, "desc": "Empiezas desde cero."},
	{"name": "Mochila", "cost": 40, "cap": 20, "speed": 4.7, "radius": 1.7, "sell": 1.0, "passive": 0.0, "desc": "El doble de carga."},
	{"name": "Carrito", "cost": 220, "cap": 35, "speed": 4.9, "radius": 1.9, "sell": 1.0, "passive": 0.0, "desc": "Empuja más material."},
	{"name": "Bicicleta", "cost": 750, "cap": 45, "speed": 6.8, "radius": 2.0, "sell": 1.0, "passive": 0.0, "desc": "Mucho más rápido."},
	{"name": "Triciclo", "cost": 2000, "cap": 70, "speed": 6.8, "radius": 2.2, "sell": 1.05, "passive": 0.0, "desc": "Velocidad y carga."},
	{"name": "Motocicleta", "cost": 5500, "cap": 90, "speed": 9.0, "radius": 2.4, "sell": 1.05, "passive": 0.0, "desc": "Recorre la ciudad volando."},
	{"name": "Camioneta", "cost": 14000, "cap": 150, "speed": 9.5, "radius": 2.7, "sell": 1.1, "passive": 2.0, "desc": "Tu primer vehículo de empresa."},
	{"name": "Furgoneta", "cost": 35000, "cap": 220, "speed": 10.0, "radius": 3.0, "sell": 1.1, "passive": 5.0, "desc": "Más espacio de carga."},
	{"name": "Camión pequeño", "cost": 85000, "cap": 350, "speed": 10.5, "radius": 3.3, "sell": 1.15, "passive": 12.0, "desc": "Logística seria."},
	{"name": "Camión recolector", "cost": 200000, "cap": 600, "speed": 11.0, "radius": 3.8, "sell": 1.2, "passive": 30.0, "desc": "El rey de la calle."},
	{"name": "Centro de reciclaje", "cost": 450000, "cap": 650, "speed": 11.0, "radius": 4.0, "sell": 1.35, "passive": 80.0, "desc": "Puntos de venta en todas tus zonas."},
	{"name": "Planta industrial", "cost": 1300000, "cap": 700, "speed": 11.5, "radius": 4.2, "sell": 1.6, "passive": 300.0, "desc": "Producción a gran escala."},
	{"name": "Empresa nacional", "cost": 5000000, "cap": 800, "speed": 12.0, "radius": 4.4, "sell": 2.0, "passive": 1200.0, "desc": "Líder del país."},
	{"name": "Empresa internacional", "cost": 22000000, "cap": 1000, "speed": 12.5, "radius": 4.6, "sell": 3.0, "passive": 5000.0, "desc": "Imperio mundial del reciclaje."},
]
const TIER_SELL_POINTS_EVERYWHERE := 10

var UPGRADES: Array = [
	{"id": "velocidad", "name": "Velocidad", "desc": "+5% velocidad de movimiento", "base": 20.0, "growth": 1.55, "max": 25},
	{"id": "capacidad", "name": "Capacidad", "desc": "+10% capacidad de carga", "base": 30.0, "growth": 1.6, "max": 25},
	{"id": "precio", "name": "Precio de venta", "desc": "+8% al vender materiales", "base": 60.0, "growth": 1.65, "max": 30},
	{"id": "almacen", "name": "Almacenamiento", "desc": "+20% capacidad de trabajadores", "base": 400.0, "growth": 1.7, "max": 20},
	{"id": "produccion", "name": "Producción", "desc": "+15% ingreso pasivo", "base": 1500.0, "growth": 1.75, "max": 25},
	{"id": "automatizacion", "name": "Automatización", "desc": "Nv1: venta remota al llenarte. +8% velocidad de trabajadores", "base": 2500.0, "growth": 1.8, "max": 20},
]

## kind: collector (recoge basura), sorter (+venta), producer ($/s),
## booster (+velocidad trabajadores), manager (+pasivo y ganancias offline).
var WORKERS: Array = [
	{"id": "recolector", "name": "Recolector", "kind": "collector", "cost": 120.0, "speed": 3.6, "cap": 8, "req_tier": 1, "color": Color("ff8c1a"), "desc": "Recoge basura a pie."},
	{"id": "conductor", "name": "Conductor", "kind": "collector", "cost": 9000.0, "speed": 7.5, "cap": 40, "req_tier": 6, "color": Color("2a6fdb"), "desc": "Conduce una camioneta de recogida."},
	{"id": "clasificador", "name": "Clasificador", "kind": "sorter", "cost": 1800.0, "speed": 0.0, "cap": 0, "req_tier": 3, "color": Color("27ae60"), "desc": "+4% precio de venta por nivel."},
	{"id": "operador", "name": "Operador", "kind": "producer", "cost": 6000.0, "speed": 0.0, "cap": 0, "req_tier": 5, "color": Color("8e44ad"), "desc": "Genera $3/s por nivel."},
	{"id": "supervisor", "name": "Supervisor", "kind": "booster", "cost": 25000.0, "speed": 0.0, "cap": 0, "req_tier": 7, "color": Color("c0392b"), "desc": "+8% velocidad de trabajadores por nivel."},
	{"id": "gerente", "name": "Gerente", "kind": "manager", "cost": 90000.0, "speed": 0.0, "cap": 0, "req_tier": 9, "color": Color("2c3e50"), "desc": "+10% ingreso pasivo por nivel y ganancias offline completas."},
	{"id": "robot", "name": "Robot", "kind": "collector", "cost": 600000.0, "speed": 9.0, "cap": 120, "req_tier": 11, "color": Color("95a5a6"), "desc": "Recolector automático incansable."},
]
const WORKER_MAX_LEVEL := 10
const MAX_WORKERS_PER_TYPE := 8

## decor: tipo de decoración procedural. pool: índices de materiales.
var ZONES: Array = [
	{"name": "Barrio residencial", "cost": 0, "pool": [0, 1, 2, 3], "ground": Color("7cc46a"), "decor": "houses"},
	{"name": "Parque", "cost": 350, "pool": [0, 1, 2, 3, 4], "ground": Color("5fb85a"), "decor": "park"},
	{"name": "Mercado", "cost": 2500, "pool": [1, 2, 3, 4, 5], "ground": Color("d9c38c"), "decor": "market"},
	{"name": "Centro comercial", "cost": 12000, "pool": [2, 4, 5, 6], "ground": Color("b9bec4"), "decor": "mall"},
	{"name": "Centro urbano", "cost": 40000, "pool": [4, 5, 6, 7], "ground": Color("9aa0a6"), "decor": "city"},
	{"name": "Playa", "cost": 110000, "pool": [2, 4, 5, 7], "ground": Color("f0dc9b"), "decor": "beach"},
	{"name": "Zona industrial", "cost": 300000, "pool": [5, 6, 7, 8], "ground": Color("8a8478"), "decor": "industrial"},
	{"name": "Vertedero", "cost": 800000, "pool": [6, 7, 8, 9], "ground": Color("8b7355"), "decor": "landfill"},
	{"name": "Aeropuerto", "cost": 2200000, "pool": [7, 8, 9, 10], "ground": Color("a7b0a0"), "decor": "airport"},
	{"name": "Puerto", "cost": 6000000, "pool": [7, 8, 9, 10], "ground": Color("8fa3ad"), "decor": "port"},
	{"name": "Isla", "cost": 15000000, "pool": [8, 9, 10, 11], "ground": Color("e8d590"), "decor": "island"},
	{"name": "Ciudad futurista", "cost": 40000000, "pool": [9, 10, 11], "ground": Color("6c7ae0"), "decor": "future"},
]

## Logros: stat = clave de GameState.stat_value(); reward = EcoCoins.
var ACHIEVEMENTS: Array = [
	{"id": "rec_10", "name": "Primeros pasos", "desc": "Recoge 10 residuos", "stat": "collected", "goal": 10, "reward": 2},
	{"id": "rec_100", "name": "Barrendero", "desc": "Recoge 100 residuos", "stat": "collected", "goal": 100, "reward": 5},
	{"id": "rec_1000", "name": "Limpiador urbano", "desc": "Recoge 1.000 residuos", "stat": "collected", "goal": 1000, "reward": 15},
	{"id": "rec_10000", "name": "Héroe ecológico", "desc": "Recoge 10.000 residuos", "stat": "collected", "goal": 10000, "reward": 50},
	{"id": "sell_1", "name": "Primera venta", "desc": "Vende en el centro de reciclaje", "stat": "sales", "goal": 1, "reward": 2},
	{"id": "sell_50", "name": "Comerciante", "desc": "Realiza 50 ventas", "stat": "sales", "goal": 50, "reward": 10},
	{"id": "earn_1k", "name": "Mil pesitos", "desc": "Gana $1.000 en total", "stat": "earned", "goal": 1000, "reward": 5},
	{"id": "earn_100k", "name": "Empresario", "desc": "Gana $100.000 en total", "stat": "earned", "goal": 100000, "reward": 20},
	{"id": "earn_10m", "name": "Magnate", "desc": "Gana $10.000.000 en total", "stat": "earned", "goal": 10000000, "reward": 60},
	{"id": "tier_3", "name": "Sobre ruedas", "desc": "Consigue la bicicleta", "stat": "tier", "goal": 3, "reward": 5},
	{"id": "tier_6", "name": "Al volante", "desc": "Consigue la camioneta", "stat": "tier", "goal": 6, "reward": 10},
	{"id": "tier_9", "name": "Camionero", "desc": "Consigue el camión recolector", "stat": "tier", "goal": 9, "reward": 25},
	{"id": "tier_13", "name": "Imperio mundial", "desc": "Funda la empresa internacional", "stat": "tier", "goal": 13, "reward": 100},
	{"id": "hire_1", "name": "Jefe", "desc": "Contrata tu primer trabajador", "stat": "workers", "goal": 1, "reward": 5},
	{"id": "hire_10", "name": "Plantilla", "desc": "Ten 10 trabajadores", "stat": "workers", "goal": 10, "reward": 20},
	{"id": "zone_3", "name": "Explorador", "desc": "Desbloquea 3 zonas", "stat": "zones", "goal": 3, "reward": 8},
	{"id": "zone_6", "name": "Conquistador", "desc": "Desbloquea 6 zonas", "stat": "zones", "goal": 6, "reward": 20},
	{"id": "zone_12", "name": "Dueño del mapa", "desc": "Desbloquea las 12 zonas", "stat": "zones", "goal": 12, "reward": 80},
	{"id": "ads_3", "name": "Patrocinado", "desc": "Mira 3 anuncios voluntarios", "stat": "ads", "goal": 3, "reward": 5},
]

## Recompensas por anuncio voluntario.
const AD_COOLDOWN := 45.0
const AD_ECO_REWARD := 5
const AD_BOOST_SECONDS := 180.0
const BOOST_ECO_COST := 15
const BOOST_ECO_SECONDS := 300.0


func worker_index(id: String) -> int:
	for i in WORKERS.size():
		if WORKERS[i]["id"] == id:
			return i
	return -1


func worker_def(id: String) -> Dictionary:
	var i := worker_index(id)
	return WORKERS[i] if i >= 0 else {}


func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


static func fmt(v: float) -> String:
	var a := absf(v)
	if a >= 1e12:
		return "%.2fT" % (v / 1e12)
	if a >= 1e9:
		return "%.2fB" % (v / 1e9)
	if a >= 1e6:
		return "%.2fM" % (v / 1e6)
	if a >= 1e4:
		return "%.1fK" % (v / 1e3)
	if a >= 100.0:
		return "%d" % int(v)
	return "%.1f" % v if fmod(v, 1.0) != 0.0 else "%d" % int(v)
