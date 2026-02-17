extends CharacterBody3D

signal unit_died(unit: Node3D)

@export var move_speed := 4.5
@export var attack_range := 2.0
@export var attack_damage := 12
@export var attack_cooldown := 1.0
@export var max_hp := 80

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

func _ready() -> void:
	hp = max_hp

	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = 0.5
	add_child(_nav_agent)

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.2
	col.shape = capsule
	add_child(col)

	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.9, 1.3, 0.9)
	_mesh.mesh = box_mesh
	add_child(_mesh)

	var spike := MeshInstance3D.new()
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.12
	spike_mesh.height = 0.5
	spike.mesh = spike_mesh
	spike.rotation_degrees.x = 90
	spike.position = Vector3(0, 0.2, -0.6)
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.6, 0.6, 0.6)
	spike.material_override = spike_mat
	_mesh.add_child(spike)

	_mat_default = StandardMaterial3D.new()
	_mat_default.albedo_color = Color(0.85, 0.15, 0.15)
	_mesh.material_override = _mat_default

	add_to_group("enemy_units")
	add_to_group("enemies")
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

func _do_move() -> void:
	if _nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		_state = State.IDLE
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

	if dist > attack_range:
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
			_do_melee_hit()

func _do_melee_hit() -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	var orig_pos := _mesh.position
	var tween := get_tree().create_tween()
	tween.tween_property(_mesh, "position", orig_pos + Vector3(0, 0, -0.3), 0.05)
	tween.tween_property(_mesh, "position", orig_pos, 0.1)

	if _attack_target.has_method("take_damage"):
		_attack_target.take_damage(attack_damage, self)

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
			var dist := global_position.distance_to(target.global_position)
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
