extends Node3D

const WorkerScene := preload("res://scenes/Worker.tscn")
const SoldierScene := preload("res://scenes/Soldier.tscn")
const HQScene := preload("res://scenes/HQ.tscn")
const BarracksScene := preload("res://scenes/Barracks.tscn")
const SupplyDepotScene := preload("res://scenes/SupplyDepot.tscn")
const ResourceScene := preload("res://scenes/ResourceNode.tscn")
const EnemyMeleeScene := preload("res://scenes/EnemyMelee.tscn")
const CameraScript := preload("res://scripts/camera_controller.gd")
const SelectionBoxScript := preload("res://scripts/selection_box.gd")
const EnemyAIScript := preload("res://scripts/enemy_ai.gd")
const HealthBarScript := preload("res://scripts/health_bar.gd")

var _world: Node3D
var _nav_region: NavigationRegion3D
var _camera: Camera3D
var _select_box: Control
var _canvas: CanvasLayer

# UI labels
var _info_label: Label
var _command_panel: VBoxContainer
var _production_label: Label
var _minimap_rect: Control

# Selection
var _selected: Array[Node] = []
var _drag_start := Vector2.ZERO
var _dragging := false
const DRAG_THRESHOLD := 5.0
var _last_click_time := 0.0
var _last_click_unit: Node = null
const DOUBLE_CLICK_TIME := 0.35

# Control groups (1-9)
var _control_groups: Array[Array] = []

# Resources
var _minerals := 50
var _gas := 0
var _supply := 6
var _max_supply := 15
var _hq: Node3D = null

# Building placement
enum PlaceMode { NONE, BARRACKS, SUPPLY_DEPOT }
var _place_mode: PlaceMode = PlaceMode.NONE
var _ghost: MeshInstance3D = null
var _ghost_mat_valid: StandardMaterial3D
var _ghost_mat_invalid: StandardMaterial3D

# Enemy AI
var _enemy_ai: Node

# Floating text
var _floating_texts: Array[Dictionary] = []

# Attack-move cursor
var _attack_cursor := false

# Game over
var _game_over := false
var _game_over_panel: PanelContainer = null

func _ready() -> void:
	for i in 10:
		_control_groups.append([])

	_build_world()
	_build_camera()
	_build_ui()
	_spawn_base()
	_spawn_minerals()
	_bake_nav_mesh()
	_setup_enemy_ai()
	_setup_ghost_materials()
	_refresh_ui()

# ─── WORLD ───────────────────────────────────────────────────

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

	# Navigation region wraps all walkable/obstacle geometry
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.6
	nav_mesh.agent_height = 2.0
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_max_climb = 0.3
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_nav_region.navigation_mesh = nav_mesh
	_world.add_child(_nav_region)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	_nav_region.add_child(ground)

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

# ─── NAVIGATION ──────────────────────────────────────────────

func _bake_nav_mesh() -> void:
	_nav_region.bake_navigation_mesh()

# ─── UI ──────────────────────────────────────────────────────

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "UI"
	add_child(_canvas)

	# Top-left info panel
	var panel := PanelContainer.new()
	panel.name = "InfoPanel"
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(320, 0)
	_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	vbox.add_child(_info_label)

	_production_label = Label.new()
	_production_label.name = "ProductionLabel"
	vbox.add_child(_production_label)

	# Bottom command panel
	var cmd_panel := PanelContainer.new()
	cmd_panel.name = "CommandPanel"
	cmd_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cmd_panel.custom_minimum_size = Vector2(0, 100)
	_canvas.add_child(cmd_panel)

	_command_panel = VBoxContainer.new()
	_command_panel.add_theme_constant_override("separation", 2)
	cmd_panel.add_child(_command_panel)

	# Drag selection rectangle
	_select_box = Control.new()
	_select_box.set_script(SelectionBoxScript)
	_select_box.visible = false
	_select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_select_box)

	# Minimap
	_build_minimap()

func _build_minimap() -> void:
	var minimap_size := Vector2(180, 180)
	var minimap_bg := ColorRect.new()
	minimap_bg.name = "MinimapBG"
	minimap_bg.color = Color(0.05, 0.08, 0.05, 0.85)
	minimap_bg.custom_minimum_size = minimap_size
	minimap_bg.size = minimap_size
	minimap_bg.position = Vector2(1600 - minimap_size.x - 10, 10)
	minimap_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(minimap_bg)

	_minimap_rect = Control.new()
	_minimap_rect.name = "Minimap"
	_minimap_rect.custom_minimum_size = minimap_size
	_minimap_rect.size = minimap_size
	_minimap_rect.position = minimap_bg.position
	_minimap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_rect.set_script(load("res://scripts/minimap.gd"))
	_canvas.add_child(_minimap_rect)

# ─── SPAWNING ────────────────────────────────────────────────

func _spawn_base() -> void:
	var hq := HQScene.instantiate()
	hq.position = Vector3.ZERO
	_nav_region.add_child(hq)
	_hq = hq
	_hq.production_finished.connect(_on_production_finished)
	_add_health_bar(_hq, 3.5, 2.0)

	for i in 6:
		var w := WorkerScene.instantiate()
		var angle := TAU * float(i) / 6.0
		w.position = Vector3(cos(angle) * 4.0, 0.0, sin(angle) * 4.0 + 6.0)
		w.set_hq(_hq)
		w.minerals_delivered.connect(_on_minerals)
		_world.add_child(w)
		_add_health_bar(w)

func _spawn_minerals() -> void:
	var positions := [
		Vector3(-8, 0, -12), Vector3(-5, 0, -15), Vector3(-2, 0, -12),
		Vector3(2, 0, -13), Vector3(6, 0, -15), Vector3(9, 0, -12),
	]
	for pos in positions:
		var r := ResourceScene.instantiate()
		r.position = pos
		_nav_region.add_child(r)

func _setup_enemy_ai() -> void:
	_enemy_ai = Node.new()
	_enemy_ai.name = "EnemyAI"
	_enemy_ai.set_script(EnemyAIScript)
	add_child(_enemy_ai)
	_enemy_ai.setup(_world)

	# Add health bar to the enemy HQ
	var enemy_hq: Node3D = _enemy_ai.get_enemy_hq()
	if enemy_hq != null:
		_add_health_bar(enemy_hq, 4.5, 3.0)

func _setup_ghost_materials() -> void:
	_ghost_mat_valid = StandardMaterial3D.new()
	_ghost_mat_valid.albedo_color = Color(0.2, 0.8, 0.3, 0.4)
	_ghost_mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_ghost_mat_invalid = StandardMaterial3D.new()
	_ghost_mat_invalid.albedo_color = Color(0.9, 0.2, 0.2, 0.4)
	_ghost_mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

# ─── MAIN LOOP ───────────────────────────────────────────────

func _process(delta: float) -> void:
	if _game_over:
		return

	if _dragging:
		var mouse_pos := get_viewport().get_mouse_position()
		var rect := Rect2(_drag_start, mouse_pos - _drag_start).abs()
		_select_box.position = rect.position
		_select_box.size = rect.size
		_select_box.queue_redraw()
		if not _select_box.visible and _drag_start.distance_to(mouse_pos) > DRAG_THRESHOLD:
			_select_box.visible = true

	if _place_mode != PlaceMode.NONE and _ghost != null:
		var mouse_pos := get_viewport().get_mouse_position()
		var hit := _raycast(mouse_pos)
		if not hit.is_empty():
			var snap_pos := _snap_to_grid(hit.position)
			snap_pos.y = 0.0
			_ghost.global_position = snap_pos
			match _place_mode:
				PlaceMode.BARRACKS:
					_ghost.global_position.y = 0.9
				PlaceMode.SUPPLY_DEPOT:
					_ghost.global_position.y = 0.6
			_ghost.material_override = _ghost_mat_valid if _can_place(snap_pos) else _ghost_mat_invalid

	_recalc_supply()
	_update_floating_texts(delta)
	_update_warning(delta)
	_update_production_label()
	_clean_dead_refs()
	_refresh_ui()
	_check_game_over()

func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		if event is InputEventKey and event.pressed:
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	if event.is_action_pressed("ui_cancel"):
		if _attack_cursor:
			_attack_cursor = false
			return
		if _place_mode != PlaceMode.NONE:
			_cancel_placement()
			return
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	if event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var idx: int = key - KEY_1
			if event.ctrl_pressed:
				_control_groups[idx] = _selected.duplicate()
				get_viewport().set_input_as_handled()
				return
			elif not event.shift_pressed and not event.alt_pressed and _place_mode == PlaceMode.NONE:
				_recall_control_group(idx)
				get_viewport().set_input_as_handled()
				return

		if key == KEY_A and _place_mode == PlaceMode.NONE and not _selected.is_empty():
			_attack_cursor = true
			return
		if key == KEY_S:
			# Stop command
			for u in _selected:
				if u != null and u.has_method("command_move"):
					u.command_move(u.global_position)
			return
		if key == KEY_B and _place_mode == PlaceMode.NONE:
			_start_placement(PlaceMode.BARRACKS)
			return
		if key == KEY_V and _place_mode == PlaceMode.NONE:
			_start_placement(PlaceMode.SUPPLY_DEPOT)
			return
		if key == KEY_Q:
			_try_train_worker()
			return
		if key == KEY_R:
			_try_train_soldier()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _attack_cursor:
					_on_attack_click(event.position)
					_attack_cursor = false
					return
				if _place_mode != PlaceMode.NONE:
					_try_place_building(event.position)
					return
				_drag_start = event.position
				_dragging = true
			else:
				_dragging = false
				_select_box.visible = false
				if _drag_start.distance_to(event.position) < DRAG_THRESHOLD:
					_on_left_click(event.position, event.shift_pressed)
				else:
					_on_box_select(_drag_start, event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_attack_cursor = false
			if _place_mode != PlaceMode.NONE:
				_cancel_placement()
				return
			_on_right_click(event.position)

# ─── GAME OVER ───────────────────────────────────────────────

func _check_game_over() -> void:
	if _game_over:
		return
	# Victory: enemy HQ destroyed
	var enemy_hq: Node3D = _enemy_ai.get_enemy_hq()
	if enemy_hq == null or not is_instance_valid(enemy_hq):
		_trigger_victory()
		return
	# Defeat: player HQ destroyed
	if _hq == null or not is_instance_valid(_hq):
		_trigger_game_over("Your HQ has been destroyed!")
		return
	# Also check if ALL player buildings are gone
	var buildings := get_tree().get_nodes_in_group("human_buildings")
	var alive := 0
	for b in buildings:
		if is_instance_valid(b):
			alive += 1
	if alive == 0:
		_trigger_game_over("All your buildings have been destroyed!")

func _trigger_game_over(message: String) -> void:
	_game_over = true

	# Darken screen
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	# Game over panel
	_game_over_panel = PanelContainer.new()
	_game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(400, 200)
	_canvas.add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_game_over_panel.add_child(vbox)

	var title := Label.new()
	title.text = "DEFEAT"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", 18)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var hint := Label.new()
	hint.text = "Press any key to return to menu"
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(hint)

func _trigger_victory() -> void:
	_game_over = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	_game_over_panel = PanelContainer.new()
	_game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(400, 200)
	_canvas.add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_game_over_panel.add_child(vbox)

	var title := Label.new()
	title.text = "VICTORY"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "The enemy base has been destroyed!"
	msg.add_theme_font_size_override("font_size", 18)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var hint2 := Label.new()
	hint2.text = "Press any key to return to menu"
	hint2.add_theme_font_size_override("font_size", 14)
	hint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint2.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(hint2)

# ─── SELECTION ───────────────────────────────────────────────

func _on_left_click(screen_pos: Vector2, shift_held: bool) -> void:
	var hit := _raycast(screen_pos)
	var unit := _find_selectable(hit.get("collider")) if not hit.is_empty() else null

	var now := Time.get_ticks_msec() / 1000.0
	if unit != null and unit == _last_click_unit and (now - _last_click_time) < DOUBLE_CLICK_TIME:
		_select_all_of_type(unit)
		_last_click_unit = null
		_refresh_ui()
		return

	_last_click_time = now
	_last_click_unit = unit

	if not shift_held:
		_clear_selection()

	if unit != null:
		if shift_held and unit in _selected:
			_selected.erase(unit)
			if unit.has_method("set_selected"):
				unit.set_selected(false)
		else:
			if unit not in _selected:
				_selected.append(unit)
				if unit.has_method("set_selected"):
					unit.set_selected(true)

	_refresh_ui()

func _on_box_select(start: Vector2, end: Vector2, shift_held: bool) -> void:
	if not shift_held:
		_clear_selection()
	var rect := Rect2(start, end - start).abs()
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.is_in_group("enemy_units"):
			continue
		var screen_pos := _camera.unproject_position(unit.global_position)
		if rect.has_point(screen_pos):
			if unit not in _selected:
				_selected.append(unit)
				if unit.has_method("set_selected"):
					unit.set_selected(true)
	for bld in get_tree().get_nodes_in_group("human_buildings"):
		if not is_instance_valid(bld):
			continue
		if not bld.is_in_group("selectable"):
			continue
		var screen_pos := _camera.unproject_position(bld.global_position)
		if rect.has_point(screen_pos):
			if bld not in _selected:
				_selected.append(bld)
				if bld.has_method("set_selected"):
					bld.set_selected(true)
	_refresh_ui()

func _select_all_of_type(reference: Node) -> void:
	_clear_selection()
	var ref_groups := []
	if reference.is_in_group("workers"):
		ref_groups = ["workers"]
	elif reference.is_in_group("combat_units"):
		ref_groups = ["combat_units"]
	elif reference.is_in_group("barracks"):
		ref_groups = ["barracks"]
	elif reference.is_in_group("supply_depots"):
		ref_groups = ["supply_depots"]
	else:
		_selected.append(reference)
		if reference.has_method("set_selected"):
			reference.set_selected(true)
		return

	for group_name in ref_groups:
		for unit in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(unit):
				continue
			var screen_pos := _camera.unproject_position(unit.global_position)
			if get_viewport().get_visible_rect().has_point(screen_pos):
				_selected.append(unit)
				if unit.has_method("set_selected"):
					unit.set_selected(true)

func _recall_control_group(idx: int) -> void:
	_clear_selection()
	var group: Array = _control_groups[idx]
	for unit in group:
		if unit != null and is_instance_valid(unit):
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

	var enemy := _find_enemy(hit.get("collider"))
	if enemy != null:
		for u in _selected:
			if u != null and u.has_method("command_attack"):
				u.command_attack(enemy)
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

func _on_attack_click(screen_pos: Vector2) -> void:
	if _selected.is_empty():
		return
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return

	# If clicked directly on an enemy, attack that target
	var enemy := _find_enemy(hit.get("collider"))
	if enemy != null:
		for u in _selected:
			if u != null and u.has_method("command_attack"):
				u.command_attack(enemy)
		return

	# Otherwise, attack-move to that ground position
	for u in _selected:
		if u != null and u.has_method("command_attack_move"):
			u.command_attack_move(hit.position)
		elif u != null and u.has_method("command_move"):
			u.command_move(hit.position)

func _clear_selection() -> void:
	for u in _selected:
		if u != null and is_instance_valid(u) and u.has_method("set_selected"):
			u.set_selected(false)
	_selected.clear()

func _clean_dead_refs() -> void:
	var i := _selected.size() - 1
	while i >= 0:
		if _selected[i] == null or not is_instance_valid(_selected[i]):
			_selected.remove_at(i)
		i -= 1
	for g in _control_groups.size():
		var j := _control_groups[g].size() - 1
		while j >= 0:
			if _control_groups[g][j] == null or not is_instance_valid(_control_groups[g][j]):
				_control_groups[g].remove_at(j)
			j -= 1

# ─── BUILDING PLACEMENT ─────────────────────────────────────

func _start_placement(mode: PlaceMode) -> void:
	_cancel_placement()
	_place_mode = mode

	_ghost = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	match mode:
		PlaceMode.BARRACKS:
			mesh.size = Vector3(4, 1.8, 3)
		PlaceMode.SUPPLY_DEPOT:
			mesh.size = Vector3(2.5, 1.2, 2.5)
	_ghost.mesh = mesh
	_ghost.material_override = _ghost_mat_valid
	_world.add_child(_ghost)

func _cancel_placement() -> void:
	_place_mode = PlaceMode.NONE
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null

func _try_place_building(screen_pos: Vector2) -> void:
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return
	var pos := _snap_to_grid(hit.position)
	pos.y = 0.0
	if not _can_place(pos):
		return

	var cost := 0
	match _place_mode:
		PlaceMode.BARRACKS:
			cost = 150
		PlaceMode.SUPPLY_DEPOT:
			cost = 100

	if _minerals < cost:
		_show_warning("Not enough minerals! (need %d)" % cost)
		return

	_minerals -= cost

	match _place_mode:
		PlaceMode.BARRACKS:
			var b := BarracksScene.instantiate()
			b.position = pos
			_nav_region.add_child(b)
			b.production_finished.connect(_on_production_finished)
			_add_health_bar(b, 2.5, 2.0)
		PlaceMode.SUPPLY_DEPOT:
			var s := SupplyDepotScene.instantiate()
			s.position = pos
			_nav_region.add_child(s)
			_add_health_bar(s, 2.0, 1.5)

	_cancel_placement()
	# Rebake nav mesh so units path around new building
	_bake_nav_mesh()
	_refresh_ui()

func _can_place(pos: Vector3) -> bool:
	for bld in get_tree().get_nodes_in_group("human_buildings"):
		if not is_instance_valid(bld):
			continue
		if bld.global_position.distance_to(pos) < 5.0:
			return false
	for res in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(res):
			continue
		if res.global_position.distance_to(pos) < 3.0:
			return false
	return true

func _snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(roundf(pos.x), 0, roundf(pos.z))

# ─── PRODUCTION ──────────────────────────────────────────────

func _try_train_worker() -> void:
	if _hq == null or not is_instance_valid(_hq):
		_show_warning("No HQ!")
		return
	var cost: int = _hq.WORKER_COST
	if _minerals < cost:
		_show_warning("Not enough minerals! (need %d)" % cost)
		return
	if _supply >= _max_supply:
		_show_warning("Supply capped! Build a Supply Depot [V]")
		return
	_minerals -= cost
	_hq.queue_worker(WorkerScene)
	_refresh_ui()

func _try_train_soldier() -> void:
	var barracks_list := get_tree().get_nodes_in_group("barracks")
	if barracks_list.is_empty():
		_show_warning("Build a Barracks first! [B]")
		return
	var barracks: Node3D = barracks_list[0]
	if not barracks.has_method("queue_soldier"):
		return
	var cost: int = barracks.SOLDIER_COST
	var supply_cost: int = barracks.SOLDIER_SUPPLY
	if _minerals < cost:
		_show_warning("Not enough minerals! (need %d)" % cost)
		return
	if _supply + supply_cost > _max_supply:
		_show_warning("Supply capped! Build a Supply Depot [V]")
		return
	_minerals -= cost
	barracks.queue_soldier(SoldierScene)
	_refresh_ui()

func _on_production_finished(unit_scene: PackedScene, spawn_pos: Vector3) -> void:
	var unit := unit_scene.instantiate()
	unit.position = spawn_pos
	_world.add_child(unit)

	if unit.has_method("set_hq"):
		unit.set_hq(_hq)
	if unit.has_signal("minerals_delivered"):
		unit.minerals_delivered.connect(_on_minerals)

	_add_health_bar(unit)

func _on_minerals(amount: int) -> void:
	_minerals += amount
	_spawn_floating_text("+%d" % amount, Color(0.3, 0.8, 1.0))
	_refresh_ui()

# ─── SUPPLY ──────────────────────────────────────────────────

func _recalc_supply() -> void:
	var base_supply := 15
	var depot_supply := 0
	for depot in get_tree().get_nodes_in_group("supply_depots"):
		if is_instance_valid(depot) and "supply_provided" in depot:
			depot_supply += depot.supply_provided
	_max_supply = base_supply + depot_supply

	var used := 0
	for u in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(u):
			if u.is_in_group("workers"):
				used += 1
			elif u.is_in_group("combat_units"):
				used += 2
	_supply = used

# ─── HEALTH BARS ─────────────────────────────────────────────

func _add_health_bar(target: Node3D, offset_y: float = 1.5, bar_width: float = 1.2) -> void:
	var hb := Node3D.new()
	hb.set_script(HealthBarScript)
	_world.add_child(hb)
	hb.setup(target, offset_y, bar_width)

# ─── WARNINGS ────────────────────────────────────────────────

var _warning_label: Label = null
var _warning_timer := 0.0

func _show_warning(text: String) -> void:
	if _warning_label == null:
		_warning_label = Label.new()
		_warning_label.add_theme_font_size_override("font_size", 20)
		_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_warning_label.position = Vector2(500, 400)
		_canvas.add_child(_warning_label)
	_warning_label.text = text
	_warning_label.visible = true
	_warning_timer = 2.0

func _update_warning(delta: float) -> void:
	if _warning_label == null or not _warning_label.visible:
		return
	_warning_timer -= delta
	_warning_label.modulate.a = clampf(_warning_timer / 0.5, 0.0, 1.0)
	if _warning_timer <= 0.0:
		_warning_label.visible = false

# ─── FLOATING TEXT ───────────────────────────────────────────

func _spawn_floating_text(text: String, color: Color) -> void:
	if _hq == null or not is_instance_valid(_hq):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var screen_pos := _camera.unproject_position(_hq.global_position + Vector3(0, 3, 0))
	lbl.position = screen_pos + Vector2(randf_range(-30, 30), 0)
	_canvas.add_child(lbl)
	_floating_texts.append({"label": lbl, "life": 1.5, "start_y": lbl.position.y})

func _update_floating_texts(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in _floating_texts.size():
		var ft: Dictionary = _floating_texts[i]
		ft.life -= delta
		var lbl: Label = ft.label
		if not is_instance_valid(lbl):
			to_remove.append(i)
			continue
		lbl.position.y -= 40.0 * delta
		lbl.modulate.a = clampf(ft.life / 0.5, 0.0, 1.0)
		if ft.life <= 0.0:
			lbl.queue_free()
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		_floating_texts.remove_at(idx)

# ─── RAYCASTING / HELPERS ───────────────────────────────────

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

func _find_enemy(collider: Object) -> Node3D:
	if collider == null:
		return null
	for group_name in ["enemy_units", "enemy_buildings"]:
		if collider is Node and collider.is_in_group(group_name):
			return collider
		if collider is Node and collider.get_parent() != null and collider.get_parent().is_in_group(group_name):
			return collider.get_parent()
	return null

# ─── UI REFRESH ──────────────────────────────────────────────

func _refresh_ui() -> void:
	var sel_text := ""
	if _selected.size() > 0:
		var first := _selected[0]
		if not is_instance_valid(first):
			sel_text = "No selection"
		else:
			if first.is_in_group("workers"):
				sel_text = "Workers: %d" % _selected.size()
			elif first.is_in_group("combat_units"):
				sel_text = "Soldiers: %d" % _selected.size()
			elif first.is_in_group("barracks"):
				sel_text = "Barracks"
			elif first.is_in_group("supply_depots"):
				sel_text = "Supply Depot"
			elif first == _hq:
				sel_text = "HQ"
			elif first.is_in_group("enemy_buildings"):
				sel_text = "Enemy HQ"
			else:
				sel_text = "Selected: %d" % _selected.size()

			if _selected.size() == 1 and "hp" in first and "max_hp" in first:
				sel_text += "  HP: %d/%d" % [first.hp, first.max_hp]
	else:
		sel_text = "No selection"

	_info_label.text = "Minerals: %d  Gas: %d\nSupply: %d / %d\n%s" % [_minerals, _gas, _supply, _max_supply, sel_text]
	_update_command_panel()

func _update_command_panel() -> void:
	for child in _command_panel.get_children():
		child.queue_free()

	var help_text := "Mouse Edge: Camera  Scroll: Zoom  Esc: Menu\n"
	help_text += "LMB: Select  RMB: Move/Gather/Attack\n"
	help_text += "[A]+LMB: Attack-Move  [S]: Stop\n"
	help_text += "Shift+Click: Add/Remove  DblClick: Select all of type\n"
	help_text += "Ctrl+1-9: Set group  1-9: Recall group\n"

	if _attack_cursor:
		help_text += "\n[ATTACK CURSOR] LMB: Attack target/ground  RMB/Esc: Cancel"
	elif _place_mode != PlaceMode.NONE:
		help_text += "\n[PLACING] LMB: Confirm  RMB/Esc: Cancel"
	else:
		help_text += "\n[B] Build Barracks (150)  [V] Supply Depot (100)"
		help_text += "\n[Q] Train Worker (50)  [R] Train Soldier (75, needs Barracks)"
		help_text += "\nObjective: Destroy the enemy base!"

	var lbl := Label.new()
	lbl.text = help_text
	lbl.add_theme_font_size_override("font_size", 13)
	_command_panel.add_child(lbl)

func _update_production_label() -> void:
	var text := ""
	if _hq != null and is_instance_valid(_hq) and _hq.get_queue_size() > 0:
		var progress: float = _hq.get_build_progress()
		text += "HQ: Training worker [%d%%] (queue: %d)\n" % [int(progress * 100), _hq.get_queue_size()]

	for barracks in get_tree().get_nodes_in_group("barracks"):
		if is_instance_valid(barracks) and barracks.get_queue_size() > 0:
			var progress: float = barracks.get_build_progress()
			text += "Barracks: Training soldier [%d%%] (queue: %d)\n" % [int(progress * 100), barracks.get_queue_size()]

	_production_label.text = text
