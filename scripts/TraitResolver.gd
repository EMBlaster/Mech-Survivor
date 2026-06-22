class_name TraitResolver extends RefCounted

## Multiplicative modifiers applied to weapon stats per trait ID.
## Stats: damage, fire_range, heat (drives cooldown), weight, projectile_speed, aoe_radius.
## All values are multipliers — 1.12 = +12%, 0.88 = -12%.
const MODIFIERS: Dictionary = {
	"range_bonus":        {"fire_range": 1.12},
	"range_penalty":      {"fire_range": 0.90},
	"damage_bonus":       {"damage": 1.15},
	"damage_penalty":     {"damage": 0.88},
	"cooldown_reduction": {"heat": 0.88},
	"cooldown_penalty":   {"heat": 1.12},
	"weight_reduction":   {"weight": 0.85},
	"weight_penalty":     {"weight": 1.15},
	"velocity_bonus":     {"projectile_speed": 1.15},
	"splash_bonus":       {"aoe_radius": 1.25},
}

## Short human-readable labels for the trait picker and weapon tooltips.
const LABELS: Dictionary = {
	"range_bonus":        "+12% range",
	"range_penalty":      "-10% range",
	"damage_bonus":       "+15% damage",
	"damage_penalty":     "-12% damage",
	"cooldown_reduction": "-12% cooldown",
	"cooldown_penalty":   "+12% cooldown",
	"weight_reduction":   "-15% weight",
	"weight_penalty":     "+15% weight",
	"velocity_bonus":     "+15% velocity",
	"splash_bonus":       "+25% splash radius",
}

## Returns a Dictionary of effective stats with all of weapon_def's traits applied.
## Keys: "damage", "fire_range", "heat", "weight", "projectile_speed", "aoe_radius"
## Call this wherever you need to display or use trait-modified values.
static func get_effective_stats(weapon_def: WeaponDef) -> Dictionary:
	var stats := {
		"damage":           weapon_def.damage,
		"fire_range":       weapon_def.fire_range,
		"heat":             weapon_def.heat,
		"weight":           weapon_def.weight,
		"projectile_speed": weapon_def.projectile_speed,
		"aoe_radius":       weapon_def.aoe_radius,
	}
	for trait_id: String in weapon_def.traits:
		var mod: Dictionary = MODIFIERS.get(trait_id, {})
		for stat_key: String in mod:
			stats[stat_key] = stats[stat_key] * mod[stat_key]
	return stats

## Human-readable label for a trait ID. Safe to call with unknown IDs.
static func label(trait_id: String) -> String:
	return LABELS.get(trait_id, trait_id)
