class_name EnemyDef extends Resource

@export var enemy_name: String = ""
@export var archetype: String = ""           # "scout" / "brawler" / "artillery" / "boss"
@export var base_armor: float = 50.0
@export var base_speed: float = 60.0
@export var base_weapons: Array[WeaponDef] = []
@export var xp_value: int = 10
@export var credits_value: int = 0           # small bonus credits on kill
@export var sprite: Texture2D
