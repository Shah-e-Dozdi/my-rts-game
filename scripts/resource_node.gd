extends Node3D

@export var minerals_remaining := 1500

var _mesh: MeshInstance3D
var _initial_minerals: int

func _ready() -> void:
	_initial_minerals = minerals_remaining

	_mesh = MeshInstance3D.new()
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.6
	cyl_mesh.bottom_radius = 0.6
	cyl_mesh.height = 1.2
	_mesh.mesh = cyl_mesh
	add_child(_mesh)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.6
	cyl_shape.height = 1.2
	col.shape = cyl_shape
	body.add_child(col)

	add_to_group("resource_nodes")
	_update_visual()

func harvest(amount: int) -> int:
	if minerals_remaining <= 0:
		return 0
	var taken := mini(amount, minerals_remaining)
	minerals_remaining -= taken
	_update_visual()
	return taken

func _update_visual() -> void:
	var mat := StandardMaterial3D.new()
	if minerals_remaining <= 0:
		mat.albedo_color = Color(0.3, 0.3, 0.3)
	else:
		mat.albedo_color = Color(0.3, 0.7, 1.0)
	_mesh.material_override = mat

	# Shrink as minerals deplete
	if _initial_minerals > 0:
		var ratio := float(minerals_remaining) / float(_initial_minerals)
		var s := lerpf(0.3, 1.0, ratio)
		_mesh.scale = Vector3(s, s, s)
