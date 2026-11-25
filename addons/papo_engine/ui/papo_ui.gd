class_name PapoUI
extends RefCounted
## Utilidades de interfaz táctil: tema, etiquetas, filas, botones y animaciones.

static func flat(c: Color, radius: int = 16, margin: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b


static func make_theme(accent: Color, panel: Color, font_size: int = 26) -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size
	t.set_stylebox("panel", "PanelContainer", flat(panel, 22, 18))
	t.set_stylebox("normal", "Button", flat(accent))
	t.set_stylebox("hover", "Button", flat(accent.lightened(0.12)))
	t.set_stylebox("pressed", "Button", flat(accent.darkened(0.2)))
	t.set_stylebox("disabled", "Button", flat(Color("4b5559")))
	var focus := flat(Color(0, 0, 0, 0))
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.55))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_stylebox("background", "ProgressBar", flat(Color(0, 0, 0, 0.45), 10, 0))
	t.set_stylebox("fill", "ProgressBar", flat(accent, 10, 0))
	t.set_type_variation("PanelRow", "PanelContainer")
	t.set_stylebox("panel", "PanelRow", flat(Color(1, 1, 1, 0.06), 16, 14))
	return t


static func label(text: String, size: int = 26, col: Color = Color.WHITE, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_size: Vector2 = Vector2(190, 76), col: Color = Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if col.a > 0.0:
		b.add_theme_stylebox_override("normal", flat(col))
		b.add_theme_stylebox_override("hover", flat(col.lightened(0.12)))
	b.pressed.connect(func() -> void:
		pop(b)
		cb.call())
	return b


## Fila: título + descripción + botón opcional.
static func row(parent: Control, title: String, desc: String, btn_text: String, enabled: bool, cb: Callable, title_col: Color = Color.WHITE) -> Button:
	var p := PanelContainer.new()
	p.theme_type_variation = "PanelRow"
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(label(title, 28, title_col, true))
	if desc != "":
		v.add_child(label(desc, 21, Color("b2bec3"), true))
	if btn_text == "":
		return null
	var b := button(btn_text, cb)
	b.disabled = not enabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b


static func pop(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.92, 0.92), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func slide_in(c: Control) -> void:
	c.modulate.a = 0.0
	var y := c.position.y
	c.position.y = y + 40
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, 0.18)
	tw.tween_property(c, "position:y", y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func float_text_3d(parent: Node3D, text: String, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 80
	l.outline_size = 16
	l.pixel_size = 0.012
	l.modulate = col
	l.position = at
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", at + Vector3(0, 2.5, 0), 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1)
	tw.tween_callback(l.queue_free)
