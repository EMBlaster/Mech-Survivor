extends Control

const T1_SLOT_COUNT: int = 5
const T2_SLOT_COUNT: int = 3
const BASE_PRICE_T1: int = 200
const BASE_PRICE_T2: int = 450

var _corp: CorpDef = null
var _inventory: Array[WeaponDef] = []
var _credits_label: Label = null
## Tracks {weapon_key -> buy_btn} so affordability can refresh after each purchase.
var _buy_buttons: Dictionary = {}
var _bought_keys: Array[String] = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_corp = _find_corp(SaveManager.corp_store_access)
	if _corp == null:
		get_tree().change_scene_to_file("res://scenes/ui/MechSelect.tscn")
		return
	_inventory = _build_inventory()
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

func _brand(base: WeaponDef) -> WeaponDef:
	var w: WeaponDef = base.duplicate(false) as WeaponDef
	w.manufacturer = _corp.corp_name
	w.traits = _corp.trait_pool.duplicate()
	return w

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
	title.text = "CORP STORE — %s" % _corp.corp_name
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

	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 4)
	scroll.add_child(item_list)

	for weapon in _inventory:
		item_list.add_child(_build_weapon_row(weapon))
		item_list.add_child(HSeparator.new())

	root.add_child(HSeparator.new())

	var leave_btn := Button.new()
	leave_btn.text = "Leave Store [Esc]"
	leave_btn.pressed.connect(_on_leave_pressed)
	root.add_child(leave_btn)

func _build_weapon_row(weapon: WeaponDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var tier_tag := " [T2]" if weapon.tier == 2 else ""
	var name_lbl := Label.new()
	name_lbl.text = "%s%s  —  %s" % [weapon.weapon_name, tier_tag, _corp.corp_name]
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

# --- Interactions ---

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
