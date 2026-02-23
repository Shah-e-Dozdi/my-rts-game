extends Node3D

signal production_finished(unit_scene: PackedScene, spawn_pos: Vector3)

@export var max_hp := 400
var hp: int

var _mesh: MeshInstance3D
var _queue: Array[Dictionary] = []
var _build_timer := 0.0
var _is_building := false

@export var wolf_cost_wood := 60
@export var wolf_cost_resin := 0
@export var wolf_supply := 1
@export var wolf_build_time := 7.0

@export var bear_cost_wood := 100
@export var bear_cost_resin := 25
@export var bear_supply := 3
@export var bear_build_time := 16.0

@export var primate_cost_wood := 75
@export var primate_cost_resin := 15
@export var primate_supply := 2
@export var primate_build_time := 12.0

func _ready() -> void:
	hp = max_hp

	# Den - earthy burrow-style building
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(4, 1.8, 3)
	_mesh.mesh = box_mesh
	_mesh.position = Vector3(0, 0.9, 0)
	add_child(_mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.28, 0.12)
	_mesh.material_override = mat

	# Thatched roof
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(4.2, 0.3, 3.2)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 1.9, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.25, 0.35, 0.1)
	roof.material_override = roof_mat
	add_child(roof)

	# Entrance arch
	var arch := MeshInstance3D.new()
	var arch_mesh := CylinderMesh.new()
	arch_mesh.top_radius = 0.6
	arch_mesh.bottom_radius = 0.6
	arch_mesh.height = 0.15
	arch.mesh = arch_mesh
	arch.rotation_degrees.x = 90
	arch.position = Vector3(0, 0.9, -1.55)
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.3, 0.2, 0.08)
	arch.material_override = arch_mat
	add_child(arch)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(4, 1.8, 3)
	col.shape = box_shape
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)

	add_to_group("human_buildings")
	add_to_group("selectable")
	add_to_group("barracks")

func _process(delta: float) -> void:
	if _queue.is_empty():
		_is_building = false
		return

	_is_building = true
	_build_timer += delta
	var current: Dictionary = _queue[0]
	if _build_timer >= current.build_time:
		_build_timer = 0.0
		var spawn_pos := global_position + Vector3(0, 0, 3)
		production_finished.emit(current.scene, spawn_pos)
		_queue.pop_front()

func queue_wolf(scene: PackedScene) -> void:
	_queue.append({"scene": scene, "build_time": wolf_build_time})
	if _queue.size() == 1:
		_build_timer = 0.0

func queue_bear(scene: PackedScene) -> void:
	_queue.append({"scene": scene, "build_time": bear_build_time})
	if _queue.size() == 1:
		_build_timer = 0.0

func queue_primate(scene: PackedScene) -> void:
	_queue.append({"scene": scene, "build_time": primate_build_time})
	if _queue.size() == 1:
		_build_timer = 0.0

func get_queue_size() -> int:
	return _queue.size()

func get_build_progress() -> float:
	if _queue.is_empty():
		return 0.0
	return _build_timer / _queue[0].build_time

func take_damage(amount: int, _attacker: Node3D = null) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
