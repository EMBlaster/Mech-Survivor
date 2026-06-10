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

# XP thresholds per level (expandable array)
var xp_thresholds: Array[int] = [100, 250, 450, 700, 1000, 1400, 1900, 2500]

signal level_up(new_level: int)
signal xp_changed(current_xp: int, current_level: int)
signal mission_complete(credits_earned: int)
signal player_died(credits_earned: int)

func reset_run(mech: MechDef) -> void:
	current_mech = mech
	active_weapons = mech.starting_weapons.duplicate()
	current_xp = 0
	current_level = 1
	mission_timer = 0.0
	is_bonus_wave = false
	run_credits = 0

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
