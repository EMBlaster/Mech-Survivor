extends Control

## Mech Lab (spec section 5, MechCommander-style simplification): a single
## 12-slot equipment pool plus one armor scalar per mech. Weight
## (free_tonnage) is the only hard constraint. Built entirely in code;
## MechLab.tscn only provides the top-level layout containers.

const FILTERS: Array[String] = ["ALL", "Ballistic", "Energy", "Missile", "Equipment", "Ammo Bins"]

## Armor is adjusted in 1-ton steps (16 armor points per ton).
const ARMOR_STEP: float = 16.0

## Small tolerance for comparing fractional weight values against
## free_tonnage so "at budget" checks aren't defeated by float rounding.
const WEIGHT_EPSILON: float = 0.001

var current_mech: MechDef = null
var working_loadout: Dictionary = {}
var placement_item_key: String = ""
var inventory_filter: String = "ALL"
var valid_only: bool = false

var unlocked_mechs: Array[MechDef] = []
var mech_tab_buttons: Array[Button] = []
var filter_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var armor_label: Label = null

# Crafting sub-panel state
var crafting_group: Dictionary = {}      # {"weapon": WeaponDef, "qty": int}
var crafting_bonuses: Array[String] = [] # selected trait IDs from CraftingSystem.combine_weapons()
var crafting_group_buttons: Array[Button] = []
var crafting_bonus_checks: Array[CheckBox] = []

func _ready() -> void:
	_build_left_panel()
	_build_right_panel()
	_build_bottom_bar()
	_build_mech_tabs()
	_build_filter_tabs()
	_build_crafting_overlay()

	var start_mech: MechDef = GameState.current_mech
	if start_mech == null or not SaveManager.is_unlocked(start_mech.mech_name):
		start_mech = unlocked_mechs[0] if not unlocked_mechs.is_empty() else null
	if start_mech != null:
		_select_mech(start_mech)

## --- Static layout ---

func _build_left_panel() -> void:
	var left := $MainVBox/ContentHBox/LeftPanel
	left.add_theme_constant_override("separation", 6)

	var mech_tabs := HBoxContainer.new()
	mech_tabs.name = "MechTabs"
	left.add_child(mech_tabs)

	var stats_box := VBoxContainer.new()
	stats_box.name = "StatsBox"
	left.add_child(stats_box)
	for label_name in ["WeightLabel", "AlphaLabel", "HeatLabel", "ArmorLabel", "AmmoLabel"]:
		var lbl := Label.new()
		lbl.name = label_name
		stats_box.add_child(lbl)

	var placement_label := Label.new()
	placement_label.name = "PlacementLabel"
	placement_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(placement_label)

	var filter_tabs := HBoxContainer.new()
	filter_tabs.name = "FilterTabs"
	left.add_child(filter_tabs)

	var valid_only_check := CheckBox.new()
	valid_only_check.name = "ValidOnlyCheck"
	valid_only_check.text = "VALID ONLY"
	valid_only_check.toggled.connect(_on_valid_only_toggled)
	left.add_child(valid_only_check)

	var inv_scroll := ScrollContainer.new()
	inv_scroll.name = "InventoryScroll"
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(inv_scroll)

	var inv_list := VBoxContainer.new()
	inv_list.name = "InventoryList"
	inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.add_child(inv_list)

func _build_right_panel() -> void:
	var right := $MainVBox/ContentHBox/RightPanel
	right.add_theme_constant_override("separation", 6)

	var weight_bar := ProgressBar.new()
	weight_bar.name = "WeightBar"
	weight_bar.show_percentage = false
	weight_bar.custom_minimum_size = Vector2(0, 18)
	right.add_child(weight_bar)

	var armor_row := HBoxContainer.new()
	armor_row.name = "ArmorRow"
	armor_row.add_theme_constant_override("separation", 6)
	right.add_child(armor_row)

	var armor_minus := Button.new()
	armor_minus.text = "-"
	armor_minus.pressed.connect(_on_armor_minus)
	armor_row.add_child(armor_minus)

	armor_label = Label.new()
	armor_label.name = "ArmorLabel"
	armor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armor_label.clip_text = true
	armor_row.add_child(armor_label)

	var armor_plus := Button.new()
	armor_plus.text = "+"
	armor_plus.pressed.connect(_on_armor_plus)
	armor_row.add_child(armor_plus)

	var slots_panel := PanelContainer.new()
	slots_panel.name = "SlotsPanel"
	slots_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(slots_panel)

	var slots_grid := GridContainer.new()
	slots_grid.name = "SlotsGrid"
	slots_grid.columns = 3
	slots_grid.add_theme_constant_override("h_separation", 6)
	slots_grid.add_theme_constant_override("v_separation", 6)
	slots_panel.add_child(slots_grid)

func _build_bottom_bar() -> void:
	var bar := $MainVBox/BottomBar
	bar.add_theme_constant_override("separation", 6)

	var save_btn := Button.new()
	save_btn.name = "SaveButton"
	save_btn.text = "SAVE [S]"
	save_btn.pressed.connect(_on_save_pressed)
	bar.add_child(save_btn)

	var revert_btn := Button.new()
	revert_btn.text = "LOAD [L]"
	revert_btn.pressed.connect(_on_revert_pressed)
	bar.add_child(revert_btn)

	var default_btn := Button.new()
	default_btn.text = "DEFAULT [D]"
	default_btn.pressed.connect(_on_default_pressed)
	bar.add_child(default_btn)

	var strip_mech_btn := Button.new()
	strip_mech_btn.text = "STRIP [X]"
	strip_mech_btn.pressed.connect(_on_strip_mech_pressed)
	bar.add_child(strip_mech_btn)

	var max_armor_btn := Button.new()
	max_armor_btn.text = "MAX ARMOR [A]"
	max_armor_btn.pressed.connect(_on_max_armor_pressed)
	bar.add_child(max_armor_btn)

	var strip_armor_btn := Button.new()
	strip_armor_btn.text = "STRIP ARMOR [Z]"
	strip_armor_btn.pressed.connect(_on_strip_armor_pressed)
	bar.add_child(strip_armor_btn)

	var crafting_btn := Button.new()
	crafting_btn.text = "CRAFTING [C]"
	crafting_btn.pressed.connect(_on_crafting_button_pressed)
	bar.add_child(crafting_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "BACK [Esc]"
	back_btn.pressed.connect(_on_back_pressed)
	bar.add_child(back_btn)

func _build_mech_tabs() -> void:
	var mech_tabs := $MainVBox/ContentHBox/LeftPanel/MechTabs
	for m in ItemDatabase.get_all_mechs():
		if not SaveManager.is_unlocked(m.mech_name):
			continue
		unlocked_mechs.append(m)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = "%s\n%s  %.0ft budget" % [m.mech_name, m.weight_class, m.free_tonnage]
		btn.pressed.connect(_on_mech_tab_pressed.bind(m))
		mech_tabs.add_child(btn)
		mech_tab_buttons.append(btn)

func _build_filter_tabs() -> void:
	var filter_tabs := $MainVBox/ContentHBox/LeftPanel/FilterTabs
	for f in FILTERS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = f
		btn.button_pressed = (f == "ALL")
		btn.pressed.connect(_on_filter_pressed.bind(f))
		filter_tabs.add_child(btn)
		filter_buttons.append(btn)

## --- Mech selection ---

func _on_mech_tab_pressed(mech: MechDef) -> void:
	_select_mech(mech)

func _select_mech(mech: MechDef) -> void:
	current_mech = mech
	GameState.current_mech = mech
	for i in unlocked_mechs.size():
		mech_tab_buttons[i].button_pressed = (unlocked_mechs[i] == mech)

	working_loadout = SaveManager.get_loadout(mech).duplicate(true)
	_ensure_items(working_loadout, mech)

	placement_item_key = ""
	_update_placement_label()
	_build_slot_grid()
	_refresh_all()

func _ensure_items(loadout: Dictionary, mech: MechDef) -> void:
	var items: Array = loadout.get("items", [])
	while items.size() < MechDef.SLOT_COUNT:
		items.append("")
	if items.size() > MechDef.SLOT_COUNT:
		items = items.slice(0, MechDef.SLOT_COUNT)
	loadout["items"] = items
	if not loadout.has("armor"):
		loadout["armor"] = mech.get_default_armor()

## --- Equipment slots ---

func _build_slot_grid() -> void:
	var grid := $MainVBox/ContentHBox/RightPanel/SlotsPanel/SlotsGrid
	for c in grid.get_children():
		c.queue_free()
	slot_buttons.clear()

	for i in MechDef.SLOT_COUNT:
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(76, 32)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.clip_text = true
		slot_btn.gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(slot_btn)
		slot_buttons.append(slot_btn)

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var items: Array = working_loadout["items"]
	var item_key: String = items[idx]

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if item_key != "":
			items[idx] = ""
			_refresh_all()
		else:
			placement_item_key = ""
			_update_placement_label()
			_rebuild_inventory()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if item_key != "":
		items[idx] = ""
		_refresh_all()
		return

	if placement_item_key == "":
		return
	if _owned_qty(placement_item_key) - _placed_count(placement_item_key) <= 0:
		return

	items[idx] = placement_item_key
	placement_item_key = ""
	_update_placement_label()
	_refresh_all()

func _update_slots() -> void:
	var items: Array = working_loadout["items"]
	for i in slot_buttons.size():
		var btn: Button = slot_buttons[i]
		var item_key: String = items[i]
		if item_key == "":
			btn.text = ""
			btn.modulate = Color(1, 1, 1, 0.4)
			btn.tooltip_text = ""
			btn.remove_theme_color_override("font_color")
		else:
			btn.text = _slot_display_text(item_key)
			btn.modulate = Color(1, 1, 1, 1)
			btn.tooltip_text = _weapon_trait_tooltip(ItemDatabase.get_weapon(item_key))
			var slot_tier := _slot_item_tier(item_key)
			if slot_tier > 0:
				btn.add_theme_color_override("font_color", _tier_color(slot_tier))

func _slot_display_text(key: String) -> String:
	var w := ItemDatabase.get_weapon(key)
	if w != null:
		var suffix := ""
		if w.ammo_type == "ballistic":
			suffix = " [B]"
		elif w.ammo_type == "missile":
			suffix = " [M]"
		return "%s%s%s" % [_corp_symbol(w.manufacturer), w.weapon_name, suffix]
	var e := ItemDatabase.get_equipment(key)
	if e != null:
		return e.equipment_name
	var bin := ItemDatabase.get_ammo_bin(key)
	if bin != null:
		return "%s Bin" % bin.ammo_type.capitalize()
	return key

func _slot_item_tier(key: String) -> int:
	var w := ItemDatabase.get_weapon(key)
	if w != null:
		return w.tier
	var e := ItemDatabase.get_equipment(key)
	if e != null:
		return e.tier
	return 0

## --- Inventory ---

func _on_filter_pressed(f: String) -> void:
	inventory_filter = f
	for i in FILTERS.size():
		filter_buttons[i].button_pressed = (FILTERS[i] == f)
	_rebuild_inventory()

func _on_valid_only_toggled(pressed: bool) -> void:
	valid_only = pressed
	_rebuild_inventory()

func _weapon_category(weapon_type: String) -> String:
	match weapon_type:
		"autocannon":
			return "Ballistic"
		"laser":
			return "Energy"
		"missile":
			return "Missile"
		_:
			return "Energy"

func _rebuild_inventory() -> void:
	var list := $MainVBox/ContentHBox/LeftPanel/InventoryScroll/InventoryList
	for c in list.get_children():
		c.queue_free()

	var current_weight := _compute_total_weight()
	var empty_slots := _count_empty_slots()

	if inventory_filter in ["ALL", "Ballistic", "Energy", "Missile"]:
		for w in ItemDatabase.get_all_weapons():
			if inventory_filter != "ALL" and _weapon_category(w.weapon_type) != inventory_filter:
				continue
			var key := SaveManager.weapon_key(w)
			var owned: int = SaveManager.owned_weapons.get(key, 0)
			if owned <= 0:
				continue
			var available: int = owned - _placed_count(key)
			if valid_only and (available <= 0 or current_weight + w.weight > current_mech.free_tonnage or empty_slots <= 0):
				continue
			var eff := TraitResolver.get_effective_stats(w)
			var trait_tag := _weapon_trait_summary(w)
			var label := "x%d  %s%s  [%.1ft]  DMG %.0f  RNG %.0f%s" % [
				available, _corp_symbol(w.manufacturer), w.weapon_name,
				eff.get("weight", w.weight),
				eff.get("damage", w.damage),
				eff.get("fire_range", w.fire_range),
				trait_tag]
			_add_inventory_row(key, label, available > 0, _weapon_trait_tooltip(w), w.tier)

	if inventory_filter in ["ALL", "Equipment"]:
		for e in ItemDatabase.get_all_equipment():
			var key := SaveManager.equipment_key(e)
			var owned: int = SaveManager.owned_equipment.get(key, 0)
			if owned <= 0:
				continue
			var available: int = owned - _placed_count(key)
			if valid_only and (available <= 0 or current_weight + e.weight > current_mech.free_tonnage or empty_slots <= 0):
				continue
			var label := "x%d  %s  [%.1ft]" % [available, e.equipment_name, e.weight]
			_add_inventory_row(key, label, available > 0, "", e.tier)

	if inventory_filter in ["ALL", "Ammo Bins"]:
		for bin in ItemDatabase.get_all_ammo_bins():
			var key := SaveManager.ammo_bin_key(bin)
			var owned: int = SaveManager.owned_ammo_bins.get(key, 0)
			if owned <= 0:
				continue
			var available: int = owned - _placed_count(key)
			if valid_only and (available <= 0 or current_weight + bin.weight > current_mech.free_tonnage or empty_slots <= 0):
				continue
			var label := "x%d  %s AmmoBin  [%.1ft]  +%d ammo" % \
				[available, bin.ammo_type.capitalize(), bin.weight, bin.ammo_provided]
			_add_inventory_row(key, label, available > 0)

func _add_inventory_row(key: String, label: String, can_place: bool, tooltip: String = "", tier: int = 0) -> void:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_pressed = (placement_item_key == key)
	btn.disabled = not can_place and placement_item_key != key
	btn.tooltip_text = tooltip
	if tier > 0:
		btn.add_theme_color_override("font_color", _tier_color(tier))
	btn.pressed.connect(_on_inventory_item_pressed.bind(key))
	$MainVBox/ContentHBox/LeftPanel/InventoryScroll/InventoryList.add_child(btn)

func _on_inventory_item_pressed(key: String) -> void:
	if placement_item_key == key:
		placement_item_key = ""
	else:
		placement_item_key = key
	_update_placement_label()
	_rebuild_inventory()

func _update_placement_label() -> void:
	var label := $MainVBox/ContentHBox/LeftPanel/PlacementLabel
	if placement_item_key == "":
		label.text = ""
	else:
		label.text = "Placing: %s -- click an empty slot (right-click a slot to cancel)" % _item_display_name(placement_item_key)

func _item_display_name(key: String) -> String:
	var w := ItemDatabase.get_weapon(key)
	if w != null:
		return "%s (T%d)" % [w.weapon_name, w.tier]
	var e := ItemDatabase.get_equipment(key)
	if e != null:
		return "%s (T%d)" % [e.equipment_name, e.tier]
	var bin := ItemDatabase.get_ammo_bin(key)
	if bin != null:
		return "%s AmmoBin" % bin.ammo_type.capitalize()
	return key

## --- Inventory / loadout bookkeeping ---

func _placed_count(key: String) -> int:
	var count := 0
	for k in working_loadout["items"]:
		if k == key:
			count += 1
	return count

func _owned_qty(key: String) -> int:
	if SaveManager.owned_weapons.has(key):
		return SaveManager.owned_weapons[key]
	if SaveManager.owned_equipment.has(key):
		return SaveManager.owned_equipment[key]
	if SaveManager.owned_ammo_bins.has(key):
		return SaveManager.owned_ammo_bins[key]
	return 0

func _compute_total_weight() -> float:
	var total := 0.0
	for key in working_loadout["items"]:
		if key != "":
			total += ItemDatabase.get_item_weight(key)
	var armor: float = working_loadout["armor"]
	total += (armor - current_mech.get_default_armor()) * MechDef.ARMOR_WEIGHT_PER_POINT
	return total

func _count_empty_slots() -> int:
	var count := 0
	for key in working_loadout["items"]:
		if key == "":
			count += 1
	return count

func _refresh_all() -> void:
	_rebuild_inventory()
	_update_slots()
	_update_stats()

## --- Stats summary ---

func _update_stats() -> void:
	var item_weight := 0.0
	var alpha := 0.0
	var heat_per_sec := 0.0
	var ballistic_ammo := 0
	var missile_ammo := 0

	for key in working_loadout["items"]:
		if key == "":
			continue
		item_weight += ItemDatabase.get_item_weight(key)
		var w := ItemDatabase.get_weapon(key)
		if w != null:
			alpha += w.damage
			heat_per_sec += w.heat / w.get_cooldown()
			continue
		var bin := ItemDatabase.get_ammo_bin(key)
		if bin != null:
			if bin.ammo_type == "ballistic":
				ballistic_ammo += bin.ammo_provided
			elif bin.ammo_type == "missile":
				missile_ammo += bin.ammo_provided

	var armor: float = working_loadout["armor"]
	var armor_weight := (armor - current_mech.get_default_armor()) * MechDef.ARMOR_WEIGHT_PER_POINT
	_update_armor_label()

	var total_weight := item_weight + armor_weight
	var budget := current_mech.free_tonnage

	var stats := $MainVBox/ContentHBox/LeftPanel/StatsBox
	stats.get_node("WeightLabel").text = "Weight: %.2f / %.2f tons" % [total_weight, budget]
	stats.get_node("AlphaLabel").text = "Alpha Damage: %.0f" % alpha
	stats.get_node("HeatLabel").text = "Heat/s: %.1f" % heat_per_sec
	stats.get_node("ArmorLabel").text = "Armor: %.0f   HP: %.0f (Structure %.0f + Armor)" % [armor, current_mech.structure + armor, current_mech.structure]
	stats.get_node("AmmoLabel").text = "Ballistic Ammo: %d   Missile Ammo: %d" % [ballistic_ammo, missile_ammo]

	var weight_bar: ProgressBar = $MainVBox/ContentHBox/RightPanel/WeightBar
	weight_bar.max_value = budget
	weight_bar.value = min(total_weight, budget)
	var frac: float = total_weight / budget if budget > 0.0 else 0.0
	if total_weight > budget or frac > 0.95:
		weight_bar.modulate = Color(1.0, 0.2, 0.2)
	elif frac > 0.8:
		weight_bar.modulate = Color(1.0, 0.85, 0.2)
	else:
		weight_bar.modulate = Color(0.3, 1.0, 0.4)

	var over_budget := total_weight > budget
	var save_btn: Button = $MainVBox/BottomBar/SaveButton
	save_btn.disabled = over_budget
	save_btn.text = "SAVE [S] (OVER BUDGET)" if over_budget else "SAVE [S]"

func _update_armor_label() -> void:
	var cur: float = working_loadout["armor"]
	armor_label.text = "ARMOR: %.0f (default %.0f)" % [cur, current_mech.get_default_armor()]

## --- Armor controls ---
## Armor is adjusted in 1-ton (16-point) steps. Adding armor draws from the
## same weight budget as equipment; stripping armor below default frees it up.

func _on_armor_minus() -> void:
	var cur: float = working_loadout["armor"]
	if cur <= 0.0:
		return
	working_loadout["armor"] = max(0.0, cur - ARMOR_STEP)
	_refresh_all()

func _on_armor_plus() -> void:
	var cur: float = working_loadout["armor"]
	var added_weight := ARMOR_STEP * MechDef.ARMOR_WEIGHT_PER_POINT
	if _compute_total_weight() + added_weight > current_mech.free_tonnage + WEIGHT_EPSILON:
		return
	working_loadout["armor"] = cur + ARMOR_STEP
	_refresh_all()

## --- Bottom bar ---

func _on_save_pressed() -> void:
	SaveManager.save_loadout(current_mech, working_loadout)

func _on_revert_pressed() -> void:
	working_loadout = SaveManager.get_loadout(current_mech).duplicate(true)
	_ensure_items(working_loadout, current_mech)
	placement_item_key = ""
	_update_placement_label()
	_refresh_all()

func _on_default_pressed() -> void:
	working_loadout = GameState.build_default_loadout(current_mech)
	_ensure_items(working_loadout, current_mech)
	placement_item_key = ""
	_update_placement_label()
	_refresh_all()

func _on_strip_mech_pressed() -> void:
	var items: Array = working_loadout["items"]
	for i in items.size():
		items[i] = ""
	placement_item_key = ""
	_update_placement_label()
	_refresh_all()

func _on_strip_armor_pressed() -> void:
	working_loadout["armor"] = 0.0
	_refresh_all()

## Adds armor in 1-ton steps until the weight budget is exhausted. Computed
## directly (no incremental loop) to avoid float-precision drift.
func _on_max_armor_pressed() -> void:
	var cur: float = working_loadout["armor"]
	var remaining_budget := current_mech.free_tonnage - _compute_total_weight()
	if remaining_budget <= 0.0:
		return
	var extra_tons: float = floor(remaining_budget + WEIGHT_EPSILON)
	working_loadout["armor"] = cur + extra_tons * ARMOR_STEP
	_refresh_all()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MechSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		if $CraftingOverlay.visible:
			_on_crafting_close_pressed()
		else:
			_on_back_pressed()
	elif event.is_action_pressed("menu_crafting"):
		_on_crafting_button_pressed()
	elif event.is_action_pressed("menu_save"):
		_on_save_pressed()
	elif event.is_action_pressed("menu_load"):
		_on_revert_pressed()
	elif event.is_action_pressed("menu_default_loadout"):
		_on_default_pressed()
	elif event.is_action_pressed("menu_strip_mech"):
		_on_strip_mech_pressed()
	elif event.is_action_pressed("menu_max_armor"):
		_on_max_armor_pressed()
	elif event.is_action_pressed("menu_strip_armor"):
		_on_strip_armor_pressed()

## --- Crafting sub-panel (spec 7.2) ---

func _build_crafting_overlay() -> void:
	var overlay := PanelContainer.new()
	overlay.name = "CraftingOverlay"
	overlay.visible = false
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 40
	overlay.offset_top = 40
	overlay.offset_right = -40
	overlay.offset_bottom = -40
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.4, 0.4, 0.45)
	overlay.add_theme_stylebox_override("panel", bg)
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "Vbox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CRAFTING — 4x T[N] → 1x T[N+1]  |  Inherited traits carry forward from source weapons"
	vbox.add_child(title)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)

	var group_scroll := ScrollContainer.new()
	group_scroll.name = "GroupScroll"
	group_scroll.custom_minimum_size = Vector2(280, 0)
	body.add_child(group_scroll)

	var group_list := VBoxContainer.new()
	group_list.name = "GroupList"
	group_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_scroll.add_child(group_list)

	var preview_box := VBoxContainer.new()
	preview_box.name = "PreviewBox"
	preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(preview_box)

	for label_name in ["InputLabel", "OutputLabel", "BonusHeader"]:
		var lbl := Label.new()
		lbl.name = label_name
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		preview_box.add_child(lbl)

	var bonus_list := VBoxContainer.new()
	bonus_list.name = "BonusList"
	preview_box.add_child(bonus_list)

	var buttons_row := HBoxContainer.new()
	buttons_row.name = "ButtonsRow"
	vbox.add_child(buttons_row)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "CONFIRM CRAFT"
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_craft_confirm_pressed)
	buttons_row.add_child(confirm_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(_on_crafting_close_pressed)
	buttons_row.add_child(close_btn)

func _on_crafting_button_pressed() -> void:
	var overlay := $CraftingOverlay
	overlay.visible = not overlay.visible
	if overlay.visible:
		crafting_group = {}
		crafting_bonuses = []
		_rebuild_crafting_groups()
		_update_crafting_preview()

func _on_crafting_close_pressed() -> void:
	$CraftingOverlay.visible = false

func _rebuild_crafting_groups() -> void:
	var list := $CraftingOverlay/Margin/Vbox/Body/GroupScroll/GroupList
	for c in list.get_children():
		c.queue_free()
	crafting_group_buttons.clear()

	var groups := CraftingSystem.get_craftable_groups()
	if groups.is_empty():
		var lbl := Label.new()
		lbl.text = "No craftable stacks (need 4x of the same weapon, tier < 5)."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(lbl)
		return

	for group in groups:
		var w: WeaponDef = group["weapon"]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = "x%d  %s  → T%d" % [group["qty"], w.weapon_name, w.tier + 1]
		btn.button_pressed = (not crafting_group.is_empty() and crafting_group["weapon"] == w)
		btn.add_theme_color_override("font_color", _tier_color(w.tier))
		btn.pressed.connect(_on_crafting_group_pressed.bind(group))
		list.add_child(btn)
		crafting_group_buttons.append(btn)

func _on_crafting_group_pressed(group: Dictionary) -> void:
	crafting_group = group
	crafting_bonuses = []
	_rebuild_crafting_groups()
	_update_crafting_preview()

func _update_crafting_preview() -> void:
	var preview := $CraftingOverlay/Margin/Vbox/Body/PreviewBox
	var input_label: Label = preview.get_node("InputLabel")
	var output_label: Label = preview.get_node("OutputLabel")
	var bonus_header: Label = preview.get_node("BonusHeader")
	var bonus_list: VBoxContainer = preview.get_node("BonusList")
	for c in bonus_list.get_children():
		c.queue_free()
	crafting_bonus_checks.clear()

	var confirm_btn: Button = $CraftingOverlay/Margin/Vbox/ButtonsRow/ConfirmButton

	if crafting_group.is_empty():
		input_label.text = "Select a stack on the left to craft."
		output_label.text = ""
		bonus_header.text = ""
		confirm_btn.disabled = true
		return

	var base: WeaponDef = crafting_group["weapon"]
	input_label.text = "Input: 4x %s T%d  (DMG %.0f, Heat %.1f, RNG %.0f, %.1ft)" % \
		[base.weapon_name, base.tier, base.damage, base.heat, base.fire_range, base.weight]

	var raw_output := CraftingSystem.get_next_tier_weapon(base)
	var output_tier: int = raw_output.tier
	var slot_count := CraftingSystem.get_bonus_slot_count(output_tier)
	var pool := CraftingSystem.combine_weapons([base])

	if pool.is_empty():
		bonus_header.text = "Traits to inherit: none on source weapons (%d slot(s) at T%d)" % [slot_count, output_tier]
	else:
		bonus_header.text = "Inherit traits (choose up to %d from source weapons):" % slot_count
		for entry: Dictionary in pool:
			var trait_id: String = entry.get("trait_id", "")
			var check := CheckBox.new()
			check.text = "%s  [from: %s]" % [entry.get("label", trait_id), entry.get("source", "?")]
			check.button_pressed = trait_id in crafting_bonuses
			check.toggled.connect(_on_trait_toggled.bind(trait_id))
			bonus_list.add_child(check)
			crafting_bonus_checks.append(check)

	var preview_weapon := CraftingSystem.preview_upgrade(base, crafting_bonuses)
	output_label.text = "Output: 1x %s T%d  (DMG %.0f, Heat %.1f, RNG %.0f, %.1ft)" % \
		[preview_weapon.weapon_name, preview_weapon.tier, preview_weapon.damage, preview_weapon.heat, preview_weapon.fire_range, preview_weapon.weight]

	confirm_btn.disabled = false

func _on_trait_toggled(pressed: bool, trait_id: String) -> void:
	var base: WeaponDef = crafting_group["weapon"]
	var raw_output := CraftingSystem.get_next_tier_weapon(base)
	var slot_count := CraftingSystem.get_bonus_slot_count(raw_output.tier)
	if pressed:
		if crafting_bonuses.size() >= slot_count:
			_update_crafting_preview()
			return
		crafting_bonuses.append(trait_id)
	else:
		crafting_bonuses.erase(trait_id)
	_update_crafting_preview()

func _corp_symbol(manufacturer: String) -> String:
	if manufacturer.is_empty() or manufacturer == "Standard":
		return ""
	for corp in MissionBoard.CORPS:
		if corp.corp_name == manufacturer:
			return corp.symbol + " " if not corp.symbol.is_empty() else ""
	return ""

static func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(1.0, 1.0, 1.0)
		2: return Color(0.3, 0.9, 0.3)
		3: return Color(0.4, 0.6, 1.0)
		4: return Color(0.8, 0.4, 1.0)
		_: return Color(1.0, 0.85, 0.2)

## One-line trait summary for inventory rows, e.g. "  [+15% dmg | -10% rng]".
## Returns "" when the weapon has no traits.
func _weapon_trait_summary(w: WeaponDef) -> String:
	if w == null or w.traits.is_empty():
		return ""
	var labels: Array[String] = []
	for t in w.traits:
		labels.append(TraitResolver.label(t))
	return "  [%s]" % " | ".join(labels)

## Multi-line tooltip for any weapon. Shows base stats always; appends
## trait list and effective (post-trait) stats when traits are present.
func _weapon_trait_tooltip(w: WeaponDef) -> String:
	if w == null:
		return ""
	var header := w.weapon_name
	if not w.manufacturer.is_empty() and w.manufacturer != "Standard":
		header += "  —  %s" % w.manufacturer
	var lines: Array[String] = [
		header,
		"%s  ·  %.1ft" % [w.weapon_type.capitalize(), w.weight],
		"DMG %.0f   RNG %.0f   Heat %.1f/s   CD %.2fs" % [
			w.damage, w.fire_range, w.heat, w.get_cooldown()],
	]
	if not w.ammo_type.is_empty():
		lines.append("Uses: %d %s ammo/shot" % [w.ammo_per_shot, w.ammo_type])
	if w.aoe_radius > 0.0:
		lines.append("AoE: %.0f radius" % w.aoe_radius)
	if not w.traits.is_empty():
		var trait_labels: Array[String] = []
		for t in w.traits:
			trait_labels.append(TraitResolver.label(t))
		lines.append("")
		lines.append("Traits:  %s" % "  |  ".join(trait_labels))
		var eff := TraitResolver.get_effective_stats(w)
		lines.append("Effective:  DMG %.0f   RNG %.0f   Heat %.1f/s   Wt %.1ft" % [
			eff.get("damage", w.damage),
			eff.get("fire_range", w.fire_range),
			eff.get("heat", w.heat),
			eff.get("weight", w.weight),
		])
	return "\n".join(lines)

func _on_craft_confirm_pressed() -> void:
	if crafting_group.is_empty():
		return
	var base: WeaponDef = crafting_group["weapon"]
	CraftingSystem.finalize_upgrade(base, crafting_bonuses)
	crafting_group = {}
	crafting_bonuses = []
	_rebuild_crafting_groups()
	_update_crafting_preview()
	_refresh_all()
