extends Node3D

const WorkerScene := preload("res://scenes/Worker.tscn")
const HQScene := preload("res://scenes/HQ.tscn")
const ResourceScene := preload("res://scenes/ResourceNode.tscn")
const CameraScript := preload("res://scripts/camera_controller.gd")
const SelectionBoxScript := preload("res://scripts/selection_box.gd")

var _world: Node3D
var _sel_label: Label
var _help_label: Label
var _camera: Camera3D
var _select_box: Control

var _selected: Array[Node] = []
var _minerals := 50
var _gas := 0
var _supply := 6
var _max_supply := 15
var _hq: Node3D = null

var _drag_start := Vector2.ZERO
var _dragging := false
const DRAG_THRESHOLD := 5.0

func _ready() -> void:
	_build_world()
	_build_camera()
	_build_ui()
	_spawn_base()
	_spawn_minerals()
	_refresh_ui()

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_world.add_child(sun)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	env.environment = environment
	_world.add_child(env)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	_world.add_child(ground)

	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground_mesh.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.4, 0.15)
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)

	var ground_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 0.1, 200)
	ground_col.shape = box
	ground.add_child(ground_col)

func _build_camera() -> void:
	var rig := Node3D.new()
	rig.name = "CameraRig"
	add_child(rig)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 30, 30)
	_camera.rotation_degrees = Vector3(-30, 0, 0)
	_camera.set_script(CameraScript)
	rig.add_child(_camera)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# Top-left info panel
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(300, 0)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_sel_label = Label.new()
	_sel_label.name = "SelectionLabel"
	_sel_label.text = "Selection: 0"
	vbox.add_child(_sel_label)

	_help_label = Label.new()
	_help_label.name = "HelpLabel"
	_help_label.text = "LMB: Select  RMB: Move/Gather"
	vbox.add_child(_help_label)

	# Drag selection rectangle
	_select_box = Control.new()
	_select_box.set_script(SelectionBoxScript)
	_select_box.visible = false
	_select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_select_box)

func _process(_delta: float) -> void:
	if _dragging:
		var mouse_pos := get_viewport().get_mouse_position()
		var rect := Rect2(_drag_start, mouse_pos - _drag_start).abs()
		_select_box.position = rect.position
		_select_box.size = rect.size
		_select_box.queue_redraw()
		if not _select_box.visible and _drag_start.distance_to(mouse_pos) > DRAG_THRESHOLD:
			_select_box.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_dragging = true
			else:
				_dragging = false
				_select_box.visible = false
				if _drag_start.distance_to(event.position) < DRAG_THRESHOLD:
					_on_left_click(event.position)
				else:
					_on_box_select(_drag_start, event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_right_click(event.position)

func _spawn_base() -> void:
	var hq := HQScene.instantiate()
	hq.position = Vector3.ZERO
	_world.add_child(hq)
	_hq = hq
	for i in 6:
		var w := WorkerScene.instantiate()
		var angle := TAU * float(i) / 6.0
		w.position = Vector3(cos(angle) * 4.0, 0.0, sin(angle) * 4.0 + 6.0)
		w.set_hq(_hq)
		w.minerals_delivered.connect(_on_minerals)
		_world.add_child(w)

func _spawn_minerals() -> void:
	var positions := [
		Vector3(-8, 0, -12), Vector3(-5, 0, -15), Vector3(-2, 0, -12),
		Vector3(2, 0, -13), Vector3(6, 0, -15), Vector3(9, 0, -12),
	]
	for pos in positions:
		var r := ResourceScene.instantiate()
		r.position = pos
		_world.add_child(r)

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

func _on_box_select(start: Vector2, end: Vector2) -> void:
	_clear_selection()
	var rect := Rect2(start, end - start).abs()
	for unit in get_tree().get_nodes_in_group("units"):
		var screen_pos := _camera.unproject_position(unit.global_position)
		if rect.has_point(screen_pos):
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
