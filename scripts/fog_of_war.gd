extends Node3D

var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_plane: MeshInstance3D
var _fog_mat: ShaderMaterial

var _resolution := 256
var _map_size := 200.0
var _half_map: float

# Default vision ranges for units that don't have the property
const DEFAULT_UNIT_VISION := 15.0
const DEFAULT_BUILDING_VISION := 12.0

func _ready() -> void:
	_half_map = _map_size / 2.0

	# Create fog image (R channel = visibility: 0=visible, 1=fogged)
	_fog_image = Image.create(_resolution, _resolution, false, Image.FORMAT_L8)
	_fog_image.fill(Color(1, 1, 1, 1))
	_fog_texture = ImageTexture.create_from_image(_fog_image)

	# Create fog overlay plane
	_fog_plane = MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(_map_size, _map_size)
	_fog_plane.mesh = plane_mesh
	_fog_plane.position = Vector3(0, 0.2, 0)

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D fog_texture : filter_linear;

void fragment() {
	float fog = texture(fog_texture, UV).r;
	ALBEDO = vec3(0.0, 0.0, 0.02);
	ALPHA = fog * 0.7;
}
"""
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = shader
	_fog_mat.set_shader_parameter("fog_texture", _fog_texture)
	_fog_plane.material_override = _fog_mat
	add_child(_fog_plane)

func _process(_delta: float) -> void:
	_update_fog_texture()
	_update_enemy_visibility()

func _update_fog_texture() -> void:
	# Start fully fogged
	_fog_image.fill(Color(1, 1, 1, 1))

	# Reveal areas around player units
	for unit in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(unit):
			var vision: float = DEFAULT_UNIT_VISION
			if "vision_range" in unit:
				vision = unit.vision_range
			_paint_circle(unit.global_position, vision)

	# Reveal areas around player buildings
	for bld in get_tree().get_nodes_in_group("human_buildings"):
		if is_instance_valid(bld):
			_paint_circle(bld.global_position, DEFAULT_BUILDING_VISION)

	_fog_texture.update(_fog_image)

func _paint_circle(world_pos: Vector3, radius: float) -> void:
	var px := int((world_pos.x + _half_map) / _map_size * _resolution)
	var pz := int((world_pos.z + _half_map) / _map_size * _resolution)
	var pr := int(radius / _map_size * _resolution)

	var x_min := maxi(0, px - pr)
	var x_max := mini(_resolution - 1, px + pr)
	var z_min := maxi(0, pz - pr)
	var z_max := mini(_resolution - 1, pz + pr)
	var pr_sq := pr * pr

	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			var dx := x - px
			var dz := z - pz
			if dx * dx + dz * dz <= pr_sq:
				_fog_image.set_pixel(x, z, Color(0, 0, 0, 0))

func _update_enemy_visibility() -> void:
	for group_name in ["enemy_units", "enemy_buildings"]:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(enemy):
				continue
			enemy.visible = _is_position_visible(enemy.global_position)

func _is_position_visible(world_pos: Vector3) -> bool:
	# Check against all player units
	for unit in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(unit):
			continue
		var vision: float = DEFAULT_UNIT_VISION
		if "vision_range" in unit:
			vision = unit.vision_range
		var diff := unit.global_position - world_pos
		diff.y = 0.0
		if diff.length() <= vision:
			return true

	# Check against all player buildings
	for bld in get_tree().get_nodes_in_group("human_buildings"):
		if not is_instance_valid(bld):
			continue
		var diff := bld.global_position - world_pos
		diff.y = 0.0
		if diff.length() <= DEFAULT_BUILDING_VISION:
			return true

	return false
