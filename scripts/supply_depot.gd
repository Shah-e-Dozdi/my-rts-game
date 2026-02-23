extends Node3D

@export var max_hp := 250
@export var supply_provided := 10
var hp: int

var _mesh: MeshInstance3D

func _ready() -> void:
	hp = max_hp

	# Burrow - small earthy supply storage
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(2.5, 1.2, 2.5)
	_mesh.mesh = box_mesh
	_mesh.position = Vector3(0, 0.6, 0)
	add_child(_mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.32, 0.18)
	_mesh.material_override = mat

	# Mound top
	var mound := MeshInstance3D.new()
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 1.0
	mound_mesh.height = 0.6
	mound.mesh = mound_mesh
	mound.position = Vector3(0, 1.2, 0)
	var mound_mat := StandardMaterial3D.new()
	mound_mat.albedo_color = Color(0.3, 0.4, 0.15)
	mound.material_override = mound_mat
	add_child(mound)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.5, 1.2, 2.5)
	col.shape = box_shape
	col.position = Vector3(0, 0.6, 0)
	body.add_child(col)

	add_to_group("human_buildings")
	add_to_group("selectable")
	add_to_group("supply_depots")

func take_damage(amount: int, _attacker: Node3D = null) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
