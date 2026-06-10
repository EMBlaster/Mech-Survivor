extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$CenterContainer/Panel/VBoxContainer.add_theme_constant_override("separation", 12)
	GameState.mission_complete.connect(_on_mission_complete)
	GameState.player_died.connect(_on_player_died)
	$CenterContainer/Panel/VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$CenterContainer/Panel/VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)

func _on_mission_complete(credits_earned: int) -> void:
	_show_result("MISSION COMPLETE", credits_earned)

func _on_player_died(credits_earned: int) -> void:
	_show_result("MECH DESTROYED", credits_earned)

func _show_result(title: String, credits_earned: int) -> void:
	$CenterContainer/Panel/VBoxContainer/TitleLabel.text = title
	$CenterContainer/Panel/VBoxContainer/CreditsLabel.text = "Credits Earned: %d" % credits_earned
	if credits_earned > 0:
		SaveManager.add_credits(credits_earned)
	get_tree().paused = true
	visible = true

func _on_retry_pressed() -> void:
	get_tree().paused = false
	GameState.reset_run(GameState.current_mech)
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
