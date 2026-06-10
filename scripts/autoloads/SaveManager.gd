extends Node

const SAVE_PATH = "user://save.cfg"

var credits: int = 0
var unlocked_mechs: Array[String] = ["Jenner JR7-D"]  # mech_name strings

func _ready() -> void:
	load_save()

func save() -> void:
	var config = ConfigFile.new()
	config.set_value("pilot", "credits", credits)
	config.set_value("pilot", "unlocked_mechs", unlocked_mechs)
	config.save(SAVE_PATH)

func load_save() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		save()  # first run -- write defaults
		return
	credits = config.get_value("pilot", "credits", 0)
	unlocked_mechs = config.get_value("pilot", "unlocked_mechs", ["Jenner JR7-D"])

func add_credits(amount: int) -> void:
	credits += amount
	save()

func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	save()
	return true

func unlock_mech(mech_name: String) -> void:
	if mech_name not in unlocked_mechs:
		unlocked_mechs.append(mech_name)
		save()

func is_unlocked(mech_name: String) -> bool:
	return mech_name in unlocked_mechs
