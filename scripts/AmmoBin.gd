class_name AmmoBin extends Resource

## A physical placeable item in the Mech Lab. The player builds their runtime
## ammo pools by placing these alongside weapons and equipment.
@export var ammo_type: String = ""           # "ballistic" or "missile"
@export var weight: float = 1.0              # always 1.0 ton
@export var slot_cost: int = 1               # always 1
@export var ammo_provided: int = 0           # shots added to runtime pool at mission start
@export var icon: Texture2D
