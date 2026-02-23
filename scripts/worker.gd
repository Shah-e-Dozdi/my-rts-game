extends CharacterBody3D

signal wood_delivered(amount: int)
signal resin_delivered(amount: int)
signal unit_died(unit: Node3D)

@export var move_speed := 5.5
@export var gather_interval := 1.0
@export var gather_per_tick := 5
@export var carry_capacity := 10
@export var max_hp := 45
@export var attack_damage := 5
@export var attack_range := 1.8
@export var attack_cooldown := 1.0
@export var vision_range := 12.0

var hp: int
var _mesh: MeshInstance3D
var _mat_default: StandardMaterial3D
var _mat_selected: StandardMaterial3D
var _mat_carrying_wood: StandardMaterial3D
var _mat_carrying_resin: StandardMaterial3D
var _nav_agent: NavigationAgent3D

enum State { IDLE, MOVING, GATHERING, RETURNING, ATTACKING }

var _state: State = State.IDLE
var _move_target := Vector3.ZERO
var _gather_timer := 0.0
var _carried := 0
var _carried_type: String = "wood"
var _resource_target: Node3D = null
var _hq: Node3D = null
var _selected := false
var _attack_target: Node3D = null
var _attack_timer := 0.0

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
	capsule.height = 1.0
	col.shape = capsule
	add_child(col)

	# Beaver body - round brown shape
	_mesh = MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.45
	cap_mesh.height = 0.9
	_mesh.mesh = cap_mesh
	add_child(_mesh)

	# Flat beaver tail
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.35, 0.08, 0.5)
	tail.mesh = tail_mesh
	tail.position = Vector3(0, -0.15, 0.45)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.3, 0.2, 0.1)
	tail.material_override = tail_mat
	_mesh.add_child(tail)

	_mat_default = StandardMaterial3D.new()
	_mat_default.albedo_color = Color(0.5, 0.35, 0.18)

	_mat_selected = StandardMaterial3D.new()
	_mat_selected.albedo_color = Color(0.4, 0.9, 1.0)

	_mat_carrying_wood = StandardMaterial3D.new()
	_mat_carrying_wood.albedo_color = Color(0.6, 0.45, 0.2)

	_mat_carrying_resin = StandardMaterial3D.new()
	_mat_carrying_resin.albedo_color = Color(0.85, 0.6, 0.15)

	_mesh.material_override = _mat_default

	add_to_group("units")
	add_to_group("selectable")
	add_to_group("player_units")
	add_to_group("workers")
	_move_target = global_position

func _physics_process(delta: float) -> void:
	_attack_timer -= delta

	match _state:
		State.MOVING:
			_do_move()
		State.GATHERING:
			_do_gather(delta)
			_mesh.position.y = sin(Time.get_ticks_msec() * 0.006) * 0.2
		State.RETURNING:
			_do_return()
		State.ATTACKING:
			_do_attack()
		_:
			velocity = Vector3.ZERO

	if _state != State.GATHERING:
		_mesh.position.y = 0.0

	move_and_slide()

func command_move(target: Vector3) -> void:
	_resource_target = null
	_attack_target = null
	_move_target = target
	_nav_agent.target_position = target
	_state = State.MOVING

func command_gather(resource: Node3D, hq: Node3D) -> void:
	_attack_target = null
	_resource_target = resource
	_hq = hq
	if _resource_target == null or _hq == null:
		return
	_move_target = _resource_approach_position(_resource_target)
	_nav_agent.target_position = _move_target
	_state = State.MOVING

func command_attack(target: Node3D) -> void:
	_resource_target = null
	_attack_target = target
	_state = State.ATTACKING

func set_hq(hq: Node3D) -> void:
	_hq = hq

func set_selected(value: bool) -> void:
	_selected = value
	_update_appearance()

func take_damage(amount: int, _attacker: Node3D = null) -> void:
	hp -= amount
	if hp <= 0:
		unit_died.emit(self)
		queue_free()

func _update_appearance() -> void:
	if _selected:
		_mesh.material_override = _mat_selected
	elif _carried > 0:
		if _carried_type == "resin":
			_mesh.material_override = _mat_carrying_resin
		else:
			_mesh.material_override = _mat_carrying_wood
	else:
		_mesh.material_override = _mat_default


func _resource_approach_position(resource: Node3D) -> Vector3:
	var base := resource.global_position
	var angle := float(get_instance_id() % 360) * PI / 180.0
	var radius := 1.2 + float(get_instance_id() % 5) * 0.15
	return base + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _do_move() -> void:
	var to_target := _move_target - global_position
	to_target.y = 0.0
	var target_dist := to_target.length()

	var arrive_dist := 1.5 if _resource_target != null else 0.5
	if target_dist < arrive_dist:
		velocity = Vector3.ZERO
		if _resource_target != null and _carried < carry_capacity:
			if _resource_target.has_method("get_resource_type"):
				_carried_type = _resource_target.get_resource_type()
			else:
				_carried_type = "wood"
			_state = State.GATHERING
			_gather_timer = 0.0
		elif _carried > 0 and _hq != null:
			_state = State.RETURNING
		else:
			_state = State.IDLE
		return

	if target_dist < 5.0:
		velocity = to_target.normalized() * move_speed
		return

	if _nav_agent.is_navigation_finished():
		velocity = to_target.normalized() * move_speed
		return
	var next_pos := _nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		velocity = dir.normalized() * move_speed

func _do_gather(delta: float) -> void:
	velocity = Vector3.ZERO
	if _resource_target == null:
		_state = State.IDLE
		return
	_gather_timer += delta
	if _gather_timer < gather_interval:
		return
	_gather_timer = 0.0
	if not _resource_target.has_method("harvest"):
		_state = State.IDLE
		return
	var room := carry_capacity - _carried
	if room <= 0:
		_head_to_hq()
		return
	var got: int = _resource_target.harvest(mini(gather_per_tick, room))
	if got <= 0:
		_resource_target = null
		_state = State.IDLE
		_update_appearance()
		return
	_carried += got
	_update_appearance()
	if _carried >= carry_capacity:
		_head_to_hq()

func _head_to_hq() -> void:
	if _hq == null:
		_state = State.IDLE
		return
	_move_target = _hq.global_position
	_nav_agent.target_position = _move_target
	_state = State.RETURNING

func _do_return() -> void:
	if _hq == null or not is_instance_valid(_hq):
		_state = State.IDLE
		return
	var diff := _hq.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()

	if dist < 3.0:
		velocity = Vector3.ZERO
		if _carried > 0:
			if _carried_type == "resin":
				resin_delivered.emit(_carried)
			else:
				wood_delivered.emit(_carried)
			_carried = 0
			_update_appearance()
		if _resource_target != null:
			_move_target = _resource_approach_position(_resource_target)
			_nav_agent.target_position = _move_target
			_state = State.MOVING
		else:
			_state = State.IDLE
		return

	if dist < 5.0:
		velocity = diff.normalized() * move_speed
		return

	if _nav_agent.is_navigation_finished():
		velocity = diff.normalized() * move_speed
		return
	var next_pos := _nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		velocity = dir.normalized() * move_speed

func _do_attack() -> void:
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
			rotation.y = atan2(diff.x, diff.z)
		else:
			_nav_agent.target_position = _attack_target.global_position
			var next_pos := _nav_agent.get_next_path_position()
			var dir := next_pos - global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				velocity = dir.normalized() * move_speed
				rotation.y = atan2(dir.x, dir.z)
	else:
		velocity = Vector3.ZERO
		if diff.length() > 0.01:
			rotation.y = atan2(diff.x, diff.z)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			if _attack_target.has_method("take_damage"):
				_attack_target.take_damage(attack_damage, self)
			var orig_pos := _mesh.position
			var tween := get_tree().create_tween()
			tween.tween_property(_mesh, "position", orig_pos + Vector3(0, 0, -0.2), 0.05)
			tween.tween_property(_mesh, "position", orig_pos, 0.1)
