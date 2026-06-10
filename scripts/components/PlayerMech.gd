extends CharacterBody2D

const CONTACT_DAMAGE_PER_SECOND: float = 8.0

var speed: float = 80.0
var weapon_components: Array[WeaponComponent] = []
var contacted_enemies: Array[Node2D] = []

func _ready() -> void:
	add_to_group("player")
	var mech_def: MechDef = GameState.current_mech
	speed = mech_def.max_speed
	$Sprite.color = _color_for_weight_class(mech_def.weight_class)
	$HealthComponent.setup(mech_def.max_armor)
	$HealthComponent.died.connect(_on_died)
	$Hitbox.body_entered.connect(_on_hitbox_body_entered)
	$Hitbox.body_exited.connect(_on_hitbox_body_exited)
	rebuild_weapons()

func _color_for_weight_class(weight_class: String) -> Color:
	match weight_class:
		"Light":
			return Color(0.3, 0.6, 1.0)
		"Medium":
			return Color(0.3, 0.9, 0.6)
		"Heavy":
			return Color(0.9, 0.7, 0.2)
		"Assault":
			return Color(0.85, 0.2, 0.55)
		_:
			return Color(0.5, 0.5, 0.9)

func rebuild_weapons() -> void:
	for wc in weapon_components:
		wc.queue_free()
	weapon_components.clear()
	var projectile_container: Node2D = get_parent().get_node("ProjectileContainer")
	for weapon_def in GameState.active_weapons:
		var wc := WeaponComponent.new()
		$WeaponMount.add_child(wc)
		wc.setup(weapon_def, projectile_container)
		weapon_components.append(wc)

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1

	velocity = direction.normalized() * speed
	move_and_slide()

	if contacted_enemies.size() > 0:
		$HealthComponent.take_damage(CONTACT_DAMAGE_PER_SECOND * contacted_enemies.size() * delta)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		contacted_enemies.append(body)

func _on_hitbox_body_exited(body: Node2D) -> void:
	contacted_enemies.erase(body)

func _on_died() -> void:
	GameState.player_died.emit(GameState.calculate_weapon_salvage() + GameState.run_credits)
