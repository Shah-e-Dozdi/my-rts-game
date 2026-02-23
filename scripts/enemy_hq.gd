extends Node3D

signal destroyed()

@export var max_hp := 2000
var hp: int

var _mesh: MeshInstance3D

func _ready() -> void:
	hp = max_hp

	# Insect Hive - organic mound structure
	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(5, 3, 5)
	_mesh.mesh = box_mesh
	_mesh.position = Vector3(0, 1.5, 0)
	add_child(_mesh)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.2, 0.1)
	_mesh.material_override = mat

	# Organic mound top
	var mound := MeshInstance3D.new()
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 2.5
	mound_mesh.height = 2.0
	mound.mesh = mound_mesh
	mound.position = Vector3(0, 3.0, 0)
	var mound_mat := StandardMaterial3D.new()
	mound_mat.albedo_color = Color(0.3, 0.15, 0.05)
	mound.material_override = mound_mat
	add_child(mound)

	# Tunnel entrances
	for offset in [Vector3(-1.5, 0.8, -2.6), Vector3(1.5, 0.8, -2.6), Vector3(0, 0.8, 2.6)]:
		var tunnel := MeshInstance3D.new()
		var tun_mesh := CylinderMesh.new()
		tun_mesh.top_radius = 0.5
		tun_mesh.bottom_radius = 0.5
		tun_mesh.height = 0.2
		tunnel.mesh = tun_mesh
		tunnel.rotation_degrees.x = 90
		tunnel.position = offset
		var tun_mat := StandardMaterial3D.new()
		tun_mat.albedo_color = Color(0.15, 0.08, 0.02)
		tunnel.material_override = tun_mat
		add_child(tunnel)

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
	if is_instance_valid(_mesh):
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color(0.6, 0.35, 0.2)
		_mesh.material_override = flash_mat
		get_tree().create_timer(0.1).timeout.connect(func() -> void:
			if is_instance_valid(_mesh):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.35, 0.2, 0.1)
				_mesh.material_override = mat
		)
	if hp <= 0:
		destroyed.emit()
		queue_free()
