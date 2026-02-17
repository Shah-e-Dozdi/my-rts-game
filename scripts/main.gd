extends Node3D

const WorkerScene := preload("res://scenes/Worker.tscn")
const HQScene := preload("res://scenes/HQ.tscn")
const ResourceScene := preload("res://scenes/ResourceNode.tscn")

@onready var _sel_label: Label = $UI/Panel/SelectionLabel
@onready var _help_label: Label = $UI/Panel/HelpLabel
@onready var _camera: Camera3D = $CameraRig/Camera3D

var _selected: Array[Node] = []
var _minerals := 50
var _gas := 0
var _supply := 6
var _max_supply := 15
var _hq: Node3D = null

func _ready() -> void:
	_spawn_base()
	_spawn_minerals()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		if event.is_action_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_on_left_click(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click(event.position)

func _spawn_base() -> void:
	var hq := HQScene.instantiate()
	hq.position = Vector3.ZERO
	$World.add_child(hq)
	_hq = hq
	for i in 6:
		var w := WorkerScene.instantiate()
		var angle := TAU * float(i) / 6.0
		w.position = Vector3(cos(angle) * 4.0, 0.0, sin(angle) * 4.0 + 6.0)
		w.set_hq(_hq)
		w.minerals_delivered.connect(_on_minerals)
		$World.add_child(w)

func _spawn_minerals() -> void:
	var positions := [
		Vector3(-8, 0, -12), Vector3(-5, 0, -15), Vector3(-2, 0, -12),
		Vector3(2, 0, -13), Vector3(6, 0, -15), Vector3(9, 0, -12),
	]
	for pos in positions:
		var r := ResourceScene.instantiate()
		r.position = pos
		$World.add_child(r)

func _on_left_click(screen_pos: Vector2) -> void:
	_clear_selection()
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		_refresh_ui()
		return
	var unit := _find_selectable(hit.get("collider"))
	if unit != null:
		_selected.append(unit)
		if unit.has_method("set_selected"):
			unit.set_selected(true)
	_refresh_ui()

func _on_right_click(screen_pos: Vector2) -> void:
	if _selected.is_empty():
		return
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return
	var resource := _find_resource(hit.get("collider"))
	if resource != null:
		for u in _selected:
			if u != null and u.has_method("command_gather"):
				u.command_gather(resource, _hq)
		return
	for u in _selected:
		if u != null and u.has_method("command_move"):
			u.command_move(hit.position)

func _clear_selection() -> void:
	for u in _selected:
		if u != null and u.has_method("set_selected"):
			u.set_selected(false)
	_selected.clear()

func _raycast(screen_pos: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_pos)
	var end := origin + _camera.project_ray_normal(screen_pos) * 500.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _find_selectable(collider: Object) -> Node:
	if collider == null:
		return null
	if collider is Node and collider.is_in_group("selectable"):
		return collider
	if collider is Node and collider.get_parent() != null and collider.get_parent().is_in_group("selectable"):
		return collider.get_parent()
	return null

func _find_resource(collider: Object) -> Node3D:
	if collider == null:
		return null
	if collider is Node and collider.is_in_group("resource_nodes"):
		return collider
	if collider is Node and collider.get_parent() != null and collider.get_parent().is_in_group("resource_nodes"):
		return collider.get_parent()
	return null

func _on_minerals(amount: int) -> void:
	_minerals += amount
	_refresh_ui()

func _refresh_ui() -> void:
	_sel_label.text = "Selection: %d\nMinerals: %d  Gas: %d\nSupply: %d / %d" % [_selected.size(), _minerals, _gas, _supply, _max_supply]
	_help_label.text = "LMB: Select  RMB: Move/Gather\nWASD + Wheel: Camera  Esc: Menu"
