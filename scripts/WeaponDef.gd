class_name WeaponDef extends Resource

@export var weapon_name: String = ""
@export var weapon_type: String = ""         # "autocannon" / "laser" / "missile"
@export var manufacturer: String = "Standard"
@export var tier: int = 1                    # 1-5
@export var damage: float = 10.0
@export var range: float = 300.0
@export var cooldown: float = 2.0
@export var projectile_speed: float = 400.0
@export var aoe_radius: float = 0.0          # 0 = no AoE
@export var projectile_scene: PackedScene
@export var icon: Texture2D
