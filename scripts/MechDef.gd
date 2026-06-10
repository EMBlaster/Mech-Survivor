class_name MechDef extends Resource

@export var mech_name: String = ""
@export var weight_class: String = ""        # "Light" / "Medium" / "Heavy" / "Assault"
@export var max_speed: float = 80.0
@export var max_armor: float = 100.0
@export var heat_capacity: float = 30.0      # cosmetic bar only in PoC
@export var starting_weapons: Array[WeaponDef] = []
@export var unlock_cost: int = 0             # 0 = starter (Jenner)
@export var sprite: Texture2D
