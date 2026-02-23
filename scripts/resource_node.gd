extends Node3D

@export var resource_type: String = "wood"
@export var amount_remaining := 1500

var _mesh: MeshInstance3D
var _initial_amount: int

func _ready() -> void:
	_initial_amount = amount_remaining

	_mesh = MeshInstance3D.new()

	if resource_type == "resin":
		# Resin: amber crystalline shape
		var cyl_mesh := CylinderMesh.new()
		cyl_mesh.top_radius = 0.3
		cyl_mesh.bottom_radius = 0.5
		cyl_mesh.height = 1.0
		_mesh.mesh = cyl_mesh
	else:
		# Wood: tree trunk shape
		var cyl_mesh := CylinderMesh.new()
		cyl_mesh.top_radius = 0.4
		cyl_mesh.bottom_radius = 0.6
		cyl_mesh.height = 1.8
		_mesh.mesh = cyl_mesh
		_mesh.position.y = 0.9

		# Canopy
		var canopy := MeshInstance3D.new()
		var canopy_mesh := SphereMesh.new()
		canopy_mesh.radius = 1.2
		canopy_mesh.height = 1.6
		canopy.mesh = canopy_mesh
		canopy.position.y = 1.2
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = Color(0.15, 0.45, 0.12)
		canopy.material_override = canopy_mat
		_mesh.add_child(canopy)

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
	if amount_remaining <= 0:
		return 0
	var taken := mini(amount, amount_remaining)
	amount_remaining -= taken
	_update_visual()
	return taken

func get_resource_type() -> String:
	return resource_type

func _update_visual() -> void:
	var mat := StandardMaterial3D.new()
	if amount_remaining <= 0:
		mat.albedo_color = Color(0.3, 0.3, 0.3)
	elif resource_type == "resin":
		mat.albedo_color = Color(0.85, 0.6, 0.15)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.25, 0.05)
		mat.emission_energy_multiplier = 0.3
	else:
		mat.albedo_color = Color(0.45, 0.3, 0.15)
	_mesh.material_override = mat

	if _initial_amount > 0:
		var ratio := float(amount_remaining) / float(_initial_amount)
		var s := lerpf(0.3, 1.0, ratio)
		_mesh.scale = Vector3(s, s, s)
