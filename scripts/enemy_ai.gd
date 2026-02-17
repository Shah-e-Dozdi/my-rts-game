extends Node

const EnemyMeleeScene := preload("res://scenes/EnemyMelee.tscn")

var _world: Node3D
var _spawn_point := Vector3(80, 0, -80)
var _wave_timer := 0.0
var _wave_interval := 45.0
var _wave_number := 0
var _min_interval := 20.0

# Enemy base visual
var _enemy_hq: MeshInstance3D

func setup(world: Node3D) -> void:
	_world = world
	_build_enemy_base()
	# First wave comes faster
	_wave_timer = _wave_interval - 15.0

func _build_enemy_base() -> void:
	# Visual-only enemy HQ
	var base := Node3D.new()
	base.name = "EnemyBase"
	base.position = _spawn_point
	_world.add_child(base)

	_enemy_hq = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(5, 2.5, 5)
	_enemy_hq.mesh = box_mesh
	_enemy_hq.position = Vector3(0, 1.25, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.1, 0.1)
	_enemy_hq.material_override = mat
	base.add_child(_enemy_hq)

	# Collision for the enemy base
	var body := StaticBody3D.new()
	base.add_child(body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(5, 2.5, 5)
	col.shape = box_shape
	col.position = Vector3(0, 1.25, 0)
	body.add_child(col)

func _process(delta: float) -> void:
	_wave_timer += delta
	if _wave_timer >= _wave_interval:
		_wave_timer = 0.0
		_wave_number += 1
		_spawn_wave()
		# Speed up waves over time
		_wave_interval = maxf(_min_interval, _wave_interval - 2.0)

func _spawn_wave() -> void:
	if _world == null:
		return
	var count := 2 + _wave_number
	count = mini(count, 12)

	# Find player HQ or center as attack target
	var target_pos := Vector3.ZERO
	var hqs := get_tree().get_nodes_in_group("human_buildings")
	if not hqs.is_empty():
		target_pos = hqs[0].global_position

	for i in count:
		var enemy := EnemyMeleeScene.instantiate()
		var offset := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		enemy.position = _spawn_point + offset
		_world.add_child(enemy)
		# Send them toward the player base
		enemy.command_move(target_pos + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
