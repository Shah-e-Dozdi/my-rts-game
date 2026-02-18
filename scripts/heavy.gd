extends CharacterBody3D

signal unit_died(unit: Node3D)

@export var move_speed := 3.0
@export var attack_range := 2.0
@export var attack_damage := 15
@export var attack_cooldown := 1.5
@export var max_hp := 200
@export var vision_range := 10.0
@export var splash_radius := 3.0

var hp: int
var _mesh: MeshInstance3D
var _mat_default: StandardMaterial3D
var _mat_selected: StandardMaterial3D
var _nav_agent: NavigationAgent3D

enum State { IDLE, MOVING, ATTACKING, ATTACK_MOVE }

var _state: State = State.IDLE
var _move_target := Vector3.ZERO
var _attack_target: Node3D = null
var _attack_timer := 0.0
var _selected := false
var _scan_timer := 0.0
var _attack_move_dest := Vector3.ZERO

func _ready() -> void:
	hp = max_hp

	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = 0.6
	add_child(_nav_agent)

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 1.4
	col.shape = capsule
	add_child(col)

	# Big, boxy body
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.2, 1.4, 1.0)
	_mesh.mesh = box_mesh
	_mesh.position.y = 0.0
	add_child(_mesh)

	# Shoulder armor plates
	for side in [-1.0, 1.0]:
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.3, 0.5, 0.8)
		plate.mesh = plate_mesh
		plate.position = Vector3(side * 0.7, 0.3, 0.0)
		var plate_mat := StandardMaterial3D.new()
		plate_mat.albedo_color = Color(0.4, 0.35, 0.15)
		plate.material_override = plate_mat
		_mesh.add_child(plate)

	# Fist weapon
	var fist := MeshInstance3D.new()
	var fist_mesh := BoxMesh.new()
	fist_mesh.size = Vector3(0.4, 0.4, 0.4)
	fist.mesh = fist_mesh
	fist.position = Vector3(0, -0.2, -0.6)
	var fist_mat := StandardMaterial3D.new()
	fist_mat.albedo_color = Color(0.5, 0.5, 0.55)
	fist.material_override = fist_mat
	_mesh.add_child(fist)

	_mat_default = StandardMaterial3D.new()
	_mat_default.albedo_color = Color(0.55, 0.5, 0.2)

	_mat_selected = StandardMaterial3D.new()
	_mat_selected.albedo_color = Color(0.4, 0.9, 1.0)

	_mesh.material_override = _mat_default

	add_to_group("units")
	add_to_group("selectable")
	add_to_group("player_units")
	add_to_group("combat_units")
	add_to_group("heavies")
	_move_target = global_position

func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_scan_timer -= delta

	match _state:
		State.IDLE:
			velocity = Vector3.ZERO
			if _scan_timer <= 0.0:
				_scan_timer = 0.5
				_auto_acquire_target()
		State.MOVING:
			_do_move()
		State.ATTACK_MOVE:
			if _scan_timer <= 0.0:
				_scan_timer = 0.3
				_auto_acquire_target()
			if _attack_target != null and is_instance_valid(_attack_target):
				_do_attack(delta)
			else:
				_do_move_to(_attack_move_dest)
		State.ATTACKING:
			_do_attack(delta)

	move_and_slide()

func command_move(target: Vector3) -> void:
	_attack_target = null
	_move_target = target
	_nav_agent.target_position = target
	_state = State.MOVING

func command_attack_move(target: Vector3) -> void:
	_attack_move_dest = target
	_move_target = target
	_nav_agent.target_position = target
	_attack_target = null
	_state = State.ATTACK_MOVE

func command_attack(target: Node3D) -> void:
	_attack_target = target
	_state = State.ATTACKING

func set_selected(value: bool) -> void:
	_selected = value
	_mesh.material_override = _mat_selected if _selected else _mat_default

func take_damage(amount: int, _attacker: Node3D = null) -> void:
	hp -= amount
	if hp <= 0:
		unit_died.emit(self)
		queue_free()

func _do_move() -> void:
	var to_target := _move_target - global_position
	to_target.y = 0.0
	var target_dist := to_target.length()

	if target_dist < 0.5:
		velocity = Vector3.ZERO
		_state = State.IDLE
		return

	if target_dist < 5.0:
		velocity = to_target.normalized() * move_speed
		_face_direction(to_target)
		return

	if _nav_agent.is_navigation_finished():
		velocity = to_target.normalized() * move_speed
		_face_direction(to_target)
		return
	var next_pos := _nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		velocity = dir.normalized() * move_speed
		_face_direction(dir)

func _do_move_to(target: Vector3) -> void:
	_nav_agent.target_position = target
	var to_target := target - global_position
	to_target.y = 0.0
	var target_dist := to_target.length()

	if target_dist < 0.5:
		velocity = Vector3.ZERO
		_state = State.IDLE
		return

	if target_dist < 5.0:
		velocity = to_target.normalized() * move_speed
		_face_direction(to_target)
		return

	if _nav_agent.is_navigation_finished():
		velocity = to_target.normalized() * move_speed
		_face_direction(to_target)
		return
	var next_pos := _nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		velocity = dir.normalized() * move_speed
		_face_direction(dir)

func _do_attack(_delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		_attack_target = null
		_state = State.IDLE
		return

	var diff := _attack_target.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()

	# Buildings are large - use extra range
	var eff_range := attack_range
	if _attack_target.is_in_group("enemy_buildings"):
		eff_range += 3.0

	if dist > eff_range:
		if dist < 5.0:
			velocity = diff.normalized() * move_speed
			_face_direction(diff)
		else:
			_nav_agent.target_position = _attack_target.global_position
			var next_pos := _nav_agent.get_next_path_position()
			var dir := next_pos - global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				velocity = dir.normalized() * move_speed
				_face_direction(dir)
	else:
		velocity = Vector3.ZERO
		_face_direction(diff)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_do_melee_slam()

func _do_melee_slam() -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	# Punch animation
	var orig_pos := _mesh.position
	var tween := get_tree().create_tween()
	tween.tween_property(_mesh, "position", orig_pos + Vector3(0, 0, -0.4), 0.08)
	tween.tween_property(_mesh, "position", orig_pos, 0.15)

	# Hit primary target
	var hit_pos := _attack_target.global_position
	if _attack_target.has_method("take_damage"):
		_attack_target.take_damage(attack_damage, self)

	# Splash damage to nearby enemies
	for enemy in get_tree().get_nodes_in_group("enemy_units"):
		if not is_instance_valid(enemy):
			continue
		if enemy == _attack_target:
			continue
		var splash_dist: float = enemy.global_position.distance_to(hit_pos)
		if splash_dist <= splash_radius:
			if enemy.has_method("take_damage"):
				var splash_dmg := int(attack_damage * 0.5)
				enemy.take_damage(splash_dmg, self)

	# Ground slam visual
	_spawn_slam_effect(hit_pos)

func _spawn_slam_effect(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = splash_radius
	torus.bottom_radius = splash_radius
	torus.height = 0.05
	ring.mesh = torus
	ring.global_position = pos + Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.2, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	get_tree().current_scene.add_child(ring)

	var tween := get_tree().create_tween()
	tween.tween_property(ring, "scale", Vector3(1.3, 1.0, 1.3), 0.3)
	tween.parallel().tween_property(mat, "albedo_color", Color(1.0, 0.7, 0.2, 0.0), 0.3)
	tween.tween_callback(ring.queue_free)

func _auto_acquire_target() -> void:
	var closest_dist := 8.0
	var closest: Node3D = null
	for group_name in ["enemy_units", "enemy_buildings"]:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(enemy):
				continue
			var dist := global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy
	if closest != null:
		_attack_target = closest
		if _state == State.IDLE:
			_state = State.ATTACKING

func _face_direction(dir: Vector3) -> void:
	if dir.length() > 0.01:
		var angle := atan2(dir.x, dir.z)
		rotation.y = angle
