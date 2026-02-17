extends Camera3D

@export var move_speed := 22.0
@export var zoom_speed := 45.0
@export var min_height := 12.0
@export var max_height := 60.0
@export var edge_margin := 30

var _zoom_direction := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_direction -= 1.0
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_direction += 1.0

func _process(delta: float) -> void:
	# Edge-of-screen scrolling
	var move_input := Vector2.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var vp_size := get_viewport().get_visible_rect().size

	if mouse_pos.x < edge_margin:
		move_input.x -= 1.0
	elif mouse_pos.x > vp_size.x - edge_margin:
		move_input.x += 1.0
	if mouse_pos.y < edge_margin:
		move_input.y -= 1.0
	elif mouse_pos.y > vp_size.y - edge_margin:
		move_input.y += 1.0

	if move_input.length() > 0.0:
		move_input = move_input.normalized()
		global_position += Vector3(move_input.x, 0.0, move_input.y) * move_speed * delta

	if _zoom_direction != 0.0:
		global_position.y = clampf(global_position.y + _zoom_direction * zoom_speed * delta, min_height, max_height)
		_zoom_direction = move_toward(_zoom_direction, 0.0, 4.0 * delta)
