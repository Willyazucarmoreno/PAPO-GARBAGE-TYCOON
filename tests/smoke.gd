extends Node
## Prueba automática: `godot --path . -- --smoke [--shots=dir]`

var world: World
var shots_dir: String = ""
var fails: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("SMOKE FALLO: ", what)


func _shot(n: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(n + ".png"))


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _ad(kind: String) -> void:
	AdManager.cooldown = 0.0
	check(AdManager.request(kind), "pedir anuncio " + kind)
	await _wait(2)
	world.ui._close_ad(true)


func _run() -> void:
	var ui := world.ui
	await _wait(5)
	await _shot("00_dialogo")
	ui.close_dialogs()
	await _wait(25)
	await _shot("01_inicio")
	# FASE 1: mover, recoger, vender, mejorar
	var start := world.player.position
	ui.joystick.output = Vector2(0.6, -0.8)
	await _wait(120)
	ui.joystick.output = Vector2.ZERO
	check(world.player.position.distance_to(start) > 3.0, "el jugador se mueve")
	for k in 5:
		var t: Node3D = world.trash[0]
		world.player.position = t.position
		await _wait(3)
	check(int(GameState.stats["collected"]) >= 5, "recoger basura")
	var bag := GameState.bag_count
	world.player.position = world.sell_points[0]
	await _wait(5)
	check(GameState.bag_count == 0 and GameState.money > 0.0, "vender (bolsa %d)" % bag)
	GameState.money += 100
	check(GameState.buy_upgrade("velocidad"), "comprar mejora")
	check(GameState.levels.level >= 1 and GameState.levels.xp > 0.0, "experiencia")
	# Limpieza visual
	var clean_before := float(GameState.zone_clean[0])
	for k in 20:
		GameState.add_to_bag(0, 0)
	check(float(GameState.zone_clean[0]) > clean_before, "la zona se limpia")
	# FASE 4: anuncios
	AdManager.consent = "unknown"
	check(not AdManager.request("eco"), "sin consentimiento no hay anuncio")
	ui.close_dialogs()
	AdManager.set_consent("non_personalized")
	var eco0 := GameState.eco
	AdManager.cooldown = 0.0
	AdManager.request("eco")
	var rid := ui._ad_id
	await _wait(2)
	await _shot("02_anuncio")
	AdManager.confirm_reward(rid)
	AdManager.confirm_reward(rid)
	check(GameState.eco == eco0 + GameData.AD_ECO_REWARD, "recompensa única (eco %d→%d)" % [eco0, GameState.eco])
	AdManager.cooldown = 0.0
	AdManager.request("eco")
	world.ui._close_ad(false)
	check(GameState.eco == eco0 + GameData.AD_ECO_REWARD, "cerrar anuncio no recompensa")
	world.player.position = world.sell_points[0] + Vector3(0, 0, 8)
	GameState.add_to_bag(5, 0)
	world.player.position = world.sell_points[0]
	await _wait(3)
	var m0 := GameState.money
	await _ad("sale_x2")
	check(GameState.money > m0, "venta x2")
	for k in ["production", "speed", "truck", "temp_worker", "materials"]:
		await _ad(k)
	check(GameState.boosts.active("production") and GameState.boosts.active("speed") and GameState.boosts.active("truck"), "potenciadores")
	check(GameState.workers.size() == 1 and GameState.workers[0].has("expires"), "trabajador temporal")
	await _wait(30)
	await _shot("03_camion_especial")
	check(GameState.claim_daily(), "recompensa diaria")
	await _ad("daily_extra")
	await _ad("eco")
	await _ad("eco")
	AdManager.cooldown = 0.0
	check(AdManager.remaining_today() == 0 and not AdManager.request("eco"), "límite diario 10 (quedan %d)" % AdManager.remaining_today())
	# FASE 2-3: economía completa
	GameState.money = 1e9
	for i in 13:
		check(GameState.buy_next_tier(), "nivel %d" % (i + 1))
	for u in GameData.UPGRADES:
		for k in 3:
			GameState.buy_upgrade(u["id"])
	for w in GameData.WORKERS:
		check(GameState.hire(w["id"]), "contratar " + w["id"])
	check(GameState.level_up_worker(1), "subir trabajador")
	for i in 11:
		check(GameState.unlock_next_zone(), "zona %d" % (i + 2))
	GameState.eco = 200
	check(GameState.buy_or_equip_cosmetic("shirt_blue") and GameState.buy_or_equip_cosmetic("veh_chrome"), "personalización")
	check(GameState.missions.list("daily").size() == 3 and GameState.missions.list("weekly").size() == 3, "misiones")
	var ev := PapoEvents.active(GameData.EVENTS, "", Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 31}))
	check(ev.get("id", "") == "halloween", "evento Halloween")
	ev = PapoEvents.active(GameData.EVENTS, "", Time.get_unix_time_from_datetime_dict({"year": 2027, "month": 1, "day": 2}))
	check(ev.get("id", "") == "anio_nuevo", "evento Año Nuevo")
	await _wait(30)
	for tab in ["mejoras", "progreso", "personal", "zonas", "misiones", "tienda", "estilo", "ajustes"]:
		ui.open_tab(tab)
		await _wait(3)
		if tab in ["misiones", "tienda", "estilo"]:
			await _shot("04_menu_" + tab)
	ui.close_panel()
	for a in GameData.ACHIEVEMENTS:
		GameState.claim_achievement(a["id"])
	await _wait(200)
	await _shot("05_trabajadores")
	world.player.position = world.zone_center(11)
	await _wait(40)
	await _shot("06_ciudad_futurista")
	# Guardado y carga
	GameState.save_game()
	var money_saved := GameState.money
	GameState.load_game()
	check(absf(GameState.money - money_saved) < 1.0 and GameState.tier == 13, "guardar/cargar")
	print("SMOKE workers=", world.workers_root.get_child_count(), " trash=", world.trash.size(), " nivel=", GameState.levels.level)
	print("SMOKE OK" if fails == 0 else "SMOKE FALLOS=%d" % fails)
	PapoSave.erase(GameState.SAVE_PATH)
	get_tree().quit(0 if fails == 0 else 1)
