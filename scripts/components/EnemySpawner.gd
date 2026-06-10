extends Node2D

signal boss_defeated

const ENEMY_SCENE: PackedScene = preload("res://scenes/game/EnemyMech.tscn")
const SPAWN_RADIUS: float = 800.0
const SCALING_INTERVAL: float = 60.0
const SCALING_FACTOR: float = 1.15
const FILLER_CHECK_INTERVAL: float = 1.0
const FILLER_ARCHETYPES: Array[String] = ["scout", "brawler", "artillery"]

const ARCHETYPE_DEFS := {
	"scout": preload("res://resources/enemies/locust_lct1v.tres"),
	"brawler": preload("res://resources/enemies/centurion_cn9a.tres"),
	"artillery": preload("res://resources/enemies/catapult_cplt_c1_enemy.tres"),
	"boss": preload("res://resources/enemies/atlas_as7d_enemy.tres"),
}

var mission: MissionDef = null
var elapsed_time: float = 0.0
var pending_waves: Array[Dictionary] = []
var filler_check_timer: float = 0.0
var active_bosses: int = 0

func setup(mission_def: MissionDef) -> void:
	mission = mission_def
	elapsed_time = 0.0
	pending_waves = mission.wave_schedule.duplicate()
	filler_check_timer = 0.0
	active_bosses = 0

func _process(delta: float) -> void:
	if mission == null:
		return
	elapsed_time += delta

	# While a boss is alive, hold off on any other spawns.
	if active_bosses > 0:
		return

	var i := 0
	while i < pending_waves.size():
		var wave: Dictionary = pending_waves[i]
		if elapsed_time >= float(wave["time"]):
			_spawn_wave(wave)
			pending_waves.remove_at(i)
			if active_bosses > 0:
				return
		else:
			i += 1

	filler_check_timer += delta
	if filler_check_timer >= FILLER_CHECK_INTERVAL:
		filler_check_timer -= FILLER_CHECK_INTERVAL
		_fill_to_cap()

func _fill_to_cap() -> void:
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= mission.max_alive_enemies:
		return
	var archetype: String = FILLER_ARCHETYPES[randi() % FILLER_ARCHETYPES.size()]
	var def: EnemyDef = ARCHETYPE_DEFS.get(archetype)
	var scaling_steps: float = floor(elapsed_time / SCALING_INTERVAL)
	var diff_mult: float = mission.base_difficulty * pow(SCALING_FACTOR, scaling_steps)
	_spawn_enemy(def, diff_mult)

func _spawn_wave(wave: Dictionary) -> void:
	var archetype: String = wave["archetype"]
	var count: int = wave["count"]
	var tier_mult: float = wave.get("tier_mult", 1.0)
	var def: EnemyDef = ARCHETYPE_DEFS.get(archetype)
	if def == null:
		return
	var scaling_steps: float = floor(elapsed_time / SCALING_INTERVAL)
	var diff_mult: float = mission.base_difficulty * tier_mult * pow(SCALING_FACTOR, scaling_steps)
	for i in count:
		_spawn_enemy(def, diff_mult)

func _spawn_enemy(def: EnemyDef, diff_mult: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var angle := randf() * TAU
	var spawn_pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS
	var enemy := ENEMY_SCENE.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos
	enemy.setup(def, diff_mult)
	if def.archetype == "boss":
		active_bosses += 1
		enemy.defeated.connect(func(_def):
			active_bosses -= 1
			boss_defeated.emit())
