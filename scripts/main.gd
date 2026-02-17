extends Node3D

const WORKER_SCENE := preload("res://scenes/Worker.tscn")
const HQ_SCENE := preload("res://scenes/HQ.tscn")
const RESOURCE_SCENE := preload("res://scenes/ResourceNode.tscn")

@onready var selection_label: Label = $UI/Panel/SelectionLabel
@onready var help_label: Label = $UI/Panel/HelpLabel
@onready var camera: Camera3D = $CameraRig/Camera3D

var selected_units: Array[Node] = []
var player_minerals := 50
var player_gas := 0
var current_supply := 6
var max_supply := 15
var player_hq: Node3D

func _ready() -> void:
	_spawn_starting_base()
	_spawn_resources()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.position)
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _spawn_starting_base() -> void:
	var hq := HQ_SCENE.instantiate()
	hq.position = Vector3(0.0, 0.0, 0.0)
	$World.add_child(hq)
	player_hq = hq

	for i in 6:
		var worker := WORKER_SCENE.instantiate()
		var angle := TAU * float(i) / 6.0
		worker.position = Vector3(cos(angle), 0.0, sin(angle)) * 4.0 + Vector3(0.0, 0.0, 6.0)
		worker.set_home_hq(player_hq)
		worker.minerals_delivered.connect(_on_worker_minerals_delivered)
		$World.add_child(worker)

func _spawn_resources() -> void:
	var node_positions := [
		Vector3(-8.0, 0.0, -12.0),
		Vector3(-5.0, 0.0, -15.0),
		Vector3(-2.0, 0.0, -12.0),
		Vector3(2.0, 0.0, -13.0),
		Vector3(6.0, 0.0, -15.0),
		Vector3(9.0, 0.0, -12.0)
	]

	for node_position in node_positions:
		var resource_node := RESOURCE_SCENE.instantiate()
		resource_node.position = node_position
		$World.add_child(resource_node)

func _handle_left_click(screen_position: Vector2) -> void:
	var result := _raycast_from_screen(screen_position)
	_clear_selection()

	if result.is_empty():
		_update_ui()
		return

	var selectable := _find_selectable_from_collider(result.get("collider"))
	if selectable != null and selectable.is_in_group("selectable"):
		selected_units.append(selectable)
		if selectable.has_method("set_selected"):
			selectable.set_selected(true)

	_update_ui()

func _handle_right_click(screen_position: Vector2) -> void:
	if selected_units.is_empty():
		return

	var result := _raycast_from_screen(screen_position)
	if result.is_empty():
		return

	var resource_target := _find_resource_from_collider(result.get("collider"))
	if resource_target != null:
		for unit in selected_units:
			if unit != null and unit.has_method("set_gather_target"):
				unit.set_gather_target(resource_target, player_hq)
		return

	var target: Vector3 = result.position
	for unit in selected_units:
		if unit != null and unit.has_method("set_move_target"):
			unit.set_move_target(target)

func _clear_selection() -> void:
	for unit in selected_units:
		if unit != null and unit.has_method("set_selected"):
			unit.set_selected(false)
	selected_units.clear()

func _raycast_from_screen(screen_position: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 500.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _find_selectable_from_collider(collider: Object) -> Node:
	if collider == null:
		return null
	if collider is Node and collider.is_in_group("selectable"):
		return collider
	if collider is Node and collider.get_parent() != null and collider.get_parent().is_in_group("selectable"):
		return collider.get_parent()
	return null

func _find_resource_from_collider(collider: Object) -> Node3D:
	if collider == null:
		return null
	if collider is Node and collider.is_in_group("resource_nodes"):
		return collider
	if collider is Node and collider.get_parent() != null and collider.get_parent().is_in_group("resource_nodes"):
		return collider.get_parent()
	return null

func _on_worker_minerals_delivered(amount: int) -> void:
	player_minerals += amount
	_update_ui()

func _update_ui() -> void:
	var selection_text := "Selection: %d" % selected_units.size()
	selection_label.text = "%s\nMinerals: %d  Gas: %d\nSupply: %d / %d" % [selection_text, player_minerals, player_gas, current_supply, max_supply]
	help_label.text = "LMB: Select  RMB: Move/Gather\nWASD + Wheel: Camera  Esc: Menu"
