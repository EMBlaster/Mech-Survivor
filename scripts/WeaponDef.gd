class_name WeaponDef extends Resource

## Cooldown is derived from heat via HEAT_COOLDOWN_MULTIPLIER -- see get_cooldown().
## Tune weapon pacing globally by adjusting this one constant.
const HEAT_COOLDOWN_MULTIPLIER: float = 0.4

@export var weapon_name: String = ""
@export var weapon_type: String = ""         # "autocannon" / "laser" / "missile"
@export var manufacturer: String = "Standard"
@export var tier: int = 1                    # 1-5
@export var traits: Array[String] = []       # trait IDs applied at read time via TraitResolver
@export var damage: float = 10.0
@export var fire_range: float = 300.0
@export var heat: float = 1.0                # drives cooldown via HEAT_COOLDOWN_MULTIPLIER
@export var projectile_speed: float = 400.0
@export var aoe_radius: float = 0.0          # 0 = no AoE
@export var projectile_scene: PackedScene
@export var icon: Texture2D

@export_group("Loadout")
@export var weight: float = 0.0              # hard constraint, drawn from MechDef.free_tonnage
@export var slot_cost: int = 1               # cosmetic -- grid cells occupied in Mech Lab UI
@export var slot_cost_modifier: int = 0      # cosmetic -- e.g. -1 from a "compact" upgrade
@export var ammo_type: String = ""           # "ballistic", "missile", or "" (energy)
@export var ammo_per_shot: int = 1           # shots consumed from runtime pool per firing

func get_cooldown() -> float:
	return heat * HEAT_COOLDOWN_MULTIPLIER

func get_effective_slot_cost() -> int:
	return max(1, slot_cost + slot_cost_modifier)
