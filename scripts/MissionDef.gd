class_name MissionDef extends Resource

@export var mission_name: String = ""
@export var duration_seconds: float = 300.0
## "survive": mission ends when the timer runs out.
## "defeat_boss": mission ends as soon as the boss wave is destroyed; the
## timer still runs (and still scales difficulty) but does not end the mission.
@export_enum("survive", "defeat_boss") var win_condition: String = "survive"
@export var base_difficulty: int = 1         # 1-3, sets enemy stat floor multiplier
@export var credit_reward: int = 300
@export var bonus_wave_reward: int = 150
@export var wave_schedule: Array[Dictionary] = []
# wave_schedule entry format:
# { "time": 30.0, "archetype": "scout", "count": 2, "tier_mult": 1.0 }
