extends Node3D

@export var minerals_remaining: int = 1500
@onready var _mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("resource_nodes")
	_update_visual_state()

func harvest(requested_amount: int) -> int:
	if minerals_remaining <= 0:
		return 0

	var mined: int = min(requested_amount, minerals_remaining)
	minerals_remaining -= mined
	_update_visual_state()
	return mined

func _update_visual_state() -> void:
	var mat := StandardMaterial3D.new()
	if minerals_remaining <= 0:
		mat.albedo_color = Color(0.2, 0.2, 0.2, 1.0)
	else:
		mat.albedo_color = Color(0.35, 0.75, 1.0, 1.0)
	_mesh.material_override = mat
