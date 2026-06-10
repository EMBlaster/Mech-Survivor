extends CharacterBody2D

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/fx/ExplosionFX.tscn")

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
	speed = enemy_def.base_speed * difficulty_mult
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
	current_armor -= amount
	$HealthBar.value = current_armor
	if current_armor <= 0.0:
		_die()

func _die() -> void:
	GameState.add_xp(enemy_def.xp_value)
	if enemy_def.credits_value > 0:
		SaveManager.add_credits(enemy_def.credits_value)
	var fx := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	defeated.emit(enemy_def)
	queue_free()
