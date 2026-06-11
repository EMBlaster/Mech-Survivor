extends CanvasLayer

## Shown when a boss is destroyed. Pauses briefly so the player can read the
## drop, then resumes the run -- the mission itself is not ended here.
## Phase 7 (Salvage system) will populate ContentLabel with real loot.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$CenterContainer/Panel/VBoxContainer.add_theme_constant_override("separation", 12)
	$CenterContainer/Panel/VBoxContainer/DismissButton.pressed.connect(_on_dismiss_pressed)

func show_panel(content_text: String = "The boss wreck yields valuable salvage.") -> void:
	$CenterContainer/Panel/VBoxContainer/ContentLabel.text = content_text
	get_tree().paused = true
	visible = true

func _on_dismiss_pressed() -> void:
	visible = false
	get_tree().paused = false
