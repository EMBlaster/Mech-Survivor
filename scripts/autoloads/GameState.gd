extends Node

const WEAPON_SALVAGE_PER_TIER: int = 40

# Run state
var current_mech: MechDef = null
var active_weapons: Array[WeaponDef] = []
var current_xp: int = 0
var current_level: int = 1
var mission_timer: float = 0.0
var is_bonus_wave: bool = false
var current_mission: MissionDef = null
var run_credits: int = 0  # bounty credits earned from kills this run, banked at mission end

# Runtime state derived from the active loadout at reset_run()
var ballistic_ammo: int = 0
var missile_ammo: int = 0
var ballistic_ammo_max: int = 0
var missile_ammo_max: int = 0
var heat_sink_multiplier: float = 1.0
var has_jump_jets: bool = false
## Current armor points (structure is fixed; combat HP = structure + current_armor).
var current_armor: float = 0.0

# XP thresholds per level (expandable array)
var xp_thresholds: Array[int] = [100, 250, 450, 700, 1000, 1400, 1900, 2500]

signal level_up(new_level: int)
signal xp_changed(current_xp: int, current_level: int)
signal mission_complete(credits_earned: int)
signal player_died(credits_earned: int)
## Survival missions only: extracting before the timer expires forfeits rewards.
signal mission_extract_failed

func reset_run(mech: MechDef) -> void:
	current_mech = mech
	current_xp = 0
	current_level = 1
	mission_timer = 0.0
	is_bonus_wave = false
	run_credits = 0

	active_weapons = []
	ballistic_ammo = 0
	missile_ammo = 0
	heat_sink_multiplier = 1.0
	has_jump_jets = false
	is_bonus_wave = false

	var loadout := _resolve_loadout(mech)
	for item_key in loadout.get("items", []):
		_apply_loadout_item(item_key)
	current_armor = float(loadout.get("armor", mech.get_default_armor()))

	if active_weapons.is_empty():
		active_weapons = mech.starting_weapons.duplicate()

	ballistic_ammo_max = ballistic_ammo
	missile_ammo_max = missile_ammo

	SaveManager.set_active_loadout(loadout)

## Returns true if the weapon has enough pooled ammo to fire. Energy weapons
## (ammo_type == "") always have ammo.
func has_ammo(weapon: WeaponDef) -> bool:
	match weapon.ammo_type:
		"ballistic":
			return ballistic_ammo >= weapon.ammo_per_shot
		"missile":
			return missile_ammo >= weapon.ammo_per_shot
		_:
			return true

func consume_ammo(weapon: WeaponDef) -> void:
	match weapon.ammo_type:
		"ballistic":
			ballistic_ammo = max(0, ballistic_ammo - weapon.ammo_per_shot)
		"missile":
			missile_ammo = max(0, missile_ammo - weapon.ammo_per_shot)

## Effective shots remaining for a weapon, given its pool's ammo_per_shot cost.
## Energy weapons return -1 (no ammo indicator).
func get_effective_shots(weapon: WeaponDef) -> int:
	match weapon.ammo_type:
		"ballistic":
			return floori(float(ballistic_ammo) / weapon.ammo_per_shot)
		"missile":
			return floori(float(missile_ammo) / weapon.ammo_per_shot)
		_:
			return -1

## Returns the loadout to apply for this mech: the player's saved loadout if
## it exists and fits within free_tonnage, otherwise a default loadout built
## from the mech's starting_weapons.
func _resolve_loadout(mech: MechDef) -> Dictionary:
	var saved: Dictionary = SaveManager.mech_loadouts.get(mech.mech_name, {})
	if _loadout_has_items(saved) and _loadout_weight(saved, mech) <= mech.free_tonnage:
		return saved
	return build_default_loadout(mech)

func _loadout_has_items(loadout: Dictionary) -> bool:
	for item_key in loadout.get("items", []):
		if item_key != "":
			return true
	return false

func _loadout_weight(loadout: Dictionary, mech: MechDef) -> float:
	var total := 0.0
	for item_key in loadout.get("items", []):
		total += ItemDatabase.get_item_weight(item_key)
	var armor: float = float(loadout.get("armor", mech.get_default_armor()))
	total += (armor - mech.get_default_armor()) * MechDef.ARMOR_WEIGHT_PER_POINT
	return total

func _apply_loadout_item(item_key: String) -> void:
	if item_key == "":
		return
	var weapon := ItemDatabase.get_weapon(item_key)
	if weapon != null:
		active_weapons.append(weapon)
		return
	var equipment := ItemDatabase.get_equipment(item_key)
	if equipment != null:
		match equipment.effect_type:
			"heat_sink":
				heat_sink_multiplier *= equipment.effect_value
			"jump_jet":
				has_jump_jets = true
		return
	var bin := ItemDatabase.get_ammo_bin(item_key)
	if bin != null:
		match bin.ammo_type:
			"ballistic":
				ballistic_ammo += bin.ammo_provided
			"missile":
				missile_ammo += bin.ammo_provided

## Builds a loadout from the mech's starting_weapons, adding one ammo bin per
## ammo-consuming starting weapon so it is immediately functional. Used when
## the player has no saved loadout (or it no longer fits free_tonnage), and
## by the Mech Lab's "Default Loadout" button.
func build_default_loadout(mech: MechDef) -> Dictionary:
	var loadout := SaveManager.build_empty_loadout(mech)
	var items: Array = loadout["items"]

	var items_to_place: Array[String] = []
	for w in mech.starting_weapons:
		items_to_place.append(SaveManager.weapon_key(w))
		if w.ammo_type != "":
			items_to_place.append(SaveManager.ammo_bin_key_for_type(w.ammo_type))

	var idx := 0
	for item_key in items_to_place:
		if idx >= items.size():
			break
		items[idx] = item_key
		idx += 1

	return loadout

func add_xp(amount: int) -> void:
	current_xp += amount
	var threshold_index = current_level - 1
	while threshold_index < xp_thresholds.size() and current_xp >= xp_thresholds[threshold_index]:
		current_level += 1
		threshold_index = current_level - 1
		emit_signal("level_up", current_level)
	xp_changed.emit(current_xp, current_level)

func add_run_credits(amount: int) -> void:
	run_credits += amount

## Weapons picked up or upgraded during a run don't carry over to the next
## mission, so convert anything above the mech's starting loadout into
## one-time salvage credits.
func calculate_weapon_salvage() -> int:
	var salvage := 0
	for w in active_weapons:
		var starting_tier := 0
		for s in current_mech.starting_weapons:
			if s.weapon_name == w.weapon_name and s.manufacturer == w.manufacturer:
				starting_tier = s.tier
				break
		if w.tier > starting_tier:
			salvage += (w.tier - starting_tier) * WEAPON_SALVAGE_PER_TIER
	return salvage

func add_weapon(weapon: WeaponDef) -> void:
	# Check if weapon of same type+manufacturer already exists -> upgrade tier
	for i in active_weapons.size():
		if active_weapons[i].weapon_name == weapon.weapon_name and \
		   active_weapons[i].manufacturer == weapon.manufacturer:
			if weapon.tier > active_weapons[i].tier:
				active_weapons[i] = weapon  # replace with higher-tier version
			return
	active_weapons.append(weapon)
