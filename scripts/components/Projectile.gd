extends Area2D

var damage: float = 0.0
var speed: float = 400.0
var aoe_radius: float = 0.0
var target: Node2D = null
var weapon_type: String = ""
var direction: Vector2 = Vector2.ZERO
var traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(def: WeaponDef, target_node: Node2D) -> void:
	damage = def.damage
	speed = def.projectile_speed
	aoe_radius = def.aoe_radius
	weapon_type = def.weapon_type
	target = target_node
	# Direction set at fire time -- missiles track, others don't
	if weapon_type != "missile":
		direction = global_position.direction_to(target_node.global_position)
	_apply_color()

func _apply_color() -> void:
	var color := Color(1, 1, 1)
	match weapon_type:
		"autocannon":
			color = Color(1.0, 0.7, 0.1)
		"laser":
			color = Color(1.0, 0.15, 0.15)
		"missile":
			color = Color(0.3, 1.0, 0.4)
	$Sprite.color = color

func _physics_process(delta: float) -> void:
	match weapon_type:
		"missile":
			if is_instance_valid(target):
				direction = global_position.direction_to(target.global_position)
			position += direction * speed * delta
		_:
			position += direction * speed * delta
	# Cull once it has traveled out of range (adjust as needed)
	traveled += speed * delta
	if traveled > 2000.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if aoe_radius > 0.0:
			_apply_aoe()
		else:
			body.take_damage(damage)
		queue_free()

func _apply_aoe() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= aoe_radius:
			enemy.take_damage(damage)
