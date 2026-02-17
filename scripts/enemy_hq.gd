extends Node3D

signal destroyed()

@export var max_hp := 2000
var hp: int

var _mesh: MeshInstance3D

func _ready() -> void:
	hp = max_hp

	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(5, 3, 5)
	_mesh.mesh = box_mesh
	_mesh.position = Vector3(0, 1.5, 0)
	add_child(_mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.1, 0.1)
	_mesh.material_override = mat

	# Spiky towers on corners
	for offset in [Vector3(-1.8, 3.0, -1.8), Vector3(1.8, 3.0, -1.8), Vector3(-1.8, 3.0, 1.8), Vector3(1.8, 3.0, 1.8)]:
		var tower := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = 0.3
		cyl.height = 1.2
		tower.mesh = cyl
		tower.position = offset
		var tower_mat := StandardMaterial3D.new()
		tower_mat.albedo_color = Color(0.4, 0.05, 0.05)
		tower.material_override = tower_mat
		add_child(tower)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(5, 3, 5)
	col.shape = box_shape
	col.position = Vector3(0, 1.5, 0)
	body.add_child(col)

	add_to_group("enemy_buildings")
	add_to_group("selectable")

func take_damage(amount: int, _attacker: Node3D = null) -> void:
	hp -= amount
	# Flash on hit
	if is_instance_valid(_mesh):
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1.0, 0.4, 0.4)
		_mesh.material_override = flash_mat
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if is_instance_valid(_mesh):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.6, 0.1, 0.1)
				_mesh.material_override = mat
		)
	if hp <= 0:
		destroyed.emit()
		queue_free()
