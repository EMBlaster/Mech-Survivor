extends Node

## Indexes all WeaponDef/EquipmentDef/AmmoBin resources by their inventory
## item key (see SaveManager.*_key helpers) so loadouts stored as flat
## string arrays can be resolved back to Resources.

const WEAPON_DIR := "res://resources/weapons/"
const CRAFTED_WEAPON_DIR := "res://resources/weapons/crafted/"
const EQUIPMENT_DIR := "res://resources/equipment/"
const AMMO_DIR := "res://resources/ammo/"
const MECH_DIR := "res://resources/mechs/"

var weapons_by_key: Dictionary = {}
var equipment_by_key: Dictionary = {}
var ammo_bins_by_key: Dictionary = {}
var mechs: Array[MechDef] = []

func _ready() -> void:
	_load_dir(WEAPON_DIR, func(res): weapons_by_key[SaveManager.weapon_key(res)] = res)
	_load_dir(CRAFTED_WEAPON_DIR, func(res): weapons_by_key[SaveManager.weapon_key(res)] = res)
	_load_dir(EQUIPMENT_DIR, func(res): equipment_by_key[SaveManager.equipment_key(res)] = res)
	_load_dir(AMMO_DIR, func(res): ammo_bins_by_key[SaveManager.ammo_bin_key(res)] = res)
	_load_dir(MECH_DIR, func(res): mechs.append(res))

func _load_dir(path: String, callback: Callable) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(path + file_name)
			callback.call(res)
		file_name = dir.get_next()

func get_weapon(key: String) -> WeaponDef:
	return weapons_by_key.get(key)

func get_equipment(key: String) -> EquipmentDef:
	return equipment_by_key.get(key)

func get_ammo_bin(key: String) -> AmmoBin:
	return ammo_bins_by_key.get(key)

func get_item_weight(key: String) -> float:
	if weapons_by_key.has(key):
		return weapons_by_key[key].weight
	if equipment_by_key.has(key):
		return equipment_by_key[key].weight
	if ammo_bins_by_key.has(key):
		return ammo_bins_by_key[key].weight
	return 0.0

func get_all_weapons() -> Array:
	return weapons_by_key.values()

func get_all_equipment() -> Array:
	return equipment_by_key.values()

func get_all_ammo_bins() -> Array:
	return ammo_bins_by_key.values()

func get_all_mechs() -> Array[MechDef]:
	return mechs
