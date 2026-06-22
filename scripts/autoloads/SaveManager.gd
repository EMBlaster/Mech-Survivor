extends Node

const SAVE_PATH = "user://save.cfg"

var credits: int = 0
var unlocked_mechs: Array[String] = ["Jackal JKL-1A"]  # mech_name strings

## Inventory: item key -> quantity owned.
var owned_weapons: Dictionary = {}      # key: weapon_key(WeaponDef)
var owned_equipment: Dictionary = {}    # key: equipment_key(EquipmentDef)
var owned_ammo_bins: Dictionary = {}    # key: ammo_type + "_bin"

## mech_name -> { "mech_id": mech_name, "items": [item_key, ...] (size SLOT_COUNT), "armor": float }
var mech_loadouts: Dictionary = {}

## The loadout currently applied to GameState.current_mech at reset_run().
## Same shape as a mech_loadouts entry.
var active_loadout: Dictionary = {}

## Corporate reputation: corp_name -> int in [-100, 100]. Starts at 0.
## Breaking relationships is fast, rebuilding is slow or impossible.
var corp_reputation: Dictionary = {}

signal rep_changed(corp: String, new_val: int)

## Corp goes dark (stops appearing on the mission board) at or below this value.
const REP_DARK_THRESHOLD: int = -50
## Corp T2 store unlocks at or above this value.
const REP_T2_STORE_THRESHOLD: int = 40
const REP_CLAMP_MIN: int = -100
const REP_CLAMP_MAX: int = 100

func _ready() -> void:
	load_save()

func save() -> void:
	var config = ConfigFile.new()
	config.set_value("pilot", "credits", credits)
	config.set_value("pilot", "unlocked_mechs", unlocked_mechs)
	config.set_value("inventory", "owned_weapons", owned_weapons)
	config.set_value("inventory", "owned_equipment", owned_equipment)
	config.set_value("inventory", "owned_ammo_bins", owned_ammo_bins)
	config.set_value("loadouts", "mech_loadouts", mech_loadouts)
	config.set_value("loadouts", "active_loadout", active_loadout)
	config.set_value("reputation", "corp_reputation", corp_reputation)
	config.save(SAVE_PATH)

func load_save() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		save()  # first run -- write defaults
		return
	credits = config.get_value("pilot", "credits", 0)
	unlocked_mechs.assign(config.get_value("pilot", "unlocked_mechs", ["Jackal JKL-1A"]))
	owned_weapons = config.get_value("inventory", "owned_weapons", {})
	owned_equipment = config.get_value("inventory", "owned_equipment", {})
	owned_ammo_bins = config.get_value("inventory", "owned_ammo_bins", {})
	mech_loadouts = config.get_value("loadouts", "mech_loadouts", {})
	active_loadout = config.get_value("loadouts", "active_loadout", {})
	corp_reputation = config.get_value("reputation", "corp_reputation", {})
	_discard_old_format_loadouts()

## Old saves stored loadouts as { "locations": {...}, "armor": {...} } (per
## location). The new format is { "items": [...], "armor": float }. Discard
## any entries still in the old shape so callers fall back to defaults.
func _discard_old_format_loadouts() -> void:
	for mech_name in mech_loadouts.keys().duplicate():
		var loadout: Dictionary = mech_loadouts[mech_name]
		var armor = loadout.get("armor")
		if not (loadout.has("items") and (armor is float or armor is int)):
			mech_loadouts.erase(mech_name)
	var active_armor = active_loadout.get("armor")
	if not (active_loadout.has("items") and (active_armor is float or active_armor is int)):
		active_loadout = {}

func add_credits(amount: int) -> void:
	credits += amount
	save()

func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	save()
	return true

func unlock_mech(mech_name: String) -> void:
	if mech_name not in unlocked_mechs:
		unlocked_mechs.append(mech_name)
		save()

func is_unlocked(mech_name: String) -> bool:
	return mech_name in unlocked_mechs

## --- Inventory item key helpers ---
## These keys are used as Dictionary keys in owned_* and as entries in
## mech_loadouts[...].items[...] arrays.

func weapon_key(w: WeaponDef) -> String:
	return "%s|%s|T%d" % [w.weapon_name, w.manufacturer, w.tier]

func equipment_key(e: EquipmentDef) -> String:
	return "%s|T%d" % [e.equipment_name, e.tier]

func ammo_bin_key(bin: AmmoBin) -> String:
	return ammo_bin_key_for_type(bin.ammo_type)

func ammo_bin_key_for_type(ammo_type: String) -> String:
	return ammo_type + "_bin"

## --- Inventory mutation ---

func add_owned_weapon(w: WeaponDef, quantity: int = 1) -> void:
	var key := weapon_key(w)
	owned_weapons[key] = owned_weapons.get(key, 0) + quantity
	save()

func add_owned_equipment(e: EquipmentDef, quantity: int = 1) -> void:
	var key := equipment_key(e)
	owned_equipment[key] = owned_equipment.get(key, 0) + quantity
	save()

func add_owned_ammo_bin(bin: AmmoBin, quantity: int = 1) -> void:
	var key := ammo_bin_key(bin)
	owned_ammo_bins[key] = owned_ammo_bins.get(key, 0) + quantity
	save()

## --- Loadouts ---

## Returns the saved loadout for a mech, or its default loadout (starting
## weapons + ammo) if none has been saved yet.
func get_loadout(mech: MechDef) -> Dictionary:
	if mech_loadouts.has(mech.mech_name):
		return mech_loadouts[mech.mech_name]
	return GameState.build_default_loadout(mech)

func build_empty_loadout(mech: MechDef) -> Dictionary:
	var items: Array = []
	items.resize(MechDef.SLOT_COUNT)
	items.fill("")
	return {"mech_id": mech.mech_name, "items": items, "armor": mech.get_default_armor()}

func save_loadout(mech: MechDef, loadout: Dictionary) -> void:
	mech_loadouts[mech.mech_name] = loadout
	save()

func set_active_loadout(loadout: Dictionary) -> void:
	active_loadout = loadout
	save()

## --- Reputation ---

func get_rep(corp: String) -> int:
	return corp_reputation.get(corp, 0)

## Adjusts reputation for a corp by delta, clamped to [REP_CLAMP_MIN, REP_CLAMP_MAX].
## Persists immediately and emits rep_changed if the value actually changed.
## Typical deltas: +10 (mission success), -20 (mission failure).
func modify_rep(corp: String, delta: int) -> void:
	if corp.is_empty():
		return
	var old_val: int = get_rep(corp)
	var new_val: int = clampi(old_val + delta, REP_CLAMP_MIN, REP_CLAMP_MAX)
	if new_val == old_val:
		return
	corp_reputation[corp] = new_val
	save()
	rep_changed.emit(corp, new_val)

## Returns true when a corp's rep has fallen to or below REP_DARK_THRESHOLD.
## Dark corps are excluded from the mission board draw pool entirely.
func is_corp_dark(corp: String) -> bool:
	return get_rep(corp) <= REP_DARK_THRESHOLD

## Returns true when a corp's rep is high enough to unlock their T2 store.
func t2_store_unlocked(corp: String) -> bool:
	return get_rep(corp) >= REP_T2_STORE_THRESHOLD
