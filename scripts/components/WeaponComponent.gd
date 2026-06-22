class_name WeaponComponent extends Node2D

const OUT_OF_AMMO_ALPHA: float = 0.15

var weapon_def: WeaponDef = null
var cooldown_timer: float = 0.0
var projectile_container: Node2D  # set by PlayerMech on instantiation
var out_of_ammo: bool = false

func setup(def: WeaponDef, container: Node2D) -> void:
	weapon_def = def
	projectile_container = container
	cooldown_timer = 0.0
	out_of_ammo = false
	modulate = Color(1, 1, 1, 1)
	queue_redraw()

func _draw() -> void:
	if weapon_def == null:
		return
	var color := _range_color(weapon_def.weapon_type)
	if out_of_ammo:
		return
	draw_circle(Vector2.ZERO, weapon_def.fire_range, Color(color.r, color.g, color.b, 0.05))
	draw_arc(Vector2.ZERO, weapon_def.fire_range, 0, TAU, 64, Color(color.r, color.g, color.b, 0.35), 1.5)

func _range_color(weapon_type: String) -> Color:
	match weapon_type:
		"autocannon":
			return Color(1.0, 0.7, 0.1)
		"laser":
			return Color(1.0, 0.15, 0.15)
		"missile":
			return Color(0.3, 1.0, 0.4)
		_:
			return Color(1, 1, 1)

func _process(delta: float) -> void:
	_update_ammo_state()
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		_try_fire()

## Dims the weapon (and hides its range circle) while it has no ammo left,
## restoring full visibility once reloaded (e.g. via a salvage ammo bin).
func _update_ammo_state() -> void:
	var ooa := weapon_def.ammo_type != "" and not GameState.has_ammo(weapon_def)
	if ooa == out_of_ammo:
		return
	out_of_ammo = ooa
	modulate = Color(1, 1, 1, OUT_OF_AMMO_ALPHA) if out_of_ammo else Color(1, 1, 1, 1)
	queue_redraw()

func _try_fire() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > weapon_def.fire_range:
		return
	if not GameState.has_ammo(weapon_def):
		return
	_spawn_projectile(target)
	GameState.consume_ammo(weapon_def)
	cooldown_timer = weapon_def.get_cooldown() * GameState.heat_sink_multiplier

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
