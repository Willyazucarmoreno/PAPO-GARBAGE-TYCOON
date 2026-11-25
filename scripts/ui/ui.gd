class_name GameUI
extends CanvasLayer
## Interfaz de PAPO Garbage Tycoon (usa PapoUI del motor).

var world: World
var joystick: VirtualJoystick

var _root: Control
var _money_lbl: Label
var _eco_lbl: Label
var _income_lbl: Label
var _level_lbl: Label
var _xp_bar: ProgressBar
var _load_bar: ProgressBar
var _load_lbl: Label
var _tier_lbl: Label
var _boost_lbl: Label
var _event_lbl: Label
var _sale_btn: Button
var _toast_box: VBoxContainer
var _panel: PanelContainer
var _panel_title: Label
var _panel_list: VBoxContainer
var _scroll: ScrollContainer
var _tab: String = ""
var _refresh_t: float = 0.0
var _tab_buttons: Dictionary = {}
var _ad_overlay: ColorRect
var _ad_lbl: Label
var _ad_time: float = 0.0
var _ad_id: int = 0
var _dialog: PanelContainer
var _dialog_queue: Array = []
var _reset_armed: bool = false

const C_PANEL := Color(0.08, 0.12, 0.14, 0.94)
const C_ACCENT := Color("27ae60")
const C_GOLD := Color("ffd32a")
const C_ECO := Color("48dbfb")
const C_DIM := Color("636e72")
const C_OK := Color("7bed9f")

const TABS := [
	["mejoras", "Mejoras"], ["progreso", "Vehículos"], ["personal", "Personal"], ["zonas", "Mapa"],
	["misiones", "Misiones"], ["tienda", "Tienda"], ["estilo", "Estilo"], ["ajustes", "Ajustes"],
]


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = PapoUI.make_theme(C_ACCENT, C_PANEL)
	add_child(_root)
	joystick = VirtualJoystick.new()
	_root.add_child(joystick)
	_build_hud()
	_build_bottom_bar()
	_build_panel()
	_build_toasts()
	_build_ad_overlay()

	GameState.toast.connect(show_toast)
	GameState.changed.connect(_on_changed)
	GameState.sold.connect(_on_sold)
	AdManager.simulated_requested.connect(_on_sim_ad)
	AdManager.consent_needed.connect(func() -> void: _queue(_show_consent))
	_on_changed()

	if GameState.pending_offline > 0.0:
		_queue(_show_offline_dialog)
	if not GameState.tutorial_done:
		_queue(_show_tutorial)
	if AdManager.consent == "unknown":
		_queue(_show_consent)
	if GameState.daily_available():
		_queue(_show_daily)


# ------------------------------------------------------------- HUD

func _build_hud() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 14
	_root.add_child(top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	top.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	_money_lbl = PapoUI.label("$0", 40, C_GOLD)
	_money_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_money_lbl)
	_eco_lbl = PapoUI.label("0 Eco", 32, C_ECO)
	h.add_child(_eco_lbl)
	var h2 := HBoxContainer.new()
	v.add_child(h2)
	_level_lbl = PapoUI.label("Nv 1", 22, Color("ffeaa7"))
	_level_lbl.custom_minimum_size = Vector2(90, 0)
	h2.add_child(_level_lbl)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 18)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.max_value = 1.0
	_xp_bar.add_theme_stylebox_override("fill", PapoUI.flat(Color("fdcb6e"), 10, 0))
	h2.add_child(_xp_bar)
	_income_lbl = PapoUI.label("", 22, Color("a4f0b8"))
	_income_lbl.custom_minimum_size = Vector2(150, 0)
	_income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h2.add_child(_income_lbl)
	var bar_box := Control.new()
	bar_box.custom_minimum_size = Vector2(0, 34)
	v.add_child(bar_box)
	_load_bar = ProgressBar.new()
	_load_bar.show_percentage = false
	_load_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_box.add_child(_load_bar)
	_load_lbl = PapoUI.label("", 22)
	_load_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_box.add_child(_load_lbl)
	var h3 := HBoxContainer.new()
	v.add_child(h3)
	_tier_lbl = PapoUI.label("", 21, Color("dfe6e9"))
	_tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h3.add_child(_tier_lbl)
	_event_lbl = PapoUI.label("", 21, Color("ff9f43"))
	h3.add_child(_event_lbl)
	_boost_lbl = PapoUI.label("", 21, C_GOLD, true)
	_boost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_boost_lbl)

	_sale_btn = PapoUI.button("Ver anuncio: x2 esta venta", func() -> void: AdManager.request("sale_x2"), Vector2(420, 72), Color("2980b9"))
	_sale_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sale_btn.offset_left = -210
	_sale_btn.offset_right = 210
	_sale_btn.offset_top = -300
	_sale_btn.offset_bottom = -228
	_sale_btn.visible = false
	_root.add_child(_sale_btn)


func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_bottom = -14
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(bar)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	bar.add_child(grid)
	for tab in TABS:
		var b := PapoUI.button(tab[1], open_tab.bind(tab[0]), Vector2(0, 70))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 23)
		grid.add_child(b)
		_tab_buttons[tab[0]] = b


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 14
	_panel.offset_right = -14
	_panel.offset_top = 236
	_panel.offset_bottom = -200
	_panel.visible = false
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_panel_title = PapoUI.label("", 34, C_GOLD)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_panel_title)
	head.add_child(PapoUI.button("Cerrar", close_panel, Vector2(140, 64), Color("c0392b")))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_panel_list = VBoxContainer.new()
	_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_panel_list)


func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 260
	_toast_box.offset_left = -330
	_toast_box.offset_right = 330
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)


func show_toast(text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := PapoUI.label(text, 26, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 3:
		var old := _toast_box.get_child(0)
		_toast_box.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _process(delta: float) -> void:
	_money_lbl.text = "$" + GameData.fmt(GameState.money)
	var pi := GameState.passive_income()
	_income_lbl.text = ("+$%s/s" % GameData.fmt(pi)) if pi > 0.0 else ""
	var parts := PackedStringArray()
	for b in [["money", "DINERO x2"], ["production", "PRODUCCIÓN x2"], ["speed", "VELOCIDAD x2"], ["truck", "CAMIÓN ESPECIAL"]]:
		if GameState.boosts.active(b[0]):
			parts.append("%s %s" % [b[1], PapoFormat.time(GameState.boosts.left(b[0]))])
	_boost_lbl.text = "  ·  ".join(parts)
	_sale_btn.visible = GameState.sale_x2_available() and AdManager.can_show() and not _panel.visible
	if _ad_overlay.visible:
		_ad_time -= delta
		_ad_lbl.text = "ANUNCIO DE PRUEBA (simulado)\n\nEn Android aquí aparece un anuncio\nrecompensado de AdMob (IDs de prueba).\n\nRecompensa en %d..." % int(ceil(_ad_time))
		if _ad_time <= 0.0:
			_close_ad(true)
	if _panel.visible:
		_refresh_t += delta
		if _refresh_t > 0.5:
			_refresh_t = 0.0
			_rebuild_panel()


func _on_changed() -> void:
	_eco_lbl.text = "%d Eco" % GameState.eco
	var cap := GameState.capacity()
	_load_bar.max_value = cap
	_load_bar.value = GameState.bag_count
	_load_lbl.text = "Carga %d / %d   ($%s)" % [GameState.bag_count, cap, GameData.fmt(GameState.bag_value() * GameState.sell_multiplier())]
	_tier_lbl.text = GameState.tier_def()["name"]
	_level_lbl.text = "Nv %d" % GameState.levels.level
	_xp_bar.value = GameState.levels.progress()
	_event_lbl.text = ("Evento: %s" % GameState.event["name"]) if not GameState.event.is_empty() else ""
	var pend := GameState.pending_achievements()
	(_tab_buttons["misiones"] as Button).text = "Misiones (%d)" % pend if pend > 0 else "Misiones"
	(_tab_buttons["tienda"] as Button).text = "Tienda (!)" if GameState.daily_available() else "Tienda"


func _on_sold(_amount: float, _at: Vector3) -> void:
	PapoUI.pop(_money_lbl)


# ------------------------------------------------------------- menús

func open_tab(tab: String) -> void:
	if _panel.visible and _tab == tab:
		close_panel()
		return
	_tab = tab
	_reset_armed = false
	_panel.visible = true
	joystick.release()
	joystick.enabled = false
	_scroll.scroll_vertical = 0
	_rebuild_panel()
	PapoUI.slide_in(_panel)


func close_panel() -> void:
	_panel.visible = false
	joystick.enabled = _dialog == null


func _rebuild_panel() -> void:
	var sv := _scroll.scroll_vertical
	for c in _panel_list.get_children():
		_panel_list.remove_child(c)
		c.queue_free()
	match _tab:
		"mejoras": _fill_upgrades()
		"progreso": _fill_tiers()
		"personal": _fill_workers()
		"zonas": _fill_zones()
		"misiones": _fill_missions()
		"tienda": _fill_shop()
		"estilo": _fill_style()
		"ajustes": _fill_settings()
	_scroll.set_deferred("scroll_vertical", sv)


func _row(title: String, desc: String, btn_text: String, enabled: bool, cb: Callable, col: Color = Color.WHITE) -> void:
	PapoUI.row(_panel_list, title, desc, btn_text, enabled, func() -> void:
		cb.call()
		_rebuild_panel(), col)


func _header(text: String, col: Color = C_ECO) -> void:
	_panel_list.add_child(PapoUI.label(text, 28, col))


func _fill_upgrades() -> void:
	_panel_title.text = "Mejoras"
	for u in GameData.UPGRADES:
		var id: String = u["id"]
		var maxed := GameState.upgrade_maxed(id)
		var cost := GameState.upgrade_cost(id)
		_row("%s  (Nv %d/%d)" % [u["name"], GameState.lvl(id), int(u["max"])], u["desc"],
			"MÁX" if maxed else "$" + GameData.fmt(cost), not maxed and GameState.money >= cost,
			GameState.buy_upgrade.bind(id))


func _fill_tiers() -> void:
	_panel_title.text = "Vehículos y empresa"
	var td := GameState.tier_def()
	_row("Actual: %s" % td["name"], "Carga %d · Velocidad %.1f · Venta x%.2f · Pasivo $%s/s" % [
		GameState.capacity(), GameState.move_speed(), GameState.sell_multiplier() / GameState.boost_mult(),
		GameData.fmt(float(td["passive"]))], "", false, Callable(), C_ACCENT.lightened(0.3))
	for i in range(1, GameData.TIERS.size()):
		var t: Dictionary = GameData.TIERS[i]
		var info := "%s · Carga %d · Vel %.1f" % [t["desc"], int(t["cap"]), float(t["speed"])]
		if i <= GameState.tier:
			_row("%d. %s" % [i, t["name"]], info, "Tuyo", false, Callable(), C_OK)
		elif i == GameState.tier + 1:
			_row("%d. %s" % [i, t["name"]], info, "$" + GameData.fmt(float(t["cost"])),
				GameState.money >= float(t["cost"]), GameState.buy_next_tier)
		else:
			_row("%d. %s" % [i, t["name"]], "Bloqueado · $" + GameData.fmt(float(t["cost"])), "", false, Callable(), C_DIM)


func _fill_workers() -> void:
	_panel_title.text = "Personal"
	for d in GameData.WORKERS:
		var id: String = d["id"]
		var n := GameState.count_workers(id)
		var req: int = d["req_tier"]
		if GameState.tier < req:
			_row(d["name"], "%s\nRequiere: %s" % [d["desc"], GameData.TIERS[req]["name"]], "", false, Callable(), C_DIM)
			continue
		var full := n >= GameData.MAX_WORKERS_PER_TYPE
		var cost := GameState.hire_cost(id)
		_row("%s  (%d/%d)" % [d["name"], n, GameData.MAX_WORKERS_PER_TYPE], d["desc"],
			"Lleno" if full else "Contratar\n$" + GameData.fmt(cost),
			not full and GameState.money >= cost, GameState.hire.bind(id), (d["color"] as Color).lightened(0.3))
	if GameState.workers.is_empty():
		return
	_header("Tu plantilla", C_GOLD)
	for i in GameState.workers.size():
		var w: Dictionary = GameState.workers[i]
		var d := GameData.worker_def(w["type"])
		var lv := int(w["level"])
		var perf := ""
		match d["kind"]:
			"collector": perf = "Vel %.1f · Carga %d" % [GameState.worker_speed(w), GameState.worker_capacity(w)]
			"sorter": perf = "+%d%% precio de venta" % (4 * lv)
			"producer": perf = "+$%d/s base" % (3 * lv)
			"booster": perf = "+%d%% velocidad equipo" % (8 * lv)
			"manager": perf = "+%d%% pasivo · offline 100%%" % (10 * lv)
		if w.has("expires"):
			_row("%s temporal" % d["name"], "%s · Quedan %s" % [perf, PapoFormat.time(float(w["expires"]) - Time.get_unix_time_from_system())], "", false, Callable(), C_ECO)
			continue
		var maxed := lv >= GameData.WORKER_MAX_LEVEL
		var cost := GameState.worker_level_cost(i)
		_row("%s #%d  Nv %d" % [d["name"], i + 1, lv], perf, "MÁX" if maxed else "Subir\n$" + GameData.fmt(cost),
			not maxed and GameState.money >= cost, GameState.level_up_worker.bind(i))


func _fill_zones() -> void:
	_panel_title.text = "Mapa de territorios"
	for i in GameData.ZONES.size():
		var z: Dictionary = GameData.ZONES[i]
		var mats := PackedStringArray()
		for m in z["pool"]:
			mats.append(GameData.MATERIALS[int(m)]["name"])
		var desc := "Materiales: " + ", ".join(mats)
		if i < GameState.zones_unlocked:
			_row("%d. %s" % [i + 1, z["name"]], "%s\nLimpieza: %d%%" % [desc, int(float(GameState.zone_clean[i]) * 100.0)],
				"Ir", true, func() -> void:
					world.player.position = world.zone_center(i) + Vector3(0, 0, 3)
					close_panel(), C_OK)
		elif i == GameState.zones_unlocked:
			_row("%d. %s" % [i + 1, z["name"]], desc, "$" + GameData.fmt(float(z["cost"])),
				GameState.money >= float(z["cost"]), GameState.unlock_next_zone)
		else:
			_row("%d. %s" % [i + 1, z["name"]], desc, "", false, Callable(), C_DIM)


func _fill_missions() -> void:
	_panel_title.text = "Misiones"
	var reader := GameState.stat_value
	for period in [["daily", "Diarias (se renuevan cada día)"], ["weekly", "Semanales"]]:
		_header(period[1])
		var l := GameState.missions.list(period[0])
		for i in l.size():
			var m: Dictionary = l[i]
			var prog := GameState.missions.progress(m, reader)
			if m["claimed"]:
				_row(m["text"], "Completada", "", false, Callable(), C_OK)
			else:
				var ready := GameState.missions.is_ready(m, reader)
				_row(m["text"], "%s / %s · Premio: %d Eco" % [GameData.fmt(prog), GameData.fmt(float(m["goal"])), int(m["reward"])],
					"Reclamar" if ready else "%d%%" % int(100.0 * prog / float(m["goal"])), ready,
					GameState.claim_mission.bind(period[0], i), C_GOLD if ready else Color.WHITE)
	_header("Logros")
	for a in GameData.ACHIEVEMENTS:
		var id: String = a["id"]
		var val := GameState.stat_value(a["stat"])
		var goal := float(a["goal"])
		if GameState.claimed.has(id):
			_row(a["name"], a["desc"] + " · Completado", "", false, Callable(), C_OK)
		else:
			var ready := val >= goal
			_row(a["name"], "%s\n%s / %s · Premio: %d Eco" % [a["desc"], GameData.fmt(minf(val, goal)), GameData.fmt(goal), int(a["reward"])],
				"Reclamar" if ready else "%d%%" % int(100.0 * val / goal), ready, GameState.claim_achievement.bind(id),
				C_GOLD if ready else Color.WHITE)


func _fill_shop() -> void:
	_panel_title.text = "Tienda"
	_header("Recompensa diaria (racha %d/7)" % GameState.daily_streak, C_GOLD)
	if GameState.daily_available():
		_row("¡Recompensa disponible!", "Entra cada día para aumentar la racha.", "Reclamar", true, GameState.claim_daily, C_GOLD)
	elif GameState.daily_extra_available():
		_row("Recompensa diaria extra", "Mira un anuncio voluntario para reclamarla otra vez hoy.", "Ver", AdManager.can_show(),
			AdManager.request.bind("daily_extra"))
	else:
		_row("Recompensa reclamada", "Vuelve mañana.", "", false, Callable(), C_OK)
	var left := AdManager.remaining_today()
	var note := "Quedan %d hoy" % left
	if AdManager.cooldown > 0.0:
		note += " · espera %ds" % int(ceil(AdManager.cooldown))
	_header("Anuncios voluntarios (%s)" % note)
	for r in GameData.AD_REWARDS:
		_row(r["name"], r["desc"], "Ver", AdManager.can_show(), AdManager.request.bind(r["kind"]))
	_header("Canjear EcoCoins (tienes %d)" % GameState.eco)
	_row("Dinero x2 (5 min)", "Cuesta %d EcoCoins." % GameData.BOOST_ECO_COST, "%d Eco" % GameData.BOOST_ECO_COST,
		GameState.eco >= GameData.BOOST_ECO_COST, GameState.buy_eco_boost)
	_row("Maletín de dinero", "Recibe $%s al instante." % GameData.fmt(GameState.eco_instant_cash_value()), "10 Eco",
		GameState.eco >= 10, GameState.buy_eco_cash)
	_panel_list.add_child(PapoUI.label("Las monedas del juego no tienen valor real. Nunca es obligatorio ver anuncios.", 20, Color("b2bec3"), true))


func _fill_style() -> void:
	_panel_title.text = "Personalización"
	for slot in [["shirt", "Uniforme"], ["hat", "Gorra"], ["vehicle", "Pintura del vehículo"]]:
		_header(slot[1])
		for c in GameData.COSMETICS:
			if c["slot"] != slot[0]:
				continue
			var owned: bool = GameState.cosmetics_owned.has(c["id"])
			var equipped: bool = GameState.look.get(slot[0], "") == c["id"]
			var btn := "Puesto" if equipped else ("Usar" if owned else "%d Eco" % int(c["cost"]))
			_row(c["name"], "", btn, not equipped and (owned or GameState.eco >= int(c["cost"])),
				GameState.buy_or_equip_cosmetic.bind(c["id"]), c["color"] if (c["color"] as Color).a > 0.0 else Color.WHITE)


func _fill_settings() -> void:
	_panel_title.text = "Configuración"
	var sh: bool = GameState.settings.get("shadows", true)
	_row("Sombras", "Desactívalas si el juego va lento.", "Activadas" if sh else "Desactivadas", true, func() -> void:
		GameState.settings["shadows"] = not sh
		world.set_shadows(not sh))
	var ps := {"personalized": "Personalizados", "non_personalized": "No personalizados", "unknown": "Sin elegir"}
	_row("Privacidad de anuncios", "Actual: %s" % ps.get(AdManager.consent, "?"), "Cambiar", true, func() -> void: _queue(_show_consent))
	_row("Guardar ahora", "Guardado automático cada %ds." % int(GameState.cfg["autosave_seconds"]), "Guardar", true, func() -> void:
		GameState.save_game()
		show_toast("Partida guardada"))
	_row("Estadísticas", "Residuos: %s · Ventas: %s · Ganado: $%s · Anuncios: %d" % [
		GameData.fmt(float(GameState.stats["collected"])), GameData.fmt(float(GameState.stats["sales"])),
		GameData.fmt(float(GameState.stats["earned"])), int(GameState.stats["ads"])], "", false, Callable())
	_row("Borrar progreso", "Pulsa dos veces para confirmar. No se puede deshacer.",
		"¿Seguro?" if _reset_armed else "Borrar", true, _on_reset_pressed, Color("ff7675"))
	_panel_list.add_child(PapoUI.label("PAPO Garbage Tycoon v0.2 · Motor PAPO-GAME-ENGINE", 20, Color("b2bec3")))


func _on_reset_pressed() -> void:
	if _reset_armed:
		GameState.reset_game()
	else:
		_reset_armed = true


# ------------------------------------------------------------- anuncios simulados

func _build_ad_overlay() -> void:
	_ad_overlay = ColorRect.new()
	_ad_overlay.color = Color(0.05, 0.05, 0.08, 0.97)
	_ad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ad_overlay.visible = false
	_root.add_child(_ad_overlay)
	_ad_lbl = PapoUI.label("", 32, Color.WHITE, true)
	_ad_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ad_overlay.add_child(_ad_lbl)
	var close := PapoUI.button("Cerrar sin recompensa", func() -> void: _close_ad(false), Vector2(360, 70), Color("636e72"))
	close.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close.offset_left = -180
	close.offset_right = 180
	close.offset_top = -160
	close.offset_bottom = -90
	_ad_overlay.add_child(close)


func _on_sim_ad(request_id: int, _kind: String) -> void:
	_ad_id = request_id
	_ad_time = 4.0
	_ad_overlay.visible = true
	joystick.release()
	joystick.enabled = false


func _close_ad(completed: bool) -> void:
	_ad_overlay.visible = false
	joystick.enabled = not _panel.visible and _dialog == null
	if completed:
		AdManager.confirm_reward(_ad_id)
	else:
		AdManager.cancel(_ad_id)
		show_toast("Anuncio cerrado: sin recompensa.")


# ------------------------------------------------------------- diálogos (cola)

func _queue(f: Callable) -> void:
	_dialog_queue.append(f)
	if _dialog == null:
		_next_dialog.call_deferred()


func _next_dialog() -> void:
	if _dialog != null or _dialog_queue.is_empty():
		return
	(_dialog_queue.pop_front() as Callable).call()


func _make_dialog(title: String, body: String) -> VBoxContainer:
	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.custom_minimum_size = Vector2(640, 0)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_dialog)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_dialog.add_child(v)
	var t := PapoUI.label(title, 36, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := PapoUI.label(body, 25, Color.WHITE, true)
	b.custom_minimum_size = Vector2(600, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	joystick.release()
	joystick.enabled = false
	return v


func _dialog_button(v: VBoxContainer, text: String, cb: Callable, col: Color = C_ACCENT) -> void:
	v.add_child(PapoUI.button(text, func() -> void:
		_dialog.queue_free()
		_dialog = null
		joystick.enabled = not _panel.visible
		cb.call()
		_next_dialog(), Vector2(0, 80), col))


func close_dialogs() -> void:
	_dialog_queue.clear()
	if _dialog:
		_dialog.queue_free()
		_dialog = null
	joystick.enabled = true


func _show_offline_dialog() -> void:
	var v := _make_dialog("¡Bienvenido de vuelta!",
		"Tu empresa ganó $%s en %s sin conexión." % [GameData.fmt(GameState.pending_offline), PapoFormat.time(GameState.offline_seconds)] +
		("" if GameState.has_manager() else "\n(Contrata un Gerente para cobrar el 100%.)"))
	_dialog_button(v, "Cobrar $%s" % GameData.fmt(GameState.pending_offline), GameState.collect_offline)
	if AdManager.can_show():
		_dialog_button(v, "Ver anuncio y cobrar x2", func() -> void:
			if not AdManager.request("offline"):
				GameState.collect_offline(), Color("2980b9"))


func _show_tutorial() -> void:
	var v := _make_dialog("PAPO Garbage Tycoon",
		"Arrastra el dedo por la pantalla para moverte.\n\nAcércate a la basura para recogerla automáticamente.\n\n" +
		"Llévala al círculo verde VENDER del centro de reciclaje.\n\nCompra mejoras, vehículos, contrata personal y limpia la ciudad.")
	_dialog_button(v, "¡A limpiar!", func() -> void:
		GameState.tutorial_done = true
		GameState.save_game())


func _show_consent() -> void:
	var v := _make_dialog("Privacidad y anuncios",
		"Este juego es gratuito. Puedes ver anuncios OPCIONALES a cambio de recompensas; nunca son obligatorios.\n\n" +
		"Google AdMob puede usar datos del dispositivo para mostrar anuncios. Elige si permites anuncios personalizados. " +
		"Puedes cambiarlo cuando quieras en Ajustes.")
	_dialog_button(v, "Aceptar anuncios personalizados", func() -> void:
		AdManager.set_consent("personalized")
		GameState.save_game())
	_dialog_button(v, "Solo anuncios no personalizados", func() -> void:
		AdManager.set_consent("non_personalized")
		GameState.save_game(), Color("636e72"))


func _show_daily() -> void:
	if not GameState.daily_available():
		_next_dialog()
		return
	var yesterday := PapoConfig.day_key(Time.get_unix_time_from_system() - 86400.0)
	var next_streak := (GameState.daily_streak % 7) + 1 if GameState.daily_last == yesterday else 1
	var r := GameState.daily_reward_for(next_streak)
	var v := _make_dialog("Recompensa diaria · Día %d" % next_streak,
		"+%d EcoCoins y $%s" % [int(r["eco"]), GameData.fmt(float(r["money"]))])
	_dialog_button(v, "Reclamar", GameState.claim_daily)
