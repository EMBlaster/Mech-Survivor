extends Node

## Crafting (spec 7.2, sub-panel within the Mech Lab): 4x Tier N of the same
## weapon -> 1x Tier N+1. Tiers beyond the highest WeaponDef resource that
## exists on disk (currently T3) are synthesized by scaling stats, then
## persisted to res://resources/weapons/crafted/ so they survive reload.

const CRAFT_COST: int = 4
const MAX_TIER: int = 5
const SYNTH_DAMAGE_SCALE: float = 1.15
const SYNTH_HEAT_SCALE: float = 0.95
const SYNTH_WEIGHT_ADD: float = 1.0
const CRAFTED_DIR: String = "res://resources/weapons/crafted/"

## output_tier -> number of manufacturer bonus slots selectable
## (T2->1, T3->2, T4->3, T5->4 per spec 7.2)
const TIER_BONUS_SLOTS: Dictionary = {2: 1, 3: 2, 4: 3, 5: 4}

## manufacturer -> Array[{"stat": String, "modifier": float, "label": String}]
## Standard components contribute no bonus options. No manufacturer variants
## exist in the current weapon roster, so this pool is empty until variant
## weapon data is added.
const MANUFACTURER_BONUSES: Dictionary = {}

## Returns one entry per (weapon_name, manufacturer, tier) group with
## qty >= CRAFT_COST and tier < MAX_TIER: {"weapon": WeaponDef, "qty": int}
func get_craftable_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for w in ItemDatabase.get_all_weapons():
		if w.tier >= MAX_TIER:
			continue
		var key := SaveManager.weapon_key(w)
		var owned: int = SaveManager.owned_weapons.get(key, 0)
		if owned >= CRAFT_COST:
			groups.append({"weapon": w, "qty": owned})
	return groups

## Manufacturer bonus options available for this craft, derived from the
## manufacturer of the 4 input components.
func get_bonus_pool(base: WeaponDef) -> Array:
	return MANUFACTURER_BONUSES.get(base.manufacturer, [])

func get_bonus_slot_count(output_tier: int) -> int:
	return TIER_BONUS_SLOTS.get(output_tier, 0)

## The Tier N+1 weapon a craft of `base` produces, before bonuses. Reuses an
## existing WeaponDef resource if one is defined for that tier, otherwise
## synthesizes one by scaling stats.
func get_next_tier_weapon(base: WeaponDef) -> WeaponDef:
	var target_tier := base.tier + 1
	for w in ItemDatabase.get_all_weapons():
		if w.weapon_name == base.weapon_name and w.manufacturer == base.manufacturer and w.tier == target_tier:
			return w
	return _synthesize_tier(base, target_tier)

func _synthesize_tier(base: WeaponDef, target_tier: int) -> WeaponDef:
	var out: WeaponDef = base.duplicate()
	var steps := target_tier - base.tier
	out.tier = target_tier
	out.damage = base.damage * pow(SYNTH_DAMAGE_SCALE, steps)
	out.heat = base.heat * pow(SYNTH_HEAT_SCALE, steps)
	out.weight = base.weight + SYNTH_WEIGHT_ADD * steps
	return out

## Returns a duplicate of `output` with the selected bonuses' stat modifiers
## applied -- used for both the live preview and the final crafted item.
func apply_bonuses(output: WeaponDef, bonuses: Array) -> WeaponDef:
	var result: WeaponDef = output.duplicate()
	for bonus in bonuses:
		match bonus.get("stat", ""):
			"damage":
				result.damage *= bonus["modifier"]
			"heat":
				result.heat *= bonus["modifier"]
			"range":
				result.range *= bonus["modifier"]
			"weight":
				result.weight *= bonus["modifier"]
	return result

## Consumes 4x `base` and adds the crafted Tier N+1 weapon (with selected
## bonuses applied) to owned_weapons. Returns the crafted weapon.
func craft(base: WeaponDef, bonuses: Array) -> WeaponDef:
	var input_key := SaveManager.weapon_key(base)
	var owned: int = SaveManager.owned_weapons.get(input_key, 0)
	SaveManager.owned_weapons[input_key] = owned - CRAFT_COST
	if SaveManager.owned_weapons[input_key] <= 0:
		SaveManager.owned_weapons.erase(input_key)

	var output := apply_bonuses(get_next_tier_weapon(base), bonuses)
	var output_key := SaveManager.weapon_key(output)
	if not ItemDatabase.weapons_by_key.has(output_key):
		_persist_crafted_weapon(output, output_key)
		ItemDatabase.weapons_by_key[output_key] = output

	SaveManager.add_owned_weapon(output)
	return output

func _persist_crafted_weapon(weapon: WeaponDef, key: String) -> void:
	DirAccess.make_dir_recursive_absolute(CRAFTED_DIR)
	var file_name := key.replace("|", "_").replace("/", "-").replace(" ", "_") + ".tres"
	ResourceSaver.save(weapon, CRAFTED_DIR + file_name)
