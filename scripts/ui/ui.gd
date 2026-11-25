class_name GameUI
extends CanvasLayer
## Interfaz completa construida por código: HUD, joystick, menús y anuncios.

var world: World
var joystick: VirtualJoystick

var _theme: Theme
var _money_lbl: Label
var _eco_lbl: Label
var _income_lbl: Label
var _load_bar: ProgressBar
var _load_lbl: Label
var _tier_lbl: Label
var _boost_lbl: Label
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
var _dialog: PanelContainer
var _reset_armed: bool = false

const C_BG := Color("1e272e")
const C_PANEL := Color(0.08, 0.12, 0.14, 0.94)
const C_ACCENT := Color("2ecc71")
const C_GOLD := Color("ffd32a")
const C_ECO := Color("48dbfb")

const TABS := [
	["mejoras", "Mejoras"], ["progreso", "Vehículos"], ["personal", "Personal"],
	["zonas", "Zonas"], ["logros", "Logros"], ["tienda", "Tienda"],
]


func _ready() -> void:
	layer = 10
	_theme = _make_theme()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme
	add_child(root)

	joystick = VirtualJoystick.new()
	root.add_child(joystick)

	_build_hud(root)
	_build_bottom_bar(root)
	_build_panel(root)
	_build_toasts(root)
	_build_ad_overlay(root)

	GameState.toast.connect(show_toast)
	GameState.changed.connect(_on_changed)
	AdManager.simulated_ad_requested.connect(_on_sim_ad)
	_on_changed()

	if GameState.pending_offline > 0.0:
		_show_offline_dialog.call_deferred(root)
	elif not GameState.tutorial_done:
		_show_tutorial.call_deferred(root)


# ------------------------------------------------------------- tema

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", sb)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(16)
		b.set_content_margin_all(12)
		match st:
			"normal": b.bg_color = Color("27ae60")
			"hover": b.bg_color = Color("2ecc71")
			"pressed": b.bg_color = Color("1e8449")
			"disabled": b.bg_color = Color("4b5559")
			"focus":
				b.bg_color = Color(0, 0, 0, 0)
				b.draw_center = false
		t.set_stylebox(st, "Button", b)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.55))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_constant("outline_size", "Label", 0)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0, 0, 0, 0.45)
	pb_bg.set_corner_radius_all(10)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = C_ACCENT
	pb_fill.set_corner_radius_all(10)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	var row := StyleBoxFlat.new()
	row.bg_color = Color(1, 1, 1, 0.06)
	row.set_corner_radius_all(16)
	row.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelRow", row)
	t.set_type_variation("PanelRow", "PanelContainer")
	return t


func _label(text: String, size: int = 26, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


# ------------------------------------------------------------- HUD

func _build_hud(root: Control) -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 14
	root.add_child(top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	top.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	_money_lbl = _label("$0", 40, C_GOLD)
	_money_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_money_lbl)
	_eco_lbl = _label("0 Eco", 32, C_ECO)
	h.add_child(_eco_lbl)
	var h2 := HBoxContainer.new()
	v.add_child(h2)
	_tier_lbl = _label("", 22, Color("dfe6e9"))
	_tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(_tier_lbl)
	_income_lbl = _label("", 22, Color("a4f0b8"))
	h2.add_child(_income_lbl)
	var bar_box := Control.new()
	bar_box.custom_minimum_size = Vector2(0, 34)
	v.add_child(bar_box)
	_load_bar = ProgressBar.new()
	_load_bar.show_percentage = false
	_load_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_box.add_child(_load_bar)
	_load_lbl = _label("", 22)
	_load_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_box.add_child(_load_lbl)
	_boost_lbl = _label("", 22, C_GOLD)
	_boost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_boost_lbl)


func _build_bottom_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_bottom = -14
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bar)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	bar.add_child(grid)
	for tab in TABS:
		var b := Button.new()
		b.text = tab[1]
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(open_tab.bind(tab[0]))
		grid.add_child(b)
		_tab_buttons[tab[0]] = b


func _build_panel(root: Control) -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 14
	_panel.offset_right = -14
	_panel.offset_top = 210
	_panel.offset_bottom = -210
	_panel.visible = false
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_panel_title = _label("", 34, C_GOLD)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_panel_title)
	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(140, 64)
	close.add_theme_stylebox_override("normal", _flat(Color("c0392b")))
	close.add_theme_stylebox_override("hover", _flat(Color("e74c3c")))
	close.pressed.connect(close_panel)
	head.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_panel_list = VBoxContainer.new()
	_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_panel_list)


func _flat(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(16)
	b.set_content_margin_all(12)
	return b


func _build_toasts(root: Control) -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 240
	_toast_box.offset_left = -330
	_toast_box.offset_right = 330
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)


func show_toast(text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		_toast_box.remove_child(_toast_box.get_child(0))
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _process(delta: float) -> void:
	_money_lbl.text = "$" + GameData.fmt(GameState.money)
	var pi := GameState.passive_income()
	_income_lbl.text = ("+$%s/s" % GameData.fmt(pi)) if pi > 0.0 else ""
	if GameState.boost_time > 0.0:
		_boost_lbl.text = "DINERO x2  %d:%02d" % [int(GameState.boost_time) / 60, int(GameState.boost_time) % 60]
	else:
		_boost_lbl.text = ""
	if _ad_overlay.visible:
		_ad_time -= delta
		_ad_lbl.text = "ANUNCIO DE PRUEBA (simulado)\n\nEn Android aquí aparece un anuncio\nrecompensado real de AdMob.\n\nRecompensa en %d..." % int(ceil(_ad_time))
		if _ad_time <= 0.0:
			_ad_overlay.visible = false
			joystick.enabled = true
			AdManager.finish_simulated(true)
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
	var pend := GameState.pending_achievements()
	(_tab_buttons["logros"] as Button).text = "Logros (%d)" % pend if pend > 0 else "Logros"


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


func close_panel() -> void:
	_panel.visible = false
	joystick.enabled = true


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
		"logros": _fill_achievements()
		"tienda": _fill_shop()
	_scroll.set_deferred("scroll_vertical", sv)


func _row(title: String, desc: String, btn_text: String, enabled: bool, cb: Callable, title_col: Color = Color.WHITE) -> Button:
	var p := PanelContainer.new()
	p.theme_type_variation = "PanelRow"
	_panel_list.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := _label(title, 28, title_col)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if desc != "":
		var d := _label(desc, 21, Color("b2bec3"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	if btn_text == "":
		return null
	var b := Button.new()
	b.text = btn_text
	b.custom_minimum_size = Vector2(190, 76)
	b.disabled = not enabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		cb.call()
		_rebuild_panel())
	h.add_child(b)
	return b


func _fill_upgrades() -> void:
	_panel_title.text = "Mejoras"
	for u in GameData.UPGRADES:
		var id: String = u["id"]
		var lv := GameState.lvl(id)
		var maxed := GameState.upgrade_maxed(id)
		var cost := GameState.upgrade_cost(id)
		_row("%s  (Nv %d/%d)" % [u["name"], lv, int(u["max"])], u["desc"],
			"MÁX" if maxed else "$" + GameData.fmt(cost),
			not maxed and GameState.money >= cost,
			GameState.buy_upgrade.bind(id))


func _fill_tiers() -> void:
	_panel_title.text = "Vehículos y empresa"
	var td := GameState.tier_def()
	_row("Actual: %s" % td["name"], "Carga %d · Velocidad %.1f · Venta x%.2f · Pasivo $%s/s" % [
		GameState.capacity(), GameState.move_speed(), GameState.sell_multiplier() / GameState.boost_mult(),
		GameData.fmt(float(td["passive"]))], "", false, Callable(), C_ACCENT)
	for i in range(1, GameData.TIERS.size()):
		var t: Dictionary = GameData.TIERS[i]
		var stats := "%s · Carga %d · Vel %.1f" % [t["desc"], int(t["cap"]), float(t["speed"])]
		if i <= GameState.tier:
			_row("%d. %s" % [i, t["name"]], stats, "Tuyo", false, Callable(), Color("7bed9f"))
		elif i == GameState.tier + 1:
			_row("%d. %s" % [i, t["name"]], stats, "$" + GameData.fmt(float(t["cost"])),
				GameState.money >= float(t["cost"]), GameState.buy_next_tier)
		else:
			_row("%d. %s" % [i, t["name"]], "Bloqueado · $" + GameData.fmt(float(t["cost"])), "", false, Callable(), Color("636e72"))


func _fill_workers() -> void:
	_panel_title.text = "Personal"
	for d in GameData.WORKERS:
		var id: String = d["id"]
		var n := GameState.count_workers(id)
		var req: int = d["req_tier"]
		if GameState.tier < req:
			_row(d["name"], "%s\nRequiere: %s" % [d["desc"], GameData.TIERS[req]["name"]], "", false, Callable(), Color("636e72"))
			continue
		var full := n >= GameData.MAX_WORKERS_PER_TYPE
		var cost := GameState.hire_cost(id)
		_row("%s  (%d/%d)" % [d["name"], n, GameData.MAX_WORKERS_PER_TYPE], d["desc"],
			"Lleno" if full else "Contratar\n$" + GameData.fmt(cost),
			not full and GameState.money >= cost, GameState.hire.bind(id), d["color"].lightened(0.3))
	if GameState.workers.is_empty():
		return
	_row("Tu plantilla", "Sube de nivel para mejorar rendimiento y capacidad.", "", false, Callable(), C_GOLD)
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
		var maxed := lv >= GameData.WORKER_MAX_LEVEL
		var cost := GameState.worker_level_cost(i)
		_row("%s #%d  Nv %d" % [d["name"], i + 1, lv], perf,
			"MÁX" if maxed else "Subir\n$" + GameData.fmt(cost),
			not maxed and GameState.money >= cost, GameState.level_up_worker.bind(i))


func _fill_zones() -> void:
	_panel_title.text = "Territorios"
	for i in GameData.ZONES.size():
		var z: Dictionary = GameData.ZONES[i]
		var mats := PackedStringArray()
		for m in z["pool"]:
			mats.append(GameData.MATERIALS[int(m)]["name"])
		var desc := "Materiales: " + ", ".join(mats)
		if i < GameState.zones_unlocked:
			_row("%d. %s" % [i + 1, z["name"]], desc, "Abierta", false, Callable(), Color("7bed9f"))
		elif i == GameState.zones_unlocked:
			_row("%d. %s" % [i + 1, z["name"]], desc, "$" + GameData.fmt(float(z["cost"])),
				GameState.money >= float(z["cost"]), GameState.unlock_next_zone)
		else:
			_row("%d. %s" % [i + 1, z["name"]], desc, "", false, Callable(), Color("636e72"))


func _fill_achievements() -> void:
	_panel_title.text = "Misiones y logros"
	for a in GameData.ACHIEVEMENTS:
		var id: String = a["id"]
		var val := GameState.stat_value(a["stat"])
		var goal := float(a["goal"])
		if GameState.claimed.has(id):
			_row(a["name"], a["desc"] + " · Completado", "", false, Callable(), Color("7bed9f"))
		else:
			var ready := val >= goal
			_row(a["name"], "%s\n%s / %s · Premio: %d Eco" % [a["desc"], GameData.fmt(minf(val, goal)), GameData.fmt(goal), int(a["reward"])],
				"Reclamar" if ready else "%d%%" % int(100.0 * val / goal), ready, GameState.claim_achievement.bind(id),
				C_GOLD if ready else Color.WHITE)


func _fill_shop() -> void:
	_panel_title.text = "Tienda EcoCoins"
	var ad_ok := AdManager.can_show()
	var cd := "" if ad_ok else " (espera %ds)" % int(ceil(GameState.ad_cooldown))
	_row("Anuncios voluntarios", "Opcionales. Nunca obligatorios. Las monedas del juego no tienen valor real.", "", false, Callable(), C_ECO)
	_row("Ver anuncio: +%d EcoCoins" % GameData.AD_ECO_REWARD, "Recompensa por ver un anuncio completo." + cd,
		"Ver", ad_ok, AdManager.show_rewarded.bind("eco"))
	_row("Ver anuncio: Dinero x2", "Duplica ventas e ingreso pasivo 3 minutos." + cd,
		"Ver", ad_ok, AdManager.show_rewarded.bind("boost"))
	_row("Ver anuncio: Dinero rápido", "Recibe $%s al instante.%s" % [GameData.fmt(GameState.eco_instant_cash_value()), cd],
		"Ver", ad_ok, AdManager.show_rewarded.bind("cash"))
	_row("Canjear EcoCoins", "Tienes %d EcoCoins." % GameState.eco, "", false, Callable(), C_ECO)
	_row("Dinero x2 (5 min)", "Cuesta %d EcoCoins." % GameData.BOOST_ECO_COST, "%d Eco" % GameData.BOOST_ECO_COST,
		GameState.eco >= GameData.BOOST_ECO_COST, GameState.buy_eco_boost)
	_row("Maletín de dinero", "Recibe $%s al instante." % GameData.fmt(GameState.eco_instant_cash_value()), "10 Eco",
		GameState.eco >= 10, GameState.buy_eco_cash)
	_row("Ajustes", "Guardado automático cada 10 s.", "", false, Callable(), Color("b2bec3"))
	_row("Guardar ahora", "", "Guardar", true, func() -> void:
		GameState.save_game()
		show_toast("Partida guardada"))
	_row("Borrar progreso", "Pulsa dos veces para confirmar. No se puede deshacer.",
		"¿Seguro?" if _reset_armed else "Borrar", true, _on_reset_pressed, Color("ff7675"))


func _on_reset_pressed() -> void:
	if _reset_armed:
		GameState.reset_game()
	else:
		_reset_armed = true


# ------------------------------------------------------------- anuncios

func _build_ad_overlay(root: Control) -> void:
	_ad_overlay = ColorRect.new()
	_ad_overlay.color = Color(0.05, 0.05, 0.08, 0.96)
	_ad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ad_overlay.visible = false
	root.add_child(_ad_overlay)
	_ad_lbl = _label("", 32)
	_ad_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ad_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ad_overlay.add_child(_ad_lbl)


func _on_sim_ad(_kind: String) -> void:
	_ad_time = 4.0
	_ad_overlay.visible = true
	joystick.release()
	joystick.enabled = false


# ------------------------------------------------------------- diálogos

func _make_dialog(root: Control, title: String, body: String) -> VBoxContainer:
	if _dialog:
		_dialog.queue_free()
	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.custom_minimum_size = Vector2(620, 0)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_dialog)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_dialog.add_child(v)
	var t := _label(title, 36, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _label(body, 26)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(580, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	joystick.enabled = false
	return v


func _dialog_button(v: VBoxContainer, text: String, cb: Callable, col: Color = Color("27ae60")) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_stylebox_override("normal", _flat(col))
	btn.pressed.connect(func() -> void:
		cb.call()
		_dialog.queue_free()
		_dialog = null
		joystick.enabled = true)
	v.add_child(btn)


func _show_offline_dialog(root: Control) -> void:
	var v := _make_dialog(root, "¡Bienvenido de vuelta!",
		"Tu empresa ganó $%s mientras no estabas." % GameData.fmt(GameState.pending_offline) +
		("" if GameState.has_manager() else "\n(Contrata un Gerente para cobrar el 100% offline.)"))
	_dialog_button(v, "Cobrar $%s" % GameData.fmt(GameState.pending_offline), GameState.collect_offline)
	_dialog_button(v, "Ver anuncio y cobrar x2", func() -> void:
		var base := GameState.pending_offline
		GameState.collect_offline()
		GameState.pending_offline = base
		AdManager.show_rewarded("offline"), Color("2980b9"))


func _show_tutorial(root: Control) -> void:
	var v := _make_dialog(root, "PAPO Garbage Tycoon",
		"Arrastra el dedo por la pantalla para moverte.\n\n" +
		"Acércate a la basura para recogerla automáticamente.\n\n" +
		"Llévala al círculo verde VENDER del centro de reciclaje.\n\n" +
		"Compra mejoras, vehículos, contrata personal y conquista la ciudad.")
	_dialog_button(v, "¡A limpiar!", func() -> void:
		GameState.tutorial_done = true
		GameState.save_game())
