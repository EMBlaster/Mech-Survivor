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

## output_tier -> max traits the player may inherit (tier number = max traits).
## T2 craft can carry 2 traits, T3 can carry 3, etc.
const TIER_BONUS_SLOTS: Dictionary = {2: 2, 3: 3, 4: 4, 5: 5}

## manufacturer -> Array[String] of trait IDs this corp's weapons can carry.
## Populated as corp-branded weapon resources are added to the game.
## Continental Defense has no traits by design -- Standard/generic weapons map here too.
const MANUFACTURER_BONUSES: Dictionary = {
	"Vantage Arms":         ["range_bonus", "velocity_bonus"],
	"Quickfire Industries": ["cooldown_reduction", "weight_reduction", "damage_penalty"],
	"Ironforge Munitions":  ["damage_bonus", "weight_penalty"],
	"Kovacs Arms":          ["damage_bonus", "cooldown_penalty", "weight_penalty"],
	"Helix Energy Systems": ["cooldown_reduction", "range_bonus"],
	"Salvo Systems":        ["damage_bonus", "splash_bonus"],
	"Axiom Dynamics":       ["damage_bonus", "range_bonus", "cooldown_penalty", "damage_penalty"],
	"Crucible Heavy":       ["damage_bonus", "weight_penalty", "range_penalty"],
	"Redline Surplus":      ["weight_reduction", "cooldown_reduction"],
}

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

## De-duplicated trait pool from the source weapons' existing traits arrays.
## Each entry: {trait_id, label, source} where source is the weapon name that
## contributed the trait. This is the Phase 5 replacement for get_bonus_pool.
func combine_weapons(sources: Array[WeaponDef]) -> Array[Dictionary]:
	var seen: Array[String] = []
	var result: Array[Dictionary] = []
	for w in sources:
		for trait_id: String in w.traits:
			if trait_id not in seen:
				seen.append(trait_id)
				result.append({
					"trait_id": trait_id,
					"label": TraitResolver.label(trait_id),
					"source": w.weapon_name,
				})
	return result

## Preview the crafted weapon with chosen traits applied, without consuming
## resources or persisting. Output manufacturer is "" (salvage amalgam).
func preview_upgrade(base: WeaponDef, chosen_traits: Array[String]) -> WeaponDef:
	var output: WeaponDef = get_next_tier_weapon(base).duplicate()
	output.manufacturer = ""
	output.traits = chosen_traits.duplicate()
	for trait_id: String in chosen_traits:
		var mod: Dictionary = TraitResolver.MODIFIERS.get(trait_id, {})
		for stat_key: String in mod:
			match stat_key:
				"damage":           output.damage           *= mod[stat_key]
				"fire_range":       output.fire_range       *= mod[stat_key]
				"heat":             output.heat             *= mod[stat_key]
				"weight":           output.weight           *= mod[stat_key]
				"projectile_speed": output.projectile_speed *= mod[stat_key]
				"aoe_radius":       output.aoe_radius       *= mod[stat_key]
	return output

## Consumes 4x base, produces T(N+1) with chosen_traits inherited, persists it.
## Output manufacturer = "" (field-built amalgam, no corp stamp).
## chosen_traits: Array[String] of trait IDs (up to TIER_BONUS_SLOTS[output_tier]).
func finalize_upgrade(base: WeaponDef, chosen_traits: Array[String]) -> WeaponDef:
	var input_key := SaveManager.weapon_key(base)
	var owned: int = SaveManager.owned_weapons.get(input_key, 0)
	SaveManager.owned_weapons[input_key] = owned - CRAFT_COST
	if SaveManager.owned_weapons[input_key] <= 0:
		SaveManager.owned_weapons.erase(input_key)
	var output := preview_upgrade(base, chosen_traits)
	var output_key := SaveManager.weapon_key(output)
	if not ItemDatabase.weapons_by_key.has(output_key):
		_persist_crafted_weapon(output, output_key)
		ItemDatabase.weapons_by_key[output_key] = output
	SaveManager.add_owned_weapon(output)
	return output

## Legacy: trait options from manufacturer lookup. Kept for reference.
## Use combine_weapons() for new code.
func get_bonus_pool(base: WeaponDef) -> Array:
	var trait_ids: Array = MANUFACTURER_BONUSES.get(base.manufacturer, [])
	var result: Array = []
	for tid: String in trait_ids:
		result.append({"trait_id": tid, "label": TraitResolver.label(tid)})
	return result

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

## Returns a duplicate of `output` with the selected traits applied.
## Each bonus dict must have a "trait_id" key (from get_bonus_pool).
## Writes trait IDs to result.traits AND bakes the stat multipliers in so
## the preview and final item display accurate stats.
func apply_bonuses(output: WeaponDef, bonuses: Array) -> WeaponDef:
	var result: WeaponDef = output.duplicate()
	result.traits = []
	for bonus: Dictionary in bonuses:
		var trait_id: String = bonus.get("trait_id", "")
		if trait_id.is_empty():
			continue
		result.traits.append(trait_id)
		var mod: Dictionary = TraitResolver.MODIFIERS.get(trait_id, {})
		for stat_key: String in mod:
			match stat_key:
				"damage":           result.damage           *= mod[stat_key]
				"fire_range":       result.fire_range       *= mod[stat_key]
				"heat":             result.heat             *= mod[stat_key]
				"weight":           result.weight           *= mod[stat_key]
				"projectile_speed": result.projectile_speed *= mod[stat_key]
				"aoe_radius":       result.aoe_radius       *= mod[stat_key]
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
