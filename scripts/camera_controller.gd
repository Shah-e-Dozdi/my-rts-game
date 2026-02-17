extends Camera3D

@export var move_speed := 22.0
@export var zoom_speed := 45.0
@export var min_height := 12.0
@export var max_height := 60.0

var _zoom_direction := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_direction -= 1.0
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_direction += 1.0

func _process(delta: float) -> void:
	var move_input := Vector2.ZERO
	move_input.x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	move_input.y = Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")

	if move_input.length() > 0.0:
		move_input = move_input.normalized()
		global_position += Vector3(move_input.x, 0.0, move_input.y) * move_speed * delta

	if _zoom_direction != 0.0:
		global_position.y = clampf(global_position.y + _zoom_direction * zoom_speed * delta, min_height, max_height)
		_zoom_direction = move_toward(_zoom_direction, 0.0, 4.0 * delta)
