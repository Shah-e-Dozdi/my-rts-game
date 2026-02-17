extends CharacterBody3D

signal unit_died(unit: Node3D)

@export var move_speed := 8.0
@export var attack_range := 6.0
@export var attack_damage := 4
@export var attack_cooldown := 0.8
@export var max_hp := 30
@export var vision_range := 22.0
@export var projectile_speed := 25.0

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
	_nav_agent.radius = 0.3
	add_child(_nav_agent)

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.8
	col.shape = capsule
	add_child(col)

	# Small, sleek body
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.8, 0.5)
	_mesh.mesh = box_mesh
	_mesh.position.y = 0.0
	add_child(_mesh)

	# Speed fins on sides
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.08, 0.3, 0.4)
		fin.mesh = fin_mesh
		fin.position = Vector3(side * 0.3, 0.1, -0.1)
		var fin_mat := StandardMaterial3D.new()
		fin_mat.albedo_color = Color(0.1, 0.7, 0.3)
		fin.material_override = fin_mat
		_mesh.add_child(fin)

	_mat_default = StandardMaterial3D.new()
	_mat_default.albedo_color = Color(0.15, 0.65, 0.3)

	_mat_selected = StandardMaterial3D.new()
	_mat_selected.albedo_color = Color(0.4, 0.9, 1.0)

	_mesh.material_override = _mat_default

	add_to_group("units")
	add_to_group("selectable")
	add_to_group("player_units")
	add_to_group("combat_units")
	add_to_group("scouts")
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

	if dist > attack_range:
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
			_fire_projectile()

func _fire_projectile() -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	var proj := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	proj.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	proj.material_override = mat
	proj.global_position = global_position + Vector3(0, 0.4, 0)

	var target_ref := _attack_target
	var damage := attack_damage
	var speed := projectile_speed

	get_tree().current_scene.add_child(proj)

	if target_ref != null and is_instance_valid(target_ref):
		var target_pos: Vector3 = target_ref.global_position + Vector3(0, 0.5, 0)
		var proj_dist := proj.global_position.distance_to(target_pos)
		var duration := proj_dist / speed

		var tween := get_tree().create_tween()
		tween.tween_property(proj, "global_position", target_pos, duration)
		tween.tween_callback(func() -> void:
			if is_instance_valid(proj):
				proj.queue_free()
			if is_instance_valid(target_ref) and target_ref.has_method("take_damage"):
				target_ref.take_damage(damage, self)
		)

func _auto_acquire_target() -> void:
	var closest_dist := attack_range * 1.5
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
