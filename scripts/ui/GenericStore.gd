extends Control

const WEAPON_BUY_PRICE: int = 150

var _credits_label: Label = null
var _roster_label: Label = null
var _content_list: VBoxContainer = null
var _buy_weapon_buttons: Array[Button] = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16.0
	root.offset_top = 16.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "GENERAL STORE"
	root.add_child(title)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 24)
	root.add_child(info_row)

	_credits_label = Label.new()
	info_row.add_child(_credits_label)

	_roster_label = Label.new()
	info_row.add_child(_roster_label)

	_refresh_info_labels()

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content_list = VBoxContainer.new()
	_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_content_list)

	_rebuild_content()

	root.add_child(HSeparator.new())

	var leave_btn := Button.new()
	leave_btn.text = "Leave Store [Esc]"
	leave_btn.pressed.connect(_on_leave_pressed)
	root.add_child(leave_btn)

func _rebuild_content() -> void:
	for c in _content_list.get_children():
		c.queue_free()
	_buy_weapon_buttons.clear()

	_add_section_label("FOR SALE  —  WEAPONS")
	if GeneralStore.available_weapons.is_empty():
		_add_section_label("(no weapons in stock)")
	else:
		for w in GeneralStore.available_weapons:
			_content_list.add_child(_build_buy_weapon_row(w))

	if not GeneralStore.available_mechs.is_empty():
		_content_list.add_child(HSeparator.new())
		_add_section_label("FOR SALE  —  MECHS")
		for mech in GeneralStore.available_mechs:
			_content_list.add_child(_build_buy_mech_row(mech))

	_content_list.add_child(HSeparator.new())
	_add_section_label("SELL INVENTORY")

	var has_items := false
	for key in SaveManager.owned_weapons:
		var qty: int = SaveManager.owned_weapons[key]
		if qty <= 0:
			continue
		var w: WeaponDef = ItemDatabase.weapons_by_key.get(key)
		if w == null:
			continue
		_content_list.add_child(_build_sell_weapon_row(w, qty))
		has_items = true

	for mech in ItemDatabase.ROSTER:
		if not SaveManager.is_unlocked(mech.mech_name):
			continue
		_content_list.add_child(_build_sell_mech_row(mech))
		has_items = true

	if not has_items:
		_add_section_label("(nothing to sell)")

func _add_section_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	_content_list.add_child(lbl)

# --- Buy rows ---

func _build_buy_weapon_row(w: WeaponDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = w.weapon_name
	name_lbl.add_theme_color_override("font_color", _tier_color(w.tier))
	name_lbl.tooltip_text = _weapon_tooltip(w)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	info.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "DMG %.0f  RNG %.0f  Heat %.1f/s  Wt %.1ft" % [
		w.damage, w.fire_range, w.heat, w.weight]
	info.add_child(stats_lbl)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)

	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % WEAPON_BUY_PRICE
	right.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(80, 0)
	buy_btn.disabled = SaveManager.credits < WEAPON_BUY_PRICE
	buy_btn.pressed.connect(_on_buy_weapon.bind(w, buy_btn))
	right.add_child(buy_btn)
	_buy_weapon_buttons.append(buy_btn)

	return row

func _build_buy_mech_row(mech: MechDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s  [%s]" % [mech.mech_name, mech.weight_class]
	info.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "HP: %.0f  Speed: %.0f  Tonnage: %.0ft" % [
		mech.max_armor, mech.max_speed, mech.free_tonnage]
	info.add_child(stats_lbl)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)

	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % mech.store_price
	right.add_child(price_lbl)

	var already_owned := SaveManager.is_unlocked(mech.mech_name)
	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(100, 0)
	if already_owned:
		buy_btn.text = "Owned"
		buy_btn.disabled = true
	else:
		buy_btn.text = "Buy"
		buy_btn.disabled = SaveManager.credits < mech.store_price or not SaveManager.can_buy_mech()
		buy_btn.pressed.connect(_on_buy_mech.bind(mech, buy_btn))
	right.add_child(buy_btn)

	return row

# --- Sell rows ---

func _build_sell_weapon_row(w: WeaponDef, qty: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	var sym := _corp_symbol(w.manufacturer)
	name_lbl.text = "%s%s  x%d" % [sym, w.weapon_name, qty]
	name_lbl.add_theme_color_override("font_color", _tier_color(w.tier))
	info.add_child(name_lbl)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)

	var sell_price := SaveManager.weapon_sell_price(w)
	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % sell_price
	right.add_child(price_lbl)

	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(80, 0)
	sell_btn.pressed.connect(_on_sell_weapon.bind(w))
	right.add_child(sell_btn)

	return row

func _build_sell_mech_row(mech: MechDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s  [%s]" % [mech.mech_name, mech.weight_class]
	info.add_child(name_lbl)

	var warn_lbl := Label.new()
	warn_lbl.text = "Equipped weapons sell with the mech — strip in MechLab to keep them"
	info.add_child(warn_lbl)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)

	var sell_price := SaveManager.mech_sell_price(mech)
	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % sell_price
	right.add_child(price_lbl)

	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(80, 0)
	sell_btn.disabled = SaveManager.mech_count() <= 1
	sell_btn.pressed.connect(_on_sell_mech.bind(mech))
	right.add_child(sell_btn)

	return row

# --- Actions ---

func _on_buy_weapon(w: WeaponDef, buy_btn: Button) -> void:
	if not SaveManager.spend_credits(WEAPON_BUY_PRICE):
		return
	SaveManager.add_owned_weapon(w)
	buy_btn.text = "Bought"
	buy_btn.disabled = true
	_refresh_info_labels()
	for btn in _buy_weapon_buttons:
		if not btn.disabled:
			btn.disabled = SaveManager.credits < WEAPON_BUY_PRICE

func _on_buy_mech(mech: MechDef, _btn: Button) -> void:
	if SaveManager.buy_mech(mech):
		_refresh_info_labels()
		_rebuild_content()

func _on_sell_weapon(w: WeaponDef) -> void:
	SaveManager.sell_weapon(w)
	_refresh_info_labels()
	_rebuild_content()

func _on_sell_mech(mech: MechDef) -> void:
	SaveManager.sell_mech(mech)
	_refresh_info_labels()
	_rebuild_content()

func _refresh_info_labels() -> void:
	_credits_label.text = "Credits: %d" % SaveManager.credits
	_roster_label.text = "Roster: %d / %d" % [SaveManager.mech_count(), SaveManager.MAX_MECHS]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		_on_leave_pressed()

func _on_leave_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MechSelect.tscn")

# --- Helpers ---

static func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(1.0, 1.0, 1.0)
		2: return Color(0.3, 0.9, 0.3)
		3: return Color(0.4, 0.6, 1.0)
		4: return Color(0.8, 0.4, 1.0)
		_: return Color(1.0, 0.85, 0.2)

func _corp_symbol(manufacturer: String) -> String:
	for corp in MissionBoard.CORPS:
		if corp.corp_name == manufacturer and not corp.symbol.is_empty():
			return corp.symbol + " "
	return ""

func _weapon_tooltip(w: WeaponDef) -> String:
	if w == null:
		return ""
	var lines: Array[String] = [
		w.weapon_name,
		"%s  ·  %.1ft" % [w.weapon_type.capitalize(), w.weight],
		"DMG %.0f   RNG %.0f   Heat %.1f/s   CD %.2fs" % [
			w.damage, w.fire_range, w.heat, w.get_cooldown()],
	]
	if not w.ammo_type.is_empty():
		lines.append("Uses: %d %s ammo/shot" % [w.ammo_per_shot, w.ammo_type])
	if w.aoe_radius > 0.0:
		lines.append("AoE: %.0f radius" % w.aoe_radius)
	return "\n".join(lines)
