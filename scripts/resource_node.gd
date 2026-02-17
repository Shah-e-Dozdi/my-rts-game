extends Node3D

@export var minerals_remaining := 1500
@onready var _mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("resource_nodes")
	_update_color()

func harvest(amount: int) -> int:
	if minerals_remaining <= 0:
		return 0
	var taken := mini(amount, minerals_remaining)
	minerals_remaining -= taken
	_update_color()
	return taken

func _update_color() -> void:
	var mat := StandardMaterial3D.new()
	if minerals_remaining <= 0:
		mat.albedo_color = Color(0.3, 0.3, 0.3)
	else:
		mat.albedo_color = Color(0.3, 0.7, 1.0)
	_mesh.material_override = mat
