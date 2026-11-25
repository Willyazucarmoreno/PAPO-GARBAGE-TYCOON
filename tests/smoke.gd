extends Node
## Prueba de humo automática: `godot --path . -- --smoke [--shots=dir]`
## Recorre la economía, menús, trabajadores y zonas; guarda capturas.

var world: World
var shots_dir: String = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	_run.call_deferred()


func _shot(n: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(n + ".png"))


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	var ui := world.ui
	if ui._dialog:
		ui._dialog.queue_free()
		ui._dialog = null
		ui.joystick.enabled = true
	await _wait(30)
	await _shot("01_inicio")
	# Caminar recogiendo
	ui.joystick.output = Vector2(0.6, -0.8)
	await _wait(120)
	ui.joystick.output = Vector2.ZERO
	print("SMOKE recogidos=", GameState.stats["collected"], " carga=", GameState.bag_count)
	# Vender: teletransportar al punto de venta
	world.player.position = world.sell_points[0]
	await _wait(5)
	print("SMOKE dinero tras vender=", GameState.money)
	assert(GameState.stats["sales"] >= 1 or GameState.stats["collected"] == 0)
	# Economía
	GameState.money = 1e9
	for i in 13:
		assert(GameState.buy_next_tier())
	for u in GameData.UPGRADES:
		for k in 3:
			GameState.buy_upgrade(u["id"])
	for w in GameData.WORKERS:
		assert(GameState.hire(w["id"]))
	assert(GameState.level_up_worker(0))
	for i in 11:
		assert(GameState.unlock_next_zone())
	GameState.eco = 100
	assert(GameState.buy_eco_boost())
	assert(GameState.buy_eco_cash())
	await _wait(60)
	for tab in ["mejoras", "progreso", "personal", "zonas", "logros", "tienda"]:
		ui.open_tab(tab)
		await _wait(3)
		if tab in ["personal", "tienda"]:
			await _shot("02_menu_" + tab)
	ui.close_panel()
	for a in GameData.ACHIEVEMENTS:
		GameState.claim_achievement(a["id"])
	AdManager.show_rewarded("eco")
	await _wait(10)
	await _shot("03_anuncio")
	await get_tree().create_timer(4.5).timeout
	print("SMOKE eco tras anuncio=", GameState.eco, " ads=", GameState.stats["ads"])
	await _wait(240)
	await _shot("04_trabajadores")
	world.player.position = world.zone_center(11)
	await _wait(40)
	await _shot("05_ciudad_futurista")
	world.player.position = world.zone_center(5)
	await _wait(40)
	await _shot("06_playa")
	GameState.save_game()
	print("SMOKE workers=", world.workers_root.get_child_count(), " trash=", world.trash.size(), " money=", GameData.fmt(GameState.money))
	print("SMOKE OK")
	# No contaminar partidas reales
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	get_tree().quit()
