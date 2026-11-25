class_name VirtualJoystick
extends Control
## Joystick táctil flotante: aparece donde el dedo toca la pantalla
## (fuera de los botones) y devuelve un vector en `output`.

const RADIUS := 110.0
const KNOB := 48.0

var output: Vector2 = Vector2.ZERO
var enabled: bool = true
var _touch: int = -1
var _origin: Vector2
var _knob: Vector2
var _idle_hint: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _touch == -1:
			_touch = e.index
			_origin = e.position
			_knob = e.position
			_idle_hint = false
			queue_redraw()
		elif not e.pressed and e.index == _touch:
			release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			var off := d.position - _origin
			if off.length() > RADIUS:
				off = off.normalized() * RADIUS
			_knob = _origin + off
			output = off / RADIUS
			queue_redraw()


func release() -> void:
	_touch = -1
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _touch == -1:
		if _idle_hint:
			var c := Vector2(size.x * 0.5, size.y * 0.72)
			draw_circle(c, RADIUS, Color(1, 1, 1, 0.12))
			draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 4.0)
			draw_circle(c, KNOB, Color(1, 1, 1, 0.4))
		return
	draw_circle(_origin, RADIUS, Color(0, 0, 0, 0.18))
	draw_arc(_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 4.0)
	draw_circle(_knob, KNOB, Color(1, 1, 1, 0.75))
