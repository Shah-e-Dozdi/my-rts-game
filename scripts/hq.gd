extends Node3D

func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(4, 2, 4)
	mesh_inst.mesh = box_mesh
	mesh_inst.position = Vector3(0, 1, 0)
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(4, 2, 4)
	col.shape = box_shape
	body.add_child(col)

	add_to_group("human_buildings")
