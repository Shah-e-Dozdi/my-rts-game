extends CharacterBody3D

signal unit_died(unit: Node3D)

@export var move_speed := 4.5
@export var attack_range := 12.0
@export var attack_damage := 8
@export var attack_cooldown := 1.1
@export var max_hp := 45
@export var projectile_speed := 16.0

var hp: int
var _mesh: MeshInstance3D
var _mat_default: StandardMaterial3D
var _nav_agent: NavigationAgent3D

enum State { IDLE, MOVING, ATTACKING }

var _state: State = State.IDLE
var _move_target := Vector3.ZERO
var _attack_target: Node3D = null
var _attack_timer := 0.0
var _scan_timer := 0.0
# Offset angle for spreading around buildings
var _building_angle_offset := 0.0

func _ready() -> void:
	hp = max_hp
	# Each unit gets a random angle offset so they spread around buildings
	_building_angle_offset = randf_range(-PI, PI)

	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = 0.4
	add_child(_nav_agent)

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	col.shape = capsule
	add_child(col)

	# Body
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.4, 0.7, 0.7)
	_mesh.mesh = box_mesh
	add_child(_mesh)

	# Hood flare - wider box on sides at head height
	var hood := MeshInstance3D.new()
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(0.8, 0.4, 0.15)
	hood.mesh = hood_mesh
	hood.position = Vector3(0, 0.15, -0.3)
	var hood_mat := StandardMaterial3D.new()
	hood_mat.albedo_color = Color(0.35, 0.4, 0.18)
	hood.material_override = hood_mat
	_mesh.add_child(hood)

	_mat_default = StandardMaterial3D.new()
	_mat_default.albedo_color = Color(0.3, 0.35, 0.15)
	_mesh.material_override = _mat_default

	add_to_group("enemy_units")
	add_to_group("enemies")
	add_to_group("reptile_units")
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
			if _scan_timer <= 0.0:
				_scan_timer = 0.5
				_auto_acquire_target()
		State.ATTACKING:
			_do_attack(delta)

	move_and_slide()

func command_move(target: Vector3) -> void:
	_attack_target = null
	_move_target = target
	_nav_agent.target_position = target
	_state = State.MOVING

func command_attack(target: Node3D) -> void:
	_attack_target = target
	_state = State.ATTACKING

func take_damage(amount: int, _attacker: Node3D = null) -> void:
	hp -= amount
	if is_instance_valid(_mesh):
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1.0, 1.0, 1.0)
		_mesh.material_override = flash_mat
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if is_instance_valid(_mesh):
				_mesh.material_override = _mat_default
		)
	if hp <= 0:
		unit_died.emit(self)
		queue_free()

func _is_building(node: Node3D) -> bool:
	return node.is_in_group("human_buildings") or node.is_in_group("enemy_buildings")

func _get_effective_range(target: Node3D) -> float:
	# Buildings are large - measure from edge not center
	if _is_building(target):
		return attack_range + 3.0
	return attack_range

func _do_move() -> void:
	var to_target := _move_target - global_position
	to_target.y = 0.0
	var target_dist := to_target.length()

	if target_dist < 0.5:
		velocity = Vector3.ZERO
		_state = State.IDLE
		return

	# Close to target: move directly (nav mesh may carve out target area)
	if target_dist < 5.0:
		velocity = to_target.normalized() * move_speed
		_face_direction(to_target)
		return

	# Far away: use navigation agent
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
	var eff_range := _get_effective_range(_attack_target)

	if dist > eff_range:
		# For buildings, path to a spread-out perimeter point
		var target_pos := _attack_target.global_position
		if _is_building(_attack_target):
			var approach_dir := Vector3(cos(_building_angle_offset), 0, sin(_building_angle_offset))
			target_pos = _attack_target.global_position + approach_dir * 3.5

		if dist < 5.0:
			velocity = diff.normalized() * move_speed
			_face_direction(diff)
		else:
			_nav_agent.target_position = target_pos
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
			_fire_projectile()

func _fire_projectile() -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	# Venom spit projectile - small yellow-green sphere with emission
	var proj := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	proj.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 0.1)
	mat.emission_energy_multiplier = 3.0
	proj.material_override = mat
	proj.global_position = global_position + Vector3(0, 0.5, 0)

	var target_ref := _attack_target
	var damage := attack_damage
	var speed := projectile_speed

	get_tree().current_scene.add_child(proj)

	if target_ref != null and is_instance_valid(target_ref):
		var target_pos: Vector3 = target_ref.global_position + Vector3(0, 0.5, 0)
		var proj_dist: float = proj.global_position.distance_to(target_pos)
		var duration: float = proj_dist / speed

		var tween := get_tree().create_tween()
		tween.tween_property(proj, "global_position", target_pos, duration)
		tween.tween_callback(func() -> void:
			if is_instance_valid(proj):
				proj.queue_free()
			if is_instance_valid(target_ref) and target_ref.has_method("take_damage"):
				target_ref.take_damage(damage, self)
		)

func _auto_acquire_target() -> void:
	var scan_range := 15.0
	var closest_dist := scan_range
	var closest: Node3D = null

	for group_name in ["player_units", "units", "human_buildings"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(target):
				continue
			if target.is_in_group("enemy_units") or target.is_in_group("enemies"):
				continue
			var dist: float = global_position.distance_to(target.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = target
		if closest != null:
			break

	if closest != null:
		_attack_target = closest
		_state = State.ATTACKING

func _face_direction(dir: Vector3) -> void:
	if dir.length() > 0.01:
		var angle := atan2(dir.x, dir.z)
		rotation.y = angle
