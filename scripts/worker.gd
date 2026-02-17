extends CharacterBody3D

signal minerals_delivered(amount: int)

@export var move_speed: float = 6.0
@export var gather_interval_seconds: float = 1.0
@export var gather_amount_per_tick: int = 5
@export var carry_capacity: int = 10

var move_target: Vector3
var has_move_target := false
var _selected := false
var _gather_timer := 0.0
var _carried_minerals := 0
var _assigned_resource: Node3D
var _home_hq: Node3D

@onready var _mesh: MeshInstance3D = $Mesh

enum WorkerState {
	IDLE,
	MOVING,
	GATHERING,
	RETURNING
}

var _state: WorkerState = WorkerState.IDLE

func _ready() -> void:
	add_to_group("units")
	add_to_group("selectable")
	move_target = global_position

func _physics_process(delta: float) -> void:
	match _state:
		WorkerState.MOVING:
			_move_towards_target()
		WorkerState.GATHERING:
			_process_gathering(delta)
		WorkerState.RETURNING:
			_process_returning()
		_:
			velocity = Vector3.ZERO

	move_and_slide()

func set_move_target(target: Vector3) -> void:
	_assigned_resource = null
	_state = WorkerState.MOVING
	move_target = target
	has_move_target = true

func set_gather_target(resource_node: Node3D, hq_node: Node3D) -> void:
	_assigned_resource = resource_node
	_home_hq = hq_node
	if _assigned_resource == null or _home_hq == null:
		return
	move_target = _assigned_resource.global_position
	has_move_target = true
	_state = WorkerState.MOVING

func set_home_hq(hq_node: Node3D) -> void:
	_home_hq = hq_node

func set_selected(value: bool) -> void:
	_selected = value
	var mat := StandardMaterial3D.new()
	if _selected:
		mat.albedo_color = Color(0.5, 0.9, 1.0)
	else:
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	_mesh.material_override = mat

func _move_towards_target() -> void:
	var to_target := move_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.55:
		velocity = Vector3.ZERO
		has_move_target = false
		if _assigned_resource != null and _carried_minerals < carry_capacity:
			_state = WorkerState.GATHERING
			_gather_timer = 0.0
		elif _carried_minerals > 0 and _home_hq != null:
			_state = WorkerState.RETURNING
		else:
			_state = WorkerState.IDLE
		return

	velocity = to_target.normalized() * move_speed

func _process_gathering(delta: float) -> void:
	velocity = Vector3.ZERO
	if _assigned_resource == null:
		_state = WorkerState.IDLE
		return

	_gather_timer += delta
	if _gather_timer < gather_interval_seconds:
		return

	_gather_timer = 0.0
	if not _assigned_resource.has_method("harvest"):
		_state = WorkerState.IDLE
		return

	var room_left := carry_capacity - _carried_minerals
	if room_left <= 0:
		_begin_return_to_hq()
		return

	var harvested := _assigned_resource.harvest(mini(gather_amount_per_tick, room_left))
	if harvested <= 0:
		_state = WorkerState.IDLE
		_assigned_resource = null
		return

	_carried_minerals += harvested
	if _carried_minerals >= carry_capacity:
		_begin_return_to_hq()

func _begin_return_to_hq() -> void:
	if _home_hq == null:
		_state = WorkerState.IDLE
		return
	move_target = _home_hq.global_position
	has_move_target = true
	_state = WorkerState.RETURNING

func _process_returning() -> void:
	if _home_hq == null:
		_state = WorkerState.IDLE
		return

	var to_hq := _home_hq.global_position - global_position
	to_hq.y = 0.0
	if to_hq.length() < 1.8:
		velocity = Vector3.ZERO
		if _carried_minerals > 0:
			minerals_delivered.emit(_carried_minerals)
			_carried_minerals = 0
		if _assigned_resource != null:
			move_target = _assigned_resource.global_position
			has_move_target = true
			_state = WorkerState.MOVING
		else:
			_state = WorkerState.IDLE
		return

	velocity = to_hq.normalized() * move_speed
