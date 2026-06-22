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

var _mech_list: VBoxContainer = null
var _mission_list: VBoxContainer = null
var _credits_label: Label = null
var _launch_btn: Button = null
var _mech_lab_btn: Button = null
var _back_btn: Button = null
var _action_col: VBoxContainer = null

func _ready() -> void:
	_build_layout()
	_build_mech_buttons()
	_build_mission_buttons()
	_add_corp_store_button()
	selected_mech = MECH_DEFS[0]
	selected_mission = MissionBoard.available_missions[0]
	_update_launch_state()

func _build_layout() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_top = 16
	hbox.offset_right = -16
	hbox.offset_bottom = -16
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	# --- Left column: mechs ---
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hbox.add_child(left)

	var mech_header := Label.new()
	mech_header.text = "MECHS"
	left.add_child(mech_header)

	var mech_scroll := ScrollContainer.new()
	mech_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(mech_scroll)

	_mech_list = VBoxContainer.new()
	_mech_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mech_list.add_theme_constant_override("separation", 12)
	mech_scroll.add_child(_mech_list)

	# --- Middle column: missions ---
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	hbox.add_child(mid)

	var mission_header := Label.new()
	mission_header.text = "MISSIONS"
	mid.add_child(mission_header)

	_mission_list = VBoxContainer.new()
	_mission_list.add_theme_constant_override("separation", 12)
	mid.add_child(_mission_list)

	# --- Right column: actions ---
	_action_col = VBoxContainer.new()
	_action_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_col.add_theme_constant_override("separation", 8)
	hbox.add_child(_action_col)

	_credits_label = Label.new()
	_credits_label.text = "Credits: %d" % SaveManager.credits
	_action_col.add_child(_credits_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_col.add_child(spacer)

	_launch_btn = Button.new()
	_launch_btn.text = "Launch Mission [L]"
	_launch_btn.pressed.connect(_on_launch_pressed)
	_action_col.add_child(_launch_btn)

	_mech_lab_btn = Button.new()
	_mech_lab_btn.text = "Mech Lab [M]"
	_mech_lab_btn.pressed.connect(_on_mech_lab_pressed)
	_action_col.add_child(_mech_lab_btn)

	_back_btn = Button.new()
	_back_btn.text = "Back [Esc]"
	_back_btn.pressed.connect(_on_back_pressed)
	_action_col.add_child(_back_btn)

# --- Mech buttons ---

func _build_mech_buttons() -> void:
	for mech in MECH_DEFS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 175)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.clip_contents = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var loadout_lbl := RichTextLabel.new()
		loadout_lbl.name = "LoadoutLabel"
		loadout_lbl.bbcode_enabled = true
		loadout_lbl.scroll_active = false
		loadout_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loadout_lbl.anchor_left = 0
		loadout_lbl.anchor_top = 1
		loadout_lbl.anchor_right = 1
		loadout_lbl.anchor_bottom = 1
		loadout_lbl.offset_left = 6
		loadout_lbl.offset_right = -6
		loadout_lbl.offset_bottom = -4
		loadout_lbl.offset_top = -58
		btn.add_child(loadout_lbl)

		_update_mech_button_text(btn, mech)
		btn.pressed.connect(_on_mech_pressed.bind(mech, btn))
		_mech_list.add_child(btn)
		mech_buttons.append(btn)
	mech_buttons[0].button_pressed = true

func _update_mech_button_text(btn: Button, mech: MechDef) -> void:
	var locked := not SaveManager.is_unlocked(mech.mech_name)
	if locked:
		btn.text = "%s\n%s\nHP: %.0f  Speed: %.0f\nLOCKED - Cost: %d" % [
			mech.mech_name, mech.weight_class, mech.max_armor, mech.max_speed, mech.unlock_cost]
	else:
		btn.text = "%s\n%s\nHP: %.0f  Speed: %.0f" % [
			mech.mech_name, mech.weight_class, mech.max_armor, mech.max_speed]
	var lbl: RichTextLabel = btn.get_node_or_null("LoadoutLabel")
	if lbl == null:
		return
	lbl.text = "" if locked else _loadout_bbcode(mech)

func _loadout_bbcode(mech: MechDef) -> String:
	var loadout := SaveManager.get_loadout(mech)
	var parts: Array[String] = []
	for item_key in loadout.get("items", []):
		if item_key.is_empty():
			continue
		var w := ItemDatabase.get_weapon(item_key)
		if w == null:
			continue
		var hex := _tier_color(w.tier).to_html(false)
		var sym := ""
		for corp in MissionBoard.CORPS:
			if corp.corp_name == w.manufacturer and not corp.symbol.is_empty():
				sym = corp.symbol + " "
				break
		parts.append("[color=#%s]%s%s[/color]" % [hex, sym, w.weapon_name])
	if parts.is_empty():
		return "Loadout: (empty)"
	return "Loadout: " + ", ".join(parts)

static func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(1.0, 1.0, 1.0)
		2: return Color(0.3, 0.9, 0.3)
		3: return Color(0.4, 0.6, 1.0)
		4: return Color(0.8, 0.4, 1.0)
		_: return Color(1.0, 0.85, 0.2)

func _on_mech_pressed(mech: MechDef, btn: Button) -> void:
	if not SaveManager.is_unlocked(mech.mech_name):
		if SaveManager.spend_credits(mech.unlock_cost):
			SaveManager.unlock_mech(mech.mech_name)
			_update_mech_button_text(btn, mech)
			_credits_label.text = "Credits: %d" % SaveManager.credits
		else:
			btn.button_pressed = false
			return
	for b in mech_buttons:
		b.button_pressed = (b == btn)
	selected_mech = mech
	_update_launch_state()

# --- Mission buttons ---

func _build_mission_buttons() -> void:
	for mission in MissionBoard.available_missions:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.text = _mission_button_text(mission)
		btn.pressed.connect(_on_mission_pressed.bind(mission, btn))
		_mission_list.add_child(btn)
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

# --- Action buttons ---

func _update_launch_state() -> void:
	_launch_btn.disabled = selected_mech == null or not SaveManager.is_unlocked(selected_mech.mech_name)

func _on_launch_pressed() -> void:
	GameState.reset_run(selected_mech)
	GameState.current_mission = selected_mission
	get_tree().change_scene_to_file("res://scenes/game/Arena.tscn")

func _on_mech_lab_pressed() -> void:
	GameState.current_mech = selected_mech
	get_tree().change_scene_to_file("res://scenes/ui/MechLab.tscn")

func _add_corp_store_button() -> void:
	if SaveManager.corp_store_access.is_empty():
		return
	var corp_sym := ""
	for corp in MissionBoard.CORPS:
		if corp.corp_name == SaveManager.corp_store_access and not corp.symbol.is_empty():
			corp_sym = corp.symbol + " "
			break
	var btn := Button.new()
	btn.text = "Corp Store [C]\n%s%s" % [corp_sym, SaveManager.corp_store_access]
	btn.pressed.connect(_on_corp_store_pressed)
	_action_col.add_child(btn)
	_action_col.move_child(btn, _back_btn.get_index())

func _on_corp_store_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CorpStore.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_launch"):
		if not _launch_btn.disabled:
			_on_launch_pressed()
	elif event.is_action_pressed("menu_mech_lab"):
		_on_mech_lab_pressed()
	elif event.is_action_pressed("menu_corp_store"):
		if not SaveManager.corp_store_access.is_empty():
			_on_corp_store_pressed()
	elif event.is_action_pressed("menu_back"):
		_on_back_pressed()
