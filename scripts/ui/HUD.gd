extends CanvasLayer

signal extract_requested

var weapon_icons: Array[Control] = []

func _ready() -> void:
	$TopLeft/ArmorBar.show_percentage = false
	$TopLeft/XPBar.show_percentage = false
	GameState.level_up.connect(_on_level_up)
	GameState.xp_changed.connect(_on_xp_changed)
	_update_xp_bar()
	$ExtractButton.pressed.connect(_on_extract_button_pressed)
	$ExtractConfirm.confirmed.connect(_on_extract_confirmed)
	$SalvageNotice.visible = false
	$SalvageNotice/HideTimer.timeout.connect(func(): $SalvageNotice.visible = false)

func _on_extract_button_pressed() -> void:
	if GameState.current_mission != null and GameState.current_mission.win_condition == "survive":
		$ExtractConfirm.dialog_text = "Extract now? The mission isn't complete yet -- you will forfeit all rewards from this run."
	else:
		$ExtractConfirm.dialog_text = "Extract from the mission and bank your rewards?"
	$ExtractConfirm.popup_centered()

func _on_extract_confirmed() -> void:
	extract_requested.emit()

func refresh(player: CharacterBody2D) -> void:
	var health: HealthComponent = player.get_node("HealthComponent")
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)
	rebuild_weapon_icons()

func _process(_delta: float) -> void:
	_update_timer_label()
	_update_weapon_cooldowns()
	_update_ammo_pool_label()
	_update_dash_indicator()

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

## Standard salvage (spec 7.1) replaces the old level-up weapon-choice
## offer: a small reward is granted immediately and shown as a brief,
## non-interrupting drop notification.
func _on_level_up(_new_level: int) -> void:
	_update_xp_bar()
	var msg := SalvageSystem.roll_standard_salvage()
	$SalvageNotice.text = msg
	$SalvageNotice.visible = true
	$SalvageNotice/HideTimer.start()

func _on_xp_changed(_current_xp: int, _current_level: int) -> void:
	_update_xp_bar()

func _update_timer_label() -> void:
	var mission := GameState.current_mission
	var t: float = GameState.mission_timer
	if mission == null:
		$TopRight.text = _format_time(t)
		return
	if mission.win_condition == "defeat_boss" and mission.boss_spawn_time > 0.0 and t < mission.boss_spawn_time:
		$TopRight.text = "BOSS IN " + _format_time(mission.boss_spawn_time - t)
	elif mission.win_condition == "survive":
		$TopRight.text = _format_time(t) + " / " + _format_time(mission.duration_seconds)
	else:
		$TopRight.text = _format_time(t)

func _format_time(t: float) -> String:
	var minutes: int = int(t) / 60
	var seconds: int = int(t) % 60
	return "%02d:%02d" % [minutes, seconds]

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

	var ammo_label := Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.size = Vector2(48, 16)
	ammo_label.position = Vector2(0, 32)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_label.add_theme_font_size_override("font_size", 12)
	ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(ammo_label)

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
		var frac: float = clamp(wc.cooldown_timer / wc.weapon_def.get_cooldown(), 0.0, 1.0)
		overlay.size = Vector2(48, 48 * frac)
		overlay.position = Vector2(0, 0)
		_update_ammo_label(weapon_icons[i].get_node("AmmoLabel"), wc.weapon_def)

## Per-weapon ammo counter: shots remaining, color-coded by scarcity.
## Energy weapons (ammo_type == "") show no indicator.
func _update_ammo_label(label: Label, weapon_def: WeaponDef) -> void:
	if weapon_def.ammo_type == "":
		label.text = ""
		return
	var shots := GameState.get_effective_shots(weapon_def)
	label.text = str(shots)
	var pool: int = GameState.ballistic_ammo if weapon_def.ammo_type == "ballistic" else GameState.missile_ammo
	var pool_max: int = GameState.ballistic_ammo_max if weapon_def.ammo_type == "ballistic" else GameState.missile_ammo_max
	if shots <= 0:
		label.modulate = Color(0.5, 0.5, 0.5)
	elif shots <= 3:
		label.modulate = Color(1.0, 0.2, 0.2)
	elif pool_max > 0 and float(pool) / pool_max <= 0.25:
		label.modulate = Color(1.0, 0.85, 0.2)
	else:
		label.modulate = Color(1, 1, 1)

## Persistent pool summary -- raw ballistic/missile ammo totals.
func _update_ammo_pool_label() -> void:
	$AmmoPoolLabel.text = "Ballistic: %d   Missile: %d" % [GameState.ballistic_ammo, GameState.missile_ammo]

## Dash readiness (Jump Jets, spec 8.3): only shown if the active loadout
## includes Jump Jets. Overlay drains as the dash cooldown recovers.
func _update_dash_indicator() -> void:
	$DashIndicator.visible = GameState.has_jump_jets
	if not GameState.has_jump_jets:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var overlay: ColorRect = $DashIndicator/Overlay
	var frac: float = clamp(player.dash_cooldown_timer / player.DASH_COOLDOWN, 0.0, 1.0)
	overlay.size = Vector2(48, 48 * frac)
	overlay.position = Vector2(0, 0)
