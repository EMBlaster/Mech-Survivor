extends Node2D

func _ready() -> void:
	var sprite: Sprite2D = $Sprite
	var idx := randi() % 4 + 1
	var tex_path := "res://assets/explosions_cc0/Free - 2D Explosion Animations/explosion %d.png" % idx
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		sprite.texture = tex
		var target_s := 80.0 / maxf(tex.get_width(), tex.get_height())
		sprite.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2(target_s, target_s), 0.12)
		tween.tween_interval(0.05)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)
	else:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
