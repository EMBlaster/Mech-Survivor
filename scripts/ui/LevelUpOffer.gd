extends CanvasLayer

const WEAPON_DIR := "res://resources/weapons/"

var current_offers: Array[WeaponDef] = []
var card_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	card_buttons = [$CenterContainer/HBoxContainer/Card1, $CenterContainer/HBoxContainer/Card2, $CenterContainer/HBoxContainer/Card3]
	GameState.level_up.connect(_on_level_up)
	for i in card_buttons.size():
		card_buttons[i].pressed.connect(_on_card_pressed.bind(i))

func _on_level_up(_new_level: int) -> void:
	_build_offers()
	visible = true

func _build_offers() -> void:
	var all_weapons := _load_all_weapons()
	var max_tier: int = GameState.current_level + 1
	var pool: Array[WeaponDef] = []
	for w in all_weapons:
		if w.tier < 1 or w.tier > max_tier:
			continue
		var owned := _find_owned(w)
		var weight: int = 3 if owned == null else 1
		for _i in weight:
			pool.append(w)

	current_offers.clear()
	for _i in 3:
		if pool.is_empty():
			break
		var idx := randi() % pool.size()
		var picked: WeaponDef = pool[idx]
		current_offers.append(picked)
		pool = pool.filter(func(w): return w != picked)

	_update_cards()

func _find_owned(weapon: WeaponDef) -> WeaponDef:
	for w in GameState.active_weapons:
		if w.weapon_name == weapon.weapon_name and w.manufacturer == weapon.manufacturer:
			return w
	return null

func _load_all_weapons() -> Array[WeaponDef]:
	var result: Array[WeaponDef] = []
	var dir := DirAccess.open(WEAPON_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var res := load(WEAPON_DIR + file_name)
				if res is WeaponDef:
					result.append(res)
			file_name = dir.get_next()
	return result

func _update_cards() -> void:
	for i in card_buttons.size():
		if i < current_offers.size():
			var w := current_offers[i]
			var label := "%s\n%s - Tier %d\nDamage: %.0f  Cooldown: %.1fs" % [w.weapon_name, w.weapon_type.capitalize(), w.tier, w.damage, w.cooldown]
			var owned := _find_owned(w)
			if owned != null and owned.tier < w.tier:
				label = "Upgrade to Tier %d\n%s" % [w.tier, label]
			card_buttons[i].text = label
			card_buttons[i].visible = true
		else:
			card_buttons[i].visible = false

func _on_card_pressed(index: int) -> void:
	var chosen := current_offers[index]
	GameState.add_weapon(chosen)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.rebuild_weapons()
		player.get_parent().get_node("HUD").rebuild_weapon_icons()
	visible = false
	get_tree().paused = false
