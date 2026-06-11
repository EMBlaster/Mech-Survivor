class_name MechDef extends Resource

## Single equipment pool size (spec MechCommander-style simplification):
## every mech has 12 generic slots. Weight (free_tonnage) is the real
## constraint -- slots just cap absurd stacking.
const SLOT_COUNT: int = 12

## Armor weight (Mech Lab, spec 5.3 / OQ-2 canonical): 1 ton per 16 points.
const ARMOR_WEIGHT_PER_POINT: float = 0.0625

@export var mech_name: String = ""
@export var weight_class: String = ""        # "Light" / "Medium" / "Heavy" / "Assault"
@export var max_speed: float = 80.0
## Total HP at default armor (structure + default armor). Displayed on the
## Mech Select screen.
@export var max_armor: float = 100.0
## Fixed base HP -- cannot be raised or lowered in the Mech Lab. Combat HP is
## always structure + current armor.
@export var structure: float = 50.0
@export var heat_capacity: float = 30.0      # cosmetic bar only in PoC
@export var starting_weapons: Array[WeaponDef] = []
@export var unlock_cost: int = 0             # 0 = starter (Jenner)
@export var sprite: Texture2D

@export_group("Loadout")
## Hard weight budget for this mech after engine, structure, and default
## armor. Everything placed in the Mech Lab (weapons, equipment, ammo bins)
## draws from this pool. Armor adjustments away from the default also draw
## from (or return to) this pool.
@export var free_tonnage: float = 10.0

## Default armor allocation (max_armor - structure), restored by "DEFAULT
## LOADOUT" and used as the baseline for weight-budget comparisons.
func get_default_armor() -> float:
	return max_armor - structure
