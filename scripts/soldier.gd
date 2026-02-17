extends CharacterBody3D

signal unit_died(unit: Node3D)

@export var move_speed := 5.0
@export var attack_range := 12.0
@export var attack_damage := 8
@export var attack_cooldown := 1.2
@export var max_hp := 60
@export var projectile_speed := 20.0

var hp: int
var _mesh: MeshInstance3D
var _mat_default: StandardMaterial3D
var _mat_selected: StandardMaterial3D

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

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.2
	col.shape = capsule
	add_child(col)

	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.7, 1.2, 0.7)
	_mesh.mesh = box_mesh
	_mesh.position.y = 0.0
	add_child(_mesh)

	# Small "gun barrel" to distinguish from workers
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.08
	barrel_mesh.bottom_radius = 0.08
	barrel_mesh.height = 0.6
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90
	barrel.position = Vector3(0, 0.3, -0.5)
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.3, 0.3, 0.3)
	barrel.material_override = barrel_mat
	_mesh.add_child(barrel)

	_mat_default = StandardMaterial3D.new()
	_mat_default.albedo_color = Color(0.2, 0.5, 0.9)

	_mat_selected = StandardMaterial3D.new()
	_mat_selected.albedo_color = Color(0.4, 0.9, 1.0)

	_mesh.material_override = _mat_default

	add_to_group("units")
	add_to_group("selectable")
	add_to_group("player_units")
	add_to_group("combat_units")
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
	_state = State.MOVING

func command_attack_move(target: Vector3) -> void:
	_attack_move_dest = target
	_move_target = target
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
	var diff := _move_target - global_position
	diff.y = 0.0
	if diff.length() < 0.6:
		velocity = Vector3.ZERO
		_state = State.IDLE
		return
	velocity = diff.normalized() * move_speed
	_face_direction(diff)

func _do_move_to(target: Vector3) -> void:
	var diff := target - global_position
	diff.y = 0.0
	if diff.length() < 0.6:
		velocity = Vector3.ZERO
		_state = State.IDLE
		return
	velocity = diff.normalized() * move_speed
	_face_direction(diff)

func _do_attack(_delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		_attack_target = null
		_state = State.IDLE
		return

	var diff := _attack_target.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()

	if dist > attack_range:
		# Move closer
		velocity = diff.normalized() * move_speed
		_face_direction(diff)
	else:
		# In range, stop and fire
		velocity = Vector3.ZERO
		_face_direction(diff)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_fire_projectile()

func _fire_projectile() -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	# Create a simple projectile
	var proj := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	proj.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 2.0
	proj.material_override = mat
	proj.global_position = global_position + Vector3(0, 0.6, 0)

	var target_ref := _attack_target
	var damage := attack_damage
	var speed := projectile_speed

	get_tree().current_scene.add_child(proj)

	# Animate projectile with a tween
	if target_ref != null and is_instance_valid(target_ref):
		var target_pos: Vector3 = target_ref.global_position + Vector3(0, 0.5, 0)
		var dist := proj.global_position.distance_to(target_pos)
		var duration := dist / speed

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
	for enemy in get_tree().get_nodes_in_group("enemy_units"):
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
