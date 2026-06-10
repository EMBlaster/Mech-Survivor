extends Node2D

func _ready() -> void:
	var rect: ColorRect = $ColorRect
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
