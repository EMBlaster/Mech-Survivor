extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$CenterContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	$CenterContainer/VBoxContainer/StartButton.text = "Start [Enter]"
	$CenterContainer/VBoxContainer/QuitButton.text = "Quit [Q]"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_start"):
		_on_start_pressed()
	elif event.is_action_pressed("menu_quit") or event.is_action_pressed("menu_back"):
		_on_quit_pressed()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MechSelect.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
