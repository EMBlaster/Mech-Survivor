extends CanvasLayer

var weapon_icons: Array[Control] = []

func _ready() -> void:
	$TopLeft/ArmorBar.show_percentage = false
	$TopLeft/XPBar.show_percentage = false
	GameState.level_up.connect(_on_level_up)
	_update_xp_bar()

func refresh(player: CharacterBody2D) -> void:
	var health: HealthComponent = player.get_node("HealthComponent")
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)
	rebuild_weapon_icons()

func _process(_delta: float) -> void:
	_update_timer_label()
	_update_weapon_cooldowns()

func _on_health_changed(current: float, max_value: float) -> void:
	$TopLeft/ArmorBar.max_value = max_value
	$TopLeft/ArmorBar.value = current

func _update_xp_bar() -> void:
	var threshold_index: int = GameState.current_level - 1
	var max_xp: int
	if threshold_index < GameState.xp_thresholds.size():
		max_xp = GameState.xp_thresholds[threshold_index]
	else:
		max_xp = GameState.xp_thresholds[-1]
	$TopLeft/XPBar.max_value = max_xp
	$TopLeft/XPBar.value = GameState.current_xp

func _on_level_up(_new_level: int) -> void:
	_update_xp_bar()
	rebuild_weapon_icons()

func _update_timer_label() -> void:
	var t: float = GameState.mission_timer
	var minutes: int = int(t) / 60
	var seconds: int = int(t) % 60
	$TopRight.text = "%02d:%02d" % [minutes, seconds]

func rebuild_weapon_icons() -> void:
	for c in $WeaponRow.get_children():
		c.queue_free()
	weapon_icons.clear()
	for weapon_def in GameState.active_weapons:
		var icon := _create_weapon_icon(weapon_def)
		$WeaponRow.add_child(icon)
		weapon_icons.append(icon)

func _color_for_weapon_type(weapon_type: String) -> Color:
	match weapon_type:
		"autocannon":
			return Color(1.0, 0.7, 0.1)
		"laser":
			return Color(1.0, 0.15, 0.15)
		"missile":
			return Color(0.3, 1.0, 0.4)
		_:
			return Color(1, 1, 1)

func _create_weapon_icon(weapon_def: WeaponDef) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(48, 48)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.size = Vector2(48, 48)
	bg.color = _color_for_weapon_type(weapon_def.weapon_type)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = Vector2(48, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(overlay)

	return container

func _update_weapon_cooldowns() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for i in weapon_icons.size():
		if i >= player.weapon_components.size():
			continue
		var wc: WeaponComponent = player.weapon_components[i]
		var overlay: ColorRect = weapon_icons[i].get_node("Overlay")
		var frac: float = clamp(wc.cooldown_timer / wc.weapon_def.cooldown, 0.0, 1.0)
		overlay.size = Vector2(48, 48 * frac)
		overlay.position = Vector2(0, 0)
