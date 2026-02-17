extends Node

const EnemyMeleeScene := preload("res://scenes/EnemyMelee.tscn")
const EnemyHQScene := preload("res://scenes/EnemyHQ.tscn")

var _world: Node3D
var _spawn_point := Vector3(80, 0, -80)
var _wave_timer := 0.0
var _wave_interval := 45.0
var _wave_number := 0
var _min_interval := 20.0

var _enemy_hq: Node3D = null
var _hq_destroyed := false

func setup(world: Node3D) -> void:
	_world = world
	_build_enemy_base()
	# First wave comes faster
	_wave_timer = _wave_interval - 15.0

func _build_enemy_base() -> void:
	_enemy_hq = EnemyHQScene.instantiate()
	_enemy_hq.position = _spawn_point
	_world.add_child(_enemy_hq)
	_enemy_hq.destroyed.connect(_on_enemy_hq_destroyed)

	# Spawn a few starting defenders
	for i in 3:
		var guard := EnemyMeleeScene.instantiate()
		var angle := TAU * float(i) / 3.0
		guard.position = _spawn_point + Vector3(cos(angle) * 6.0, 0, sin(angle) * 6.0)
		_world.add_child(guard)

func get_enemy_hq() -> Node3D:
	return _enemy_hq

func _on_enemy_hq_destroyed() -> void:
	_hq_destroyed = true

func _process(delta: float) -> void:
	if _hq_destroyed:
		return

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
