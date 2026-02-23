extends Node3D

signal production_finished(unit_scene: PackedScene, spawn_pos: Vector3)

@export var max_hp := 1000
var hp: int

var _mesh: MeshInstance3D
var _queue: Array[Dictionary] = []
var _build_timer := 0.0

const WORKER_COST := 50
const WORKER_SUPPLY := 1
const WORKER_BUILD_TIME := 12.0

func _ready() -> void:
	hp = max_hp

	# Lodge - wooden cabin style HQ
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(4, 2, 4)
	_mesh.mesh = box_mesh
	_mesh.position = Vector3(0, 1, 0)
	add_child(_mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.15)
	_mesh.material_override = mat

	# Peaked roof
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(4.4, 0.4, 4.4)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 2.2, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.2, 0.08)
	roof.material_override = roof_mat
	add_child(roof)

	# Log accent pillars
	for offset in [Vector3(-1.8, 1, -1.8), Vector3(1.8, 1, -1.8), Vector3(-1.8, 1, 1.8), Vector3(1.8, 1, 1.8)]:
		var pillar := MeshInstance3D.new()
		var pil_mesh := CylinderMesh.new()
		pil_mesh.top_radius = 0.12
		pil_mesh.bottom_radius = 0.12
		pil_mesh.height = 2.0
		pillar.mesh = pil_mesh
		pillar.position = offset
		var pil_mat := StandardMaterial3D.new()
		pil_mat.albedo_color = Color(0.35, 0.22, 0.1)
		pillar.material_override = pil_mat
		add_child(pillar)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(4, 2, 4)
	col.shape = box_shape
	col.position = Vector3(0, 1, 0)
	body.add_child(col)

	add_to_group("human_buildings")
	add_to_group("selectable")

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

func queue_worker(scene: PackedScene) -> void:
	_queue.append({"scene": scene, "build_time": WORKER_BUILD_TIME})
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
