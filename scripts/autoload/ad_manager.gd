extends Node
## Gestor de anuncios recompensados VOLUNTARIOS.
##
## - En Android con el plugin de AdMob instalado (ver docs/ADMOB.md) usa
##   anuncios reales con los IDs configurados abajo.
## - En navegador / escritorio / sin plugin muestra un anuncio SIMULADO para
##   poder probar el flujo completo sin conexión y sin cuentas.
##
## El juego nunca obliga a ver anuncios: solo se muestran al pulsar un botón.

signal simulated_ad_requested(kind: String)
signal ad_finished(kind: String, rewarded: bool)

## IDs DE PRUEBA oficiales de Google. Sustitúyelos por los tuyos al publicar.
const ANDROID_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ANDROID_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

var _plugin: Object = null
var _pending_kind: String = ""
var _loaded: bool = false


func _ready() -> void:
	# Compatible con plugins que exponen un singleton "AdMob" (p. ej.
	# godot-admob-android). Si no existe, se usa el modo simulado.
	if Engine.has_singleton("AdMob"):
		_plugin = Engine.get_singleton("AdMob")
		_connect_plugin()


func is_real() -> bool:
	return _plugin != null


func can_show() -> bool:
	return GameState.ad_cooldown <= 0.0


func show_rewarded(kind: String) -> void:
	if not can_show():
		GameState.toast.emit("Espera %ds para otro anuncio." % int(ceil(GameState.ad_cooldown)))
		return
	_pending_kind = kind
	if _plugin != null:
		if _loaded and _plugin.has_method("show_rewarded_ad"):
			_plugin.call("show_rewarded_ad")
		else:
			GameState.toast.emit("Cargando anuncio, inténtalo en unos segundos.")
			_load_ad()
	else:
		simulated_ad_requested.emit(kind)


## Llamado por la UI cuando termina el anuncio simulado.
func finish_simulated(rewarded: bool) -> void:
	_complete(rewarded)


func _complete(rewarded: bool) -> void:
	var k := _pending_kind
	_pending_kind = ""
	if rewarded and k != "":
		GameState.grant_ad_reward(k)
	ad_finished.emit(k, rewarded)


# ------------------------------------------------- integración plugin real

func _connect_plugin() -> void:
	for pair in [["rewarded_ad_loaded", "_on_loaded"], ["user_earned_rewarded", "_on_earned"],
			["rewarded_ad_closed", "_on_closed"], ["rewarded_ad_failed_to_load", "_on_failed"]]:
		if _plugin.has_signal(pair[0]):
			_plugin.connect(pair[0], Callable(self, pair[1]))
	if _plugin.has_method("initialize"):
		_plugin.call("initialize")
	_load_ad()


func _load_ad() -> void:
	if _plugin != null and _plugin.has_method("load_rewarded_ad"):
		_plugin.call("load_rewarded_ad", ANDROID_REWARDED_ID)


func _on_loaded(_a = null) -> void:
	_loaded = true


func _on_earned(_a = null, _b = null) -> void:
	_loaded = false
	_complete(true)
	_load_ad()


func _on_closed(_a = null) -> void:
	if _pending_kind != "":
		_complete(false)
	_load_ad()


func _on_failed(_a = null, _b = null) -> void:
	_loaded = false
