extends Control

const MECH_DEFS: Array[MechDef] = [
	preload("res://resources/mechs/jackal_jkl1a.tres"),
	preload("res://resources/mechs/rampart_rmp4g.tres"),
	preload("res://resources/mechs/ballista_bls_c1.tres"),
	preload("res://resources/mechs/anvil_anv6r.tres"),
	preload("res://resources/mechs/colossus_cls7d.tres"),
]

var selected_mech: MechDef = null
var selected_mission: MissionDef = null
var mech_buttons: Array[Button] = []
var mission_buttons: Array[Button] = []

func _ready() -> void:
	$VBoxContainer.add_theme_constant_override("separation", 16)
	$VBoxContainer/MechList.add_theme_constant_override("separation", 12)
	$VBoxContainer/MissionList.add_theme_constant_override("separation", 12)
	$VBoxContainer.offset_left = 16
	$VBoxContainer.offset_top = 16
	$VBoxContainer.offset_right = -16
	$VBoxContainer.offset_bottom = -16
	$VBoxContainer/CreditsLabel.text = "Credits: %d" % SaveManager.credits
	_build_mech_buttons()
	_build_mission_buttons()
	$VBoxContainer/LaunchButton.pressed.connect(_on_launch_pressed)
	$VBoxContainer/MechLabButton.pressed.connect(_on_mech_lab_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	$VBoxContainer/LaunchButton.text = "Launch Mission [L]"
	$VBoxContainer/MechLabButton.text = "Mech Lab [M]"
	$VBoxContainer/BackButton.text = "Back [Esc]"
	_add_corp_store_button()
	selected_mech = MECH_DEFS[0]
	selected_mission = MissionBoard.available_missions[0]
	_update_launch_state()

func _build_mech_buttons() -> void:
	for mech in MECH_DEFS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(220, 110)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		_update_mech_button_text(btn, mech)
		btn.pressed.connect(_on_mech_pressed.bind(mech, btn))
		$VBoxContainer/MechList.add_child(btn)
		mech_buttons.append(btn)
	mech_buttons[0].button_pressed = true

func _update_mech_button_text(btn: Button, mech: MechDef) -> void:
	var status: String = "" if SaveManager.is_unlocked(mech.mech_name) else "\nLOCKED - Cost: %d" % mech.unlock_cost
	var loadout_line: String = "" if status != "" else "\n%s" % _loadout_summary(mech)
	btn.text = "%s\n%s\nHP: %.0f  Speed: %.0f%s%s" % [mech.mech_name, mech.weight_class, mech.max_armor, mech.max_speed, status, loadout_line]

## One-line summary of the mech's saved loadout (or default loadout if none
## has been saved yet) for display on the Mech Select screen.
func _loadout_summary(mech: MechDef) -> String:
	var loadout := SaveManager.get_loadout(mech)
	var weapon_names: Array[String] = []
	for item_key in loadout.get("items", []):
		var w := ItemDatabase.get_weapon(item_key)
		if w != null:
			weapon_names.append("%s T%d" % [w.weapon_name, w.tier])
	if weapon_names.is_empty():
		return "Loadout: (empty)"
	return "Loadout: " + ", ".join(weapon_names)

func _on_mech_pressed(mech: MechDef, btn: Button) -> void:
	if not SaveManager.is_unlocked(mech.mech_name):
		if SaveManager.spend_credits(mech.unlock_cost):
			SaveManager.unlock_mech(mech.mech_name)
			_update_mech_button_text(btn, mech)
			$VBoxContainer/CreditsLabel.text = "Credits: %d" % SaveManager.credits
		else:
			btn.button_pressed = false
			return
	for b in mech_buttons:
		b.button_pressed = (b == btn)
	selected_mech = mech
	_update_launch_state()

func _build_mission_buttons() -> void:
	for mission in MissionBoard.available_missions:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(160, 60)
		btn.text = _mission_button_text(mission)
		btn.pressed.connect(_on_mission_pressed.bind(mission, btn))
		$VBoxContainer/MissionList.add_child(btn)
		mission_buttons.append(btn)
	mission_buttons[0].button_pressed = true

func _mission_button_text(mission: MissionDef) -> String:
	var prefix := ""
	if not mission.sponsored_by_corp.is_empty():
		for corp in MissionBoard.CORPS:
			if corp.corp_name == mission.sponsored_by_corp:
				if not corp.symbol.is_empty():
					prefix = corp.symbol + " "
				break
	var contract_tag := "  [CONTRACT]" if not mission.sponsored_by_corp.is_empty() else ""
	return "%s%s\n%ds  Reward: %d%s" % [
		prefix,
		mission.mission_name,
		int(mission.duration_seconds),
		mission.credit_reward,
		contract_tag,
	]

func _on_mission_pressed(mission: MissionDef, btn: Button) -> void:
	for b in mission_buttons:
		b.button_pressed = (b == btn)
	selected_mission = mission

func _update_launch_state() -> void:
	$VBoxContainer/LaunchButton.disabled = selected_mech == null or not SaveManager.is_unlocked(selected_mech.mech_name)

func _on_launch_pressed() -> void:
	GameState.reset_run(selected_mech)
	GameState.current_mission = selected_mission
	get_tree().change_scene_to_file("res://scenes/game/Arena.tscn")

func _on_mech_lab_pressed() -> void:
	GameState.current_mech = selected_mech
	get_tree().change_scene_to_file("res://scenes/ui/MechLab.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_launch"):
		if not $VBoxContainer/LaunchButton.disabled:
			_on_launch_pressed()
	elif event.is_action_pressed("menu_mech_lab"):
		_on_mech_lab_pressed()
	elif event.is_action_pressed("menu_corp_store"):
		if not SaveManager.corp_store_access.is_empty():
			_on_corp_store_pressed()
	elif event.is_action_pressed("menu_back"):
		_on_back_pressed()

func _add_corp_store_button() -> void:
	if SaveManager.corp_store_access.is_empty():
		return
	var btn := Button.new()
	btn.text = "Corp Store [C]\n[%s]" % SaveManager.corp_store_access
	btn.pressed.connect(_on_corp_store_pressed)
	$VBoxContainer.add_child(btn)
	$VBoxContainer.move_child(btn, $VBoxContainer/BackButton.get_index())

func _on_corp_store_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CorpStore.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
