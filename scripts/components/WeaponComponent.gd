class_name WeaponComponent extends Node2D

var weapon_def: WeaponDef = null
var cooldown_timer: float = 0.0
var projectile_container: Node2D  # set by PlayerMech on instantiation

func setup(def: WeaponDef, container: Node2D) -> void:
	weapon_def = def
	projectile_container = container
	cooldown_timer = 0.0

func _process(delta: float) -> void:
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		_try_fire()

func _try_fire() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > weapon_def.range:
		return
	_spawn_projectile(target)
	cooldown_timer = weapon_def.cooldown

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF
	for e in enemies:
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

func _spawn_projectile(target: Node2D) -> void:
	if weapon_def.projectile_scene == null:
		return
	var proj = weapon_def.projectile_scene.instantiate()
	projectile_container.add_child(proj)
	proj.global_position = global_position
	proj.setup(weapon_def, target)
