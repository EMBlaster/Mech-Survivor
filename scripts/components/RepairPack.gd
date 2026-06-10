extends Area2D

const HEAL_AMOUNT: float = 10.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var health: HealthComponent = body.get_node_or_null("HealthComponent")
	if health:
		health.heal(HEAL_AMOUNT)
	queue_free()
