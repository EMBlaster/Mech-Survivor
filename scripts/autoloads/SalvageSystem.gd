extends Node

## Replaces the old LevelUpOffer weapon-choice cards (spec 7.1).
## Standard salvage rolls on XP-threshold level-ups; exceptional salvage
## rolls on boss death. Both write rewards directly into SaveManager's
## owned_* inventories so they show up back in the Mech Lab.

const STANDARD_CREDITS_RANGE := Vector2i(50, 150)
const EXCEPTIONAL_CREDITS_RANGE := Vector2i(200, 500)
const STANDARD_MAX_TIER := 2
const MECH_UNLOCK_CHANCE := 0.15

## Standard salvage: a single small reward, granted immediately. Returns a
## short description for the in-run drop notification.
func roll_standard_salvage() -> String:
	var roll := randf()
	if roll < 0.35:
		return _grant_credits(STANDARD_CREDITS_RANGE)
	elif roll < 0.55:
		var bin: AmmoBin = ItemDatabase.get_ammo_bin("ballistic_bin") if randf() < 0.5 else ItemDatabase.get_ammo_bin("missile_bin")
		if bin == null:
			return _grant_credits(STANDARD_CREDITS_RANGE)
		SaveManager.add_owned_ammo_bin(bin)
		return "Salvage: %s AmmoBin" % bin.ammo_type.capitalize()
	elif roll < 0.7:
		var equip := _random_equipment(1, 1)
		if equip == null:
			return _grant_credits(STANDARD_CREDITS_RANGE)
		SaveManager.add_owned_equipment(equip)
		return "Salvage: %s" % equip.equipment_name
	else:
		var weapon := _random_weapon(1, STANDARD_MAX_TIER)
		if weapon == null:
			return _grant_credits(STANDARD_CREDITS_RANGE)
		SaveManager.add_owned_weapon(weapon)
		return "Salvage: %s (T%d)" % [weapon.weapon_name, weapon.tier]

## Exceptional salvage: a bundle of rewards granted immediately on boss
## death. Returns a multi-line description for the salvage panel.
func roll_exceptional_salvage() -> String:
	var lines: Array[String] = []

	var credits_amount := randi_range(EXCEPTIONAL_CREDITS_RANGE.x, EXCEPTIONAL_CREDITS_RANGE.y)
	SaveManager.add_credits(credits_amount)
	lines.append("%d credits" % credits_amount)

	var max_tier := _max_weapon_tier()
	var min_tier: int = min(max_tier, STANDARD_MAX_TIER + 1)
	var weapon := _random_weapon(min_tier, max_tier)
	if weapon != null:
		SaveManager.add_owned_weapon(weapon)
		lines.append("%s (T%d)" % [weapon.weapon_name, weapon.tier])

	var equip := _random_equipment(2, 99)
	if equip != null:
		SaveManager.add_owned_equipment(equip)
		lines.append(equip.equipment_name)

	if randf() < MECH_UNLOCK_CHANCE:
		var locked_mech := _random_locked_mech()
		if locked_mech != "":
			SaveManager.unlock_mech(locked_mech)
			lines.append("MECH UNLOCKED: %s" % locked_mech)

	return "\n".join(lines)

func _grant_credits(amount_range: Vector2i) -> String:
	var amount := randi_range(amount_range.x, amount_range.y)
	SaveManager.add_credits(amount)
	return "Salvage: %d credits" % amount

func _random_weapon(min_tier: int, max_tier: int) -> WeaponDef:
	var pool: Array = []
	for w in ItemDatabase.get_all_weapons():
		if w.tier >= min_tier and w.tier <= max_tier:
			pool.append(w)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _random_equipment(min_tier: int, max_tier: int) -> EquipmentDef:
	var pool: Array = []
	for e in ItemDatabase.get_all_equipment():
		if e.tier >= min_tier and e.tier <= max_tier:
			pool.append(e)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _max_weapon_tier() -> int:
	var max_tier := 1
	for w in ItemDatabase.get_all_weapons():
		max_tier = max(max_tier, w.tier)
	return max_tier

func _random_locked_mech() -> String:
	var locked: Array[String] = []
	for mech in ItemDatabase.get_all_mechs():
		if not SaveManager.is_unlocked(mech.mech_name):
			locked.append(mech.mech_name)
	if locked.is_empty():
		return ""
	return locked[randi() % locked.size()]
