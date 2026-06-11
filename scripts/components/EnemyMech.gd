extends CharacterBody2D

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/fx/ExplosionFX.tscn")
const REPAIR_PACK_SCENE: PackedScene = preload("res://scenes/game/RepairPack.tscn")
const BALLISTIC_AMMO_CRATE_SCENE: PackedScene = preload("res://scenes/game/BallisticAmmoCrate.tscn")
const MISSILE_AMMO_CRATE_SCENE: PackedScene = preload("res://scenes/game/MissileAmmoCrate.tscn")

## Used when GameState.current_mission has no drop_weights override.
const DEFAULT_DROP_WEIGHTS: Dictionary = {
	"repair": 0.25,
	"ballistic_ammo": 0.08,
	"missile_ammo": 0.08,
}

signal defeated(enemy_def: EnemyDef)

var enemy_def: EnemyDef = null
var current_armor: float = 50.0
var speed: float = 60.0
var difficulty_mult: float = 1.0

func _ready() -> void:
	add_to_group("enemies")

func setup(def: EnemyDef, diff_mult: float = 1.0) -> void:
	enemy_def = def
	difficulty_mult = diff_mult
	current_armor = enemy_def.base_armor * difficulty_mult
	# Armor scales fully with difficulty, but speed scales gently so late-game
	# enemies don't outrun every mech.
	speed = enemy_def.base_speed * sqrt(difficulty_mult)
	$HealthBar.max_value = current_armor
	$HealthBar.value = current_armor
	_apply_visuals()

func _apply_visuals() -> void:
	var color := Color(1, 1, 1)
	match enemy_def.archetype:
		"scout":
			color = Color(0.8, 0.8, 0.9)
		"brawler":
			color = Color(0.9, 0.3, 0.2)
		"artillery":
			color = Color(0.6, 0.3, 0.9)
		"boss":
			color = Color(0.5, 0.0, 0.0)
			scale = Vector2(2.5, 2.5)
	$Sprite.color = color

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		velocity = global_position.direction_to(player.global_position) * speed
		move_and_slide()

func take_damage(amount: float) -> void:
	if current_armor <= 0.0:
		return
	current_armor -= amount
	$HealthBar.value = current_armor
	if current_armor <= 0.0:
		_die()

func _die() -> void:
	GameState.add_xp(enemy_def.xp_value)
	if enemy_def.credits_value > 0:
		GameState.add_run_credits(enemy_def.credits_value)
	var fx := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	_try_spawn_drop()
	defeated.emit(enemy_def)
	queue_free()

func _try_spawn_drop() -> void:
	var weights := DEFAULT_DROP_WEIGHTS
	if GameState.current_mission != null and not GameState.current_mission.drop_weights.is_empty():
		weights = GameState.current_mission.drop_weights
	var roll := randf()
	var cumulative := 0.0
	for drop_type in weights:
		cumulative += weights[drop_type]
		if roll < cumulative:
			_spawn_drop(drop_type)
			return

func _spawn_drop(drop_type: String) -> void:
	var scene: PackedScene
	match drop_type:
		"repair":
			scene = REPAIR_PACK_SCENE
		"ballistic_ammo":
			scene = BALLISTIC_AMMO_CRATE_SCENE
		"missile_ammo":
			scene = MISSILE_AMMO_CRATE_SCENE
		_:
			return
	var drop := scene.instantiate()
	drop.global_position = global_position
	get_parent().call_deferred("add_child", drop)
