class_name MissionDef extends Resource

@export var mission_name: String = ""
@export var duration_seconds: float = 300.0
## "survive": mission ends when the timer runs out.
## "defeat_boss": mission ends as soon as the boss wave is destroyed; the
## timer still runs (and still scales difficulty) but does not end the mission.
@export_enum("survive", "defeat_boss") var win_condition: String = "survive"
@export var base_difficulty: int = 1         # 1-3, sets enemy stat floor multiplier
## Assassination ("defeat_boss") only: HUD shows a countdown to this time,
## then counts up afterward. 0 = no countdown (timer counts up from start).
@export var boss_spawn_time: float = 0.0
@export var credit_reward: int = 300
@export var bonus_wave_reward: int = 150
## Once the scheduled waves are exhausted (or in addition to them), the spawner
## keeps the alive enemy count topped up to this cap so combat stays dense.
@export var max_alive_enemies: int = 8
@export var wave_schedule: Array[Dictionary] = []
# wave_schedule entry format:
# { "time": 30.0, "archetype": "scout", "count": 2, "tier_mult": 1.0 }

## Independent per-kill drop chances. Keys: "repair", "ballistic_ammo",
## "missile_ammo". Each is rolled separately against EnemyMech.DEFAULT_DROP_WEIGHTS
## if not overridden here. Survival missions may want higher ammo weights.
@export var drop_weights: Dictionary = {
	"repair": 0.25,
	"ballistic_ammo": 0.08,
	"missile_ammo": 0.08,
}
