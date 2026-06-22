class_name CorpDef extends Resource

@export var corp_name: String = ""
@export var symbol: String = ""             # single Unicode glyph shown next to corp name
@export var philosophy: String = ""         # one-liner shown in UI
@export var trait_pool: Array[String] = []  # trait IDs this corp expresses on its weapons
@export var availability: float = 1.0       # base draw weight on the mission board
@export var price_multiplier: float = 1.0   # relative cost in corp store
@export var color: Color = Color.WHITE      # logo tint in UI
