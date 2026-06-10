class_name HealthComponent extends Node

signal died
signal health_changed(current: float, max: float)

var max_health: float = 100.0
var current_health: float = 100.0

func setup(max_hp: float) -> void:
	max_health = max_hp
	current_health = max_hp
	health_changed.emit(current_health, max_health)

func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = max(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
