extends Control
class_name TouchJoystick

var value: Vector2 = Vector2.ZERO
var active_touch: int = -1
var knob_position: Vector2 = Vector2.ZERO
@export var radius: float = 76.0

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.4, radius * 2.4)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_update_value(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			value = Vector2.ZERO
			knob_position = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_value(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		active_touch = 0 if event.pressed else -1
		if event.pressed:
			_update_value(event.position)
		else:
			value = Vector2.ZERO
			knob_position = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_value(event.position)

func _update_value(point: Vector2) -> void:
	var center := size * 0.5
	var offset := point - center
	knob_position = offset.limit_length(radius)
	value = Vector2(knob_position.x / radius, -knob_position.y / radius)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(0.04, 0.08, 0.12, 0.48))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.55, 0.82, 0.95, 0.85), 3.0)
	draw_circle(center + knob_position, radius * 0.38, Color(0.35, 0.78, 0.95, 0.82))
