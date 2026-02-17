extends Node3D

var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D
var _target: Node3D
var _offset_y := 1.5
var _bar_width := 1.2

func setup(target: Node3D, offset_y: float = 1.5, bar_width: float = 1.2) -> void:
	_target = target
	_offset_y = offset_y
	_bar_width = bar_width

	# Background (dark)
	_bar_bg = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(_bar_width, 0.18)
	_bar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_mat.no_depth_test = true
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.render_priority = 10
	_bar_bg.material_override = bg_mat
	add_child(_bar_bg)

	# Foreground (green fill)
	_bar_fg = MeshInstance3D.new()
	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(_bar_width - 0.04, 0.12)
	_bar_fg.mesh = fg_mesh
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.2, 0.9, 0.2)
	fg_mat.no_depth_test = true
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.render_priority = 11
	_bar_fg.material_override = fg_mat
	_bar_fg.position.z = -0.01  # slightly in front of bg
	add_child(_bar_fg)

func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	# Follow target
	global_position = _target.global_position + Vector3(0, _offset_y, 0)

	# Billboard: always face camera
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		look_at(cam.global_position, Vector3.UP)

	# Update fill
	var ratio := 1.0
	if "hp" in _target and "max_hp" in _target:
		var hp_val: float = float(_target.hp)
		var max_val: float = float(_target.max_hp)
		if max_val > 0:
			ratio = hp_val / max_val

	ratio = clampf(ratio, 0.0, 1.0)

	# Scale and reposition the foreground bar to anchor left edge
	var fill_width := (_bar_width - 0.04) * ratio
	_bar_fg.scale.x = ratio if ratio > 0.001 else 0.001
	_bar_fg.position.x = -(_bar_width - 0.04) * (1.0 - ratio) * 0.5

	# Color based on health
	var fg_mat: StandardMaterial3D = _bar_fg.material_override
	if ratio > 0.6:
		fg_mat.albedo_color = Color(0.2, 0.9, 0.2)
	elif ratio > 0.3:
		fg_mat.albedo_color = Color(0.9, 0.9, 0.1)
	else:
		fg_mat.albedo_color = Color(0.9, 0.2, 0.1)

	# Hide if full health
	visible = ratio < 1.0
