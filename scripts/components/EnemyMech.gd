extends CharacterBody2D

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/fx/ExplosionFX.tscn")
const REPAIR_PACK_SCENE: PackedScene = preload("res://scenes/game/RepairPack.tscn")
const REPAIR_PACK_DROP_CHANCE: float = 0.25

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
	if randf() < REPAIR_PACK_DROP_CHANCE:
		var pack := REPAIR_PACK_SCENE.instantiate()
		pack.global_position = global_position
		get_parent().call_deferred("add_child", pack)
	defeated.emit(enemy_def)
	queue_free()
