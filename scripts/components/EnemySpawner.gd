extends Node2D

signal boss_defeated
signal bonus_wave_started(reward: int)
signal bonus_wave_cleared(reward: int)

const ENEMY_SCENE: PackedScene = preload("res://scenes/game/EnemyMech.tscn")
const SPAWN_RADIUS: float = 800.0
const SCALING_INTERVAL: float = 60.0
const SCALING_FACTOR: float = 1.15
const FILLER_CHECK_INTERVAL: float = 1.0
const FILLER_ARCHETYPES: Array[String] = ["scout", "brawler", "artillery"]

## Post-boss escalation (Assassination "farm or extract" phase): periodic
## bonus waves on top of the normal fill-to-cap, arriving faster over time
## down to a floor of POST_BOSS_MIN_INTERVAL.
const POST_BOSS_INITIAL_INTERVAL: float = 20.0
const POST_BOSS_MIN_INTERVAL: float = 10.0
const POST_BOSS_INTERVAL_DECAY: float = 0.85
const POST_BOSS_WAVE_SIZE: int = 2

const BONUS_WAVE_INTERVAL: float = 90.0
const BONUS_WAVE_SIZE: int = 4
const BONUS_WAVE_DIFFICULTY_BONUS: float = 1.5

const ARCHETYPE_DEFS := {
	"scout": preload("res://resources/enemies/harrier_hrr1v.tres"),
	"brawler": preload("res://resources/enemies/sentinel_snt9a.tres"),
	"artillery": preload("res://resources/enemies/ballista_bls_c1_enemy.tres"),
	"boss": preload("res://resources/enemies/colossus_cls7d_enemy.tres"),
}

var mission: MissionDef = null
var elapsed_time: float = 0.0
var pending_waves: Array[Dictionary] = []
var filler_check_timer: float = 0.0
var active_bosses: int = 0
var post_boss_active: bool = false
var post_boss_interval: float = POST_BOSS_INITIAL_INTERVAL
var post_boss_timer: float = 0.0
var bonus_wave_timer: float = BONUS_WAVE_INTERVAL
var bonus_wave_alive: int = 0

func setup(mission_def: MissionDef) -> void:
	mission = mission_def
	elapsed_time = 0.0
	pending_waves = mission.wave_schedule.duplicate()
	filler_check_timer = 0.0
	active_bosses = 0
	post_boss_active = false
	post_boss_interval = POST_BOSS_INITIAL_INTERVAL
	post_boss_timer = 0.0
	bonus_wave_timer = BONUS_WAVE_INTERVAL
	bonus_wave_alive = 0

## Called once the boss is defeated in an Assassination mission. Begins
## periodic escalating bonus waves (in addition to normal fill-to-cap) for
## as long as the player chooses to keep farming before extracting.
func start_escalating_spawns() -> void:
	post_boss_active = true
	post_boss_interval = POST_BOSS_INITIAL_INTERVAL
	post_boss_timer = post_boss_interval

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

	if post_boss_active:
		post_boss_timer -= delta
		if post_boss_timer <= 0.0:
			_spawn_post_boss_wave()
			post_boss_interval = max(POST_BOSS_MIN_INTERVAL, post_boss_interval * POST_BOSS_INTERVAL_DECAY)
			post_boss_timer = post_boss_interval

	if not GameState.is_bonus_wave and active_bosses == 0 and not post_boss_active:
		bonus_wave_timer -= delta
		if bonus_wave_timer <= 0.0:
			bonus_wave_timer = BONUS_WAVE_INTERVAL
			_spawn_bonus_wave()

func _spawn_post_boss_wave() -> void:
	var scaling_steps: float = floor(elapsed_time / SCALING_INTERVAL)
	var diff_mult: float = mission.base_difficulty * pow(SCALING_FACTOR, scaling_steps)
	for i in POST_BOSS_WAVE_SIZE:
		var archetype: String = FILLER_ARCHETYPES[randi() % FILLER_ARCHETYPES.size()]
		var def: EnemyDef = ARCHETYPE_DEFS.get(archetype)
		_spawn_enemy(def, diff_mult)

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

func _spawn_bonus_wave() -> void:
	if mission == null:
		return
	GameState.is_bonus_wave = true
	bonus_wave_alive = BONUS_WAVE_SIZE
	var scaling_steps := floor(elapsed_time / SCALING_INTERVAL)
	var diff_mult := mission.base_difficulty * BONUS_WAVE_DIFFICULTY_BONUS * pow(SCALING_FACTOR, scaling_steps)
	for i in BONUS_WAVE_SIZE:
		var archetype: String = FILLER_ARCHETYPES[randi() % FILLER_ARCHETYPES.size()]
		var def: EnemyDef = ARCHETYPE_DEFS.get(archetype)
		var enemy := ENEMY_SCENE.instantiate()
		var player := get_tree().get_first_node_in_group("player")
		if player == null:
			break
		var angle := randf() * TAU
		var spawn_pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS
		get_parent().add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.setup(def, diff_mult)
		enemy.defeated.connect(_on_bonus_enemy_defeated)
	bonus_wave_started.emit(mission.bonus_wave_reward)

func _on_bonus_enemy_defeated(_def: EnemyDef) -> void:
	bonus_wave_alive = max(0, bonus_wave_alive - 1)
	if bonus_wave_alive == 0:
		GameState.is_bonus_wave = false
		GameState.add_run_credits(mission.bonus_wave_reward)
		bonus_wave_cleared.emit(mission.bonus_wave_reward)

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
