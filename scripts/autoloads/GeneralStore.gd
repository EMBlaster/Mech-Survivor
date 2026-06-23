extends Node

const WEAPON_SLOT_COUNT: int = 8
const MECH_APPEAR_CHANCE: float = 0.10

const LIGHT_MEDIUM_MECHS: Array[String] = [
	"res://resources/mechs/jackal_jkl1a.tres",
	"res://resources/mechs/rampart_rmp4g.tres",
	"res://resources/mechs/ballista_bls_c1.tres",
]

var available_weapons: Array[WeaponDef] = []
var available_mechs: Array[MechDef] = []

func _ready() -> void:
	refresh()

func refresh() -> void:
	available_weapons = _pick_weapons()
	available_mechs = _pick_mechs()

func _pick_weapons() -> Array[WeaponDef]:
	var pool: Array[WeaponDef] = []
	for w in ItemDatabase.get_all_weapons():
		if w is WeaponDef and w.tier == 1 and (w.manufacturer.is_empty() or w.manufacturer == "Standard") and w.traits.is_empty():
			pool.append(w)
	pool.shuffle()
	var result: Array[WeaponDef] = []
	for i in mini(WEAPON_SLOT_COUNT, pool.size()):
		result.append(pool[i])
	return result

func _pick_mechs() -> Array[MechDef]:
	var result: Array[MechDef] = []
	for path in LIGHT_MEDIUM_MECHS:
		if randf() < MECH_APPEAR_CHANCE:
			result.append(load(path) as MechDef)
	return result
