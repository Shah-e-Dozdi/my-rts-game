extends Control

const MAP_RANGE := 100.0  # World units from center shown on minimap

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var map_size := size
	if map_size.x <= 0 or map_size.y <= 0:
		return

	# Draw player buildings (white squares)
	for bld in get_tree().get_nodes_in_group("human_buildings"):
		if not is_instance_valid(bld):
			continue
		var pt := _world_to_minimap(bld.global_position, map_size)
		draw_rect(Rect2(pt - Vector2(3, 3), Vector2(6, 6)), Color(0.8, 0.8, 1.0))

	# Draw resource nodes (cyan dots)
	for res in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(res):
			continue
		var pt := _world_to_minimap(res.global_position, map_size)
		draw_circle(pt, 2.5, Color(0.3, 0.7, 1.0))

	# Draw player units (green dots)
	for unit in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(unit):
			continue
		var pt := _world_to_minimap(unit.global_position, map_size)
		var c := Color(0.2, 0.9, 0.3) if unit.is_in_group("workers") else Color(0.3, 0.5, 1.0)
		draw_circle(pt, 2.0, c)

	# Draw enemy units (red dots)
	for enemy in get_tree().get_nodes_in_group("enemy_units"):
		if not is_instance_valid(enemy):
			continue
		var pt := _world_to_minimap(enemy.global_position, map_size)
		draw_circle(pt, 2.0, Color(0.9, 0.2, 0.2))

	# Draw camera viewport indicator
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var cam_pt := _world_to_minimap(cam.global_position, map_size)
		draw_rect(Rect2(cam_pt - Vector2(12, 8), Vector2(24, 16)), Color(1, 1, 1, 0.4), false, 1.0)

func _world_to_minimap(world_pos: Vector3, map_size: Vector2) -> Vector2:
	var nx := (world_pos.x + MAP_RANGE) / (MAP_RANGE * 2.0)
	var ny := (world_pos.z + MAP_RANGE) / (MAP_RANGE * 2.0)
	nx = clampf(nx, 0.0, 1.0)
	ny = clampf(ny, 0.0, 1.0)
	return Vector2(nx * map_size.x, ny * map_size.y)
