extends CharacterBody3D

signal minerals_delivered(amount: int)

@export var move_speed := 6.0
@export var gather_interval := 1.0
@export var gather_per_tick := 5
@export var carry_capacity := 10

@onready var _mesh: MeshInstance3D = $Mesh

enum State { IDLE, MOVING, GATHERING, RETURNING }

var _state: State = State.IDLE
var _move_target := Vector3.ZERO
var _gather_timer := 0.0
var _carried := 0
var _resource_target: Node3D = null
var _hq: Node3D = null
var _selected := false

func _ready() -> void:
	add_to_group("units")
	add_to_group("selectable")
	_move_target = global_position

func _physics_process(delta: float) -> void:
	match _state:
		State.MOVING:
			_do_move()
		State.GATHERING:
			_do_gather(delta)
		State.RETURNING:
			_do_return()
		_:
			velocity = Vector3.ZERO
	move_and_slide()

func command_move(target: Vector3) -> void:
	_resource_target = null
	_move_target = target
	_state = State.MOVING

func command_gather(resource: Node3D, hq: Node3D) -> void:
	_resource_target = resource
	_hq = hq
	if _resource_target == null or _hq == null:
		return
	_move_target = _resource_target.global_position
	_state = State.MOVING

func set_hq(hq: Node3D) -> void:
	_hq = hq

func set_selected(value: bool) -> void:
	_selected = value
	var mat := StandardMaterial3D.new()
	if _selected:
		mat.albedo_color = Color(0.4, 0.9, 1.0)
	else:
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	_mesh.material_override = mat

func _do_move() -> void:
	var diff := _move_target - global_position
	diff.y = 0.0
	if diff.length() < 0.6:
		velocity = Vector3.ZERO
		if _resource_target != null and _carried < carry_capacity:
			_state = State.GATHERING
			_gather_timer = 0.0
		elif _carried > 0 and _hq != null:
			_state = State.RETURNING
		else:
			_state = State.IDLE
		return
	velocity = diff.normalized() * move_speed

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
		return
	_carried += got
	if _carried >= carry_capacity:
		_head_to_hq()

func _head_to_hq() -> void:
	if _hq == null:
		_state = State.IDLE
		return
	_move_target = _hq.global_position
	_state = State.RETURNING

func _do_return() -> void:
	if _hq == null:
		_state = State.IDLE
		return
	var diff := _hq.global_position - global_position
	diff.y = 0.0
	if diff.length() < 1.8:
		velocity = Vector3.ZERO
		if _carried > 0:
			minerals_delivered.emit(_carried)
			_carried = 0
		if _resource_target != null:
			_move_target = _resource_target.global_position
			_state = State.MOVING
		else:
			_state = State.IDLE
		return
	velocity = diff.normalized() * move_speed
