extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/game/PlayerMech.tscn")
const DEFAULT_MECH: MechDef = preload("res://resources/mechs/jenner_jr7d.tres")
const DEFAULT_MISSION: MissionDef = preload("res://resources/missions/mission1_recon_in_force.tres")

const ZOOM_STEP: float = 0.1
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 1.5

var player: CharacterBody2D = null
var mission_ended: bool = false

func _ready() -> void:
	if GameState.current_mech == null:
		GameState.reset_run(DEFAULT_MECH)
	if GameState.current_mission == null:
		GameState.current_mission = DEFAULT_MISSION
	player = PLAYER_SCENE.instantiate()
	player.global_position = $PlayerSpawn.global_position
	add_child(player)
	$Camera2D.global_position = player.global_position
	$EnemySpawner.setup(GameState.current_mission)
	$EnemySpawner.boss_defeated.connect(_on_boss_defeated)
	$HUD.refresh(player)
	$HUD.extract_requested.connect(_on_extract_requested)

func _process(delta: float) -> void:
	if mission_ended:
		return
	GameState.mission_timer += delta
	if GameState.current_mission.win_condition == "survive" \
			and GameState.mission_timer >= GameState.current_mission.duration_seconds:
		_complete_mission()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(player):
		$Camera2D.global_position = player.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(-ZOOM_STEP)

func _adjust_zoom(delta: float) -> void:
	var new_zoom: float = clamp($Camera2D.zoom.x + delta, MIN_ZOOM, MAX_ZOOM)
	$Camera2D.zoom = Vector2(new_zoom, new_zoom)

## Boss death never ends the mission directly. Assassination: show the
## Exceptional Salvage panel and kick off escalating post-boss spawns so the
## player can farm before extracting. Survival: show the panel and keep
## surviving toward the timer.
func _on_boss_defeated() -> void:
	if mission_ended:
		return
	$ExceptionalSalvage.show_panel(SalvageSystem.roll_exceptional_salvage())
	if GameState.current_mission.win_condition == "defeat_boss":
		$EnemySpawner.start_escalating_spawns()

## Extract button: Assassination banks rewards immediately (the intended way
## to end the mission). Survival forfeits all rewards if used before the
## timer expires.
func _on_extract_requested() -> void:
	if mission_ended:
		return
	if GameState.current_mission.win_condition == "survive":
		mission_ended = true
		GameState.mission_extract_failed.emit()
	else:
		_complete_mission()

func _complete_mission() -> void:
	mission_ended = true
	var credits := GameState.current_mission.credit_reward + GameState.calculate_weapon_salvage() + GameState.run_credits
	GameState.mission_complete.emit(credits)
