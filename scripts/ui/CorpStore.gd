extends Control

const T1_SLOT_COUNT: int = 5
const T2_SLOT_COUNT: int = 3
const BASE_PRICE_T1: int = 200
const BASE_PRICE_T2: int = 450
const MECH_APPEAR_CHANCE: float = 0.10

const CORP_MECH_POOL: Array[MechDef] = [
	preload("res://resources/mechs/anvil_anv6r.tres"),
	preload("res://resources/mechs/colossus_cls7d.tres"),
]

var _corp: CorpDef = null
var _inventory: Array[WeaponDef] = []
var _mech_stock: Array[MechDef] = []
var _credits_label: Label = null
var _buy_buttons: Dictionary = {}
var _bought_keys: Array[String] = []
var _content_list: VBoxContainer = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_corp = _find_corp(SaveManager.corp_store_access)
	if _corp == null:
		get_tree().change_scene_to_file("res://scenes/ui/MechSelect.tscn")
		return
	_inventory = _build_inventory()
	_mech_stock = _pick_mechs()
	_build_ui()

func _find_corp(corp_name: String) -> CorpDef:
	for corp in MissionBoard.CORPS:
		if corp.corp_name == corp_name:
			return corp
	return null

# --- Inventory generation ---

func _build_inventory() -> Array[WeaponDef]:
	var all: Array = ItemDatabase.get_all_weapons()
	var t1: Array[WeaponDef] = []
	var t2: Array[WeaponDef] = []
	for w in all:
		if not w is WeaponDef:
			continue
		if not (w.manufacturer.is_empty() or w.manufacturer == "Standard"):
			continue
		if w.tier == 1:
			t1.append(w)
		elif w.tier == 2:
			t2.append(w)
	t1.shuffle()
	t2.shuffle()
	var result: Array[WeaponDef] = []
	for i in mini(T1_SLOT_COUNT, t1.size()):
		result.append(_brand(t1[i]))
	if SaveManager.t2_store_unlocked(_corp.corp_name):
		for i in mini(T2_SLOT_COUNT, t2.size()):
			result.append(_brand(t2[i]))
	return result

func _pick_mechs() -> Array[MechDef]:
	var result: Array[MechDef] = []
	for mech in CORP_MECH_POOL:
		if randf() < MECH_APPEAR_CHANCE:
			result.append(mech)
	return result

func _brand(base: WeaponDef) -> WeaponDef:
	var w: WeaponDef = base.duplicate(false) as WeaponDef
	w.manufacturer = _corp.corp_name
	var pool: Array = _corp.trait_pool.duplicate()
	pool.shuffle()
	var max_traits: int = mini(w.tier, pool.size())
	w.traits = pool.slice(0, randi_range(0, max_traits))
	return w

func _weapon_tooltip(w: WeaponDef) -> String:
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

static func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(1.0, 1.0, 1.0)
		2: return Color(0.3, 0.9, 0.3)
		3: return Color(0.4, 0.6, 1.0)
		4: return Color(0.8, 0.4, 1.0)
		_: return Color(1.0, 0.85, 0.2)

func _weapon_price(weapon: WeaponDef) -> int:
	var base := BASE_PRICE_T1 if weapon.tier == 1 else BASE_PRICE_T2
	return int(float(base) * _corp.price_multiplier)

# --- UI construction ---

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
	title.text = "CORP STORE — %s %s" % [_corp.symbol, _corp.corp_name]
	root.add_child(title)

	var rep_lbl := Label.new()
	var t2_tag := "  [T2 CATALOG UNLOCKED]" if SaveManager.t2_store_unlocked(_corp.corp_name) else ""
	rep_lbl.text = "Reputation: %d  |  %s%s" % [SaveManager.get_rep(_corp.corp_name), _corp.philosophy, t2_tag]
	root.add_child(rep_lbl)

	_credits_label = Label.new()
	_refresh_credits_label()
	root.add_child(_credits_label)

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content_list = VBoxContainer.new()
	_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_list.add_theme_constant_override("separation", 4)
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
	_buy_buttons.clear()

	_add_section_label("FOR SALE  —  WEAPONS")
	for weapon in _inventory:
		_content_list.add_child(_build_weapon_row(weapon))
		_content_list.add_child(HSeparator.new())

	if not _mech_stock.is_empty():
		_add_section_label("FOR SALE  —  MECHS")
		for mech in _mech_stock:
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

func _build_weapon_row(weapon: WeaponDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s %s  —  %s" % [_corp.symbol, weapon.weapon_name, _corp.corp_name]
	name_lbl.add_theme_color_override("font_color", _tier_color(weapon.tier))
	name_lbl.tooltip_text = _weapon_tooltip(weapon)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	info.add_child(name_lbl)

	if not weapon.traits.is_empty():
		var trait_labels: Array[String] = []
		for t in weapon.traits:
			trait_labels.append(TraitResolver.label(t))
		var trait_lbl := Label.new()
		trait_lbl.text = "Traits: %s" % "  |  ".join(trait_labels)
		info.add_child(trait_lbl)

	var eff := TraitResolver.get_effective_stats(weapon)
	var stats_lbl := Label.new()
	stats_lbl.text = "Dmg: %.0f  Range: %.0f  Heat: %.1f  Wt: %.1f" % [
		eff.get("damage", weapon.damage),
		eff.get("fire_range", weapon.fire_range),
		eff.get("heat", weapon.heat),
		eff.get("weight", weapon.weight),
	]
	info.add_child(stats_lbl)

	var price := _weapon_price(weapon)
	var wkey := SaveManager.weapon_key(weapon)

	var price_col := VBoxContainer.new()
	price_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(price_col)

	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % price
	price_col.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(80.0, 0.0)
	buy_btn.disabled = SaveManager.credits < price
	buy_btn.pressed.connect(_on_buy_pressed.bind(weapon, price, wkey, buy_btn))
	price_col.add_child(buy_btn)

	_buy_buttons[wkey] = {"btn": buy_btn, "price": price}
	return row

func _build_buy_mech_row(mech: MechDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s %s  [%s]" % [_corp.symbol, mech.mech_name, mech.weight_class]
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
		buy_btn.pressed.connect(_on_buy_mech.bind(mech))
	right.add_child(buy_btn)
	return row

func _build_sell_weapon_row(w: WeaponDef, qty: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	var sym := ""
	for corp in MissionBoard.CORPS:
		if corp.corp_name == w.manufacturer and not corp.symbol.is_empty():
			sym = corp.symbol + " "
			break
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
	warn_lbl.text = "Equipped weapons sell with the mech — strip in MechLab first"
	info.add_child(warn_lbl)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)

	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % SaveManager.mech_sell_price(mech)
	right.add_child(price_lbl)

	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(80, 0)
	sell_btn.disabled = SaveManager.mech_count() <= 1
	sell_btn.pressed.connect(_on_sell_mech.bind(mech))
	right.add_child(sell_btn)
	return row

# --- Interactions ---

func _on_buy_mech(mech: MechDef) -> void:
	if SaveManager.buy_mech(mech):
		_refresh_credits_label()
		_rebuild_content()

func _on_sell_weapon(w: WeaponDef) -> void:
	SaveManager.sell_weapon(w)
	_refresh_credits_label()
	_rebuild_content()

func _on_sell_mech(mech: MechDef) -> void:
	SaveManager.sell_mech(mech)
	_refresh_credits_label()
	_rebuild_content()

func _on_buy_pressed(weapon: WeaponDef, price: int, wkey: String, buy_btn: Button) -> void:
	if not SaveManager.spend_credits(price):
		return
	_save_branded_weapon(weapon)
	ItemDatabase.weapons_by_key[wkey] = weapon
	SaveManager.add_owned_weapon(weapon)
	_bought_keys.append(wkey)
	buy_btn.text = "Bought"
	buy_btn.disabled = true
	_refresh_credits_label()
	_refresh_buy_buttons()

func _save_branded_weapon(weapon: WeaponDef) -> void:
	var raw_key := SaveManager.weapon_key(weapon)
	var safe_key := raw_key.replace("|", "_").replace(" ", "_").to_lower()
	ResourceSaver.save(weapon, "%s%s.tres" % [ItemDatabase.BRANDED_WEAPON_DIR, safe_key])

func _refresh_credits_label() -> void:
	_credits_label.text = "Credits: %d" % SaveManager.credits

func _refresh_buy_buttons() -> void:
	for wkey in _buy_buttons:
		if wkey in _bought_keys:
			continue
		var entry: Dictionary = _buy_buttons[wkey]
		entry.btn.disabled = SaveManager.credits < entry.price

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		_on_leave_pressed()

func _on_leave_pressed() -> void:
	SaveManager.corp_store_access = ""
	SaveManager.save()
	get_tree().change_scene_to_file("res://scenes/ui/MechSelect.tscn")
