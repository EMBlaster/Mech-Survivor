class_name EquipmentDef extends Resource

@export var equipment_name: String = ""
@export var weight: float = 0.0
@export var slot_cost: int = 1
@export var effect_type: String = ""         # "heat_sink" or "jump_jet"
@export var effect_value: float = 0.0        # e.g. cooldown multiplier for heat sinks
@export var tier: int = 1
@export var icon: Texture2D
