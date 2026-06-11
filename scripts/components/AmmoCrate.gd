extends Area2D

## Resupply drop: restores a fixed amount to one of GameState's runtime ammo
## pools when the player walks over it. Set ammo_type per-scene instance.
@export var ammo_type: String = "ballistic"  # "ballistic" or "missile"
@export var restore_amount: int = 15

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	match ammo_type:
		"ballistic":
			GameState.ballistic_ammo += restore_amount
			GameState.ballistic_ammo_max = max(GameState.ballistic_ammo_max, GameState.ballistic_ammo)
		"missile":
			GameState.missile_ammo += restore_amount
			GameState.missile_ammo_max = max(GameState.missile_ammo_max, GameState.missile_ammo)
	queue_free()
