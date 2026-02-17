extends Node3D

signal production_finished(unit_scene: PackedScene, spawn_pos: Vector3)

@export var max_hp := 600
var hp: int

var _mesh: MeshInstance3D
var _queue: Array[Dictionary] = []
var _build_timer := 0.0

const SNIPER_COST := 125
const SNIPER_SUPPLY := 2
const SNIPER_BUILD_TIME := 18.0

const HEAVY_COST := 150
const HEAVY_SUPPLY := 3
const HEAVY_BUILD_TIME := 20.0

func _ready() -> void:
	hp = max_hp

	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(4, 2.2, 3.5)
	_mesh.mesh = box_mesh
	_mesh.position = Vector3(0, 1.1, 0)
	add_child(_mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.45)
	_mesh.material_override = mat

	# Gear/cog detail on front
	var gear := MeshInstance3D.new()
	var gear_mesh := CylinderMesh.new()
	gear_mesh.top_radius = 0.5
	gear_mesh.bottom_radius = 0.5
	gear_mesh.height = 0.1
	gear.mesh = gear_mesh
	gear.rotation_degrees.x = 90
	gear.position = Vector3(0, 1.1, -1.8)
	var gear_mat := StandardMaterial3D.new()
	gear_mat.albedo_color = Color(0.6, 0.55, 0.2)
	gear.material_override = gear_mat
	add_child(gear)

	# Chimney
	var chimney := MeshInstance3D.new()
	var chimney_mesh := CylinderMesh.new()
	chimney_mesh.top_radius = 0.2
	chimney_mesh.bottom_radius = 0.25
	chimney_mesh.height = 1.0
	chimney.mesh = chimney_mesh
	chimney.position = Vector3(1.2, 2.7, 0.8)
	var chimney_mat := StandardMaterial3D.new()
	chimney_mat.albedo_color = Color(0.3, 0.3, 0.3)
	chimney.material_override = chimney_mat
	add_child(chimney)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(4, 2.2, 3.5)
	col.shape = box_shape
	col.position = Vector3(0, 1.1, 0)
	body.add_child(col)

	add_to_group("human_buildings")
	add_to_group("selectable")
	add_to_group("armories")

func _process(delta: float) -> void:
	if _queue.is_empty():
		return

	_build_timer += delta
	var current: Dictionary = _queue[0]
	if _build_timer >= current.build_time:
		_build_timer = 0.0
		var spawn_pos := global_position + Vector3(0, 0, 4)
		production_finished.emit(current.scene, spawn_pos)
		_queue.pop_front()

func queue_sniper(scene: PackedScene) -> void:
	_queue.append({"scene": scene, "build_time": SNIPER_BUILD_TIME})
	if _queue.size() == 1:
		_build_timer = 0.0

func queue_heavy(scene: PackedScene) -> void:
	_queue.append({"scene": scene, "build_time": HEAVY_BUILD_TIME})
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
