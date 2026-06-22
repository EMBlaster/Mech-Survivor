extends Node

const CORPS: Array[CorpDef] = [
	preload("res://resources/corps/continental_defense.tres"),
	preload("res://resources/corps/vantage_arms.tres"),
	preload("res://resources/corps/quickfire_industries.tres"),
	preload("res://resources/corps/ironforge_munitions.tres"),
	preload("res://resources/corps/kovacs_arms.tres"),
	preload("res://resources/corps/helix_energy.tres"),
	preload("res://resources/corps/salvo_systems.tres"),
	preload("res://resources/corps/axiom_dynamics.tres"),
	preload("res://resources/corps/crucible_heavy.tres"),
	preload("res://resources/corps/redline_surplus.tres"),
]

const BASE_MISSIONS: Array[MissionDef] = [
	preload("res://resources/missions/mission1_recon_in_force.tres"),
	preload("res://resources/missions/mission2_defensive_action.tres"),
	preload("res://resources/missions/mission3_maximum_attrition.tres"),
]

const BOARD_SIZE: int = 3
## Per-slot probability of a corp-sponsored contract. Scales up with best positive rep.
const CORP_SLOT_CHANCE: float = 0.20

var available_missions: Array[MissionDef] = []

func _ready() -> void:
	refresh()

## Rebuilds the board. Call after each mission ends so the player sees fresh contracts.
func refresh() -> void:
	available_missions.clear()
	var used_base_indices: Array[int] = []
	for _i in BOARD_SIZE:
		var corp := _try_pick_corp()
		if corp != null:
			available_missions.append(_build_corp_mission(corp, used_base_indices))
		else:
			var idx := _pick_base_index(used_base_indices)
			used_base_indices.append(idx)
			available_missions.append(BASE_MISSIONS[idx])

## Returns a corp for a sponsored slot, or null for a generic slot.
## Sponsored chance = base + bonus proportional to highest positive rep held.
func _try_pick_corp() -> CorpDef:
	var best_rep := 0
	for corp in CORPS:
		if not SaveManager.is_corp_dark(corp.corp_name):
			best_rep = maxi(best_rep, SaveManager.get_rep(corp.corp_name))
	var chance := CORP_SLOT_CHANCE + (float(best_rep) / 100.0) * CORP_SLOT_CHANCE
	if randf() > chance:
		return null
	return _weighted_corp_draw()

## Weighted draw from non-dark corps. weight = availability + rep * 0.02.
func _weighted_corp_draw() -> CorpDef:
	var eligible: Array[CorpDef] = []
	var weights: Array[float] = []
	for corp in CORPS:
		if SaveManager.is_corp_dark(corp.corp_name):
			continue
		var w := maxf(0.0, corp.availability + float(SaveManager.get_rep(corp.corp_name)) * 0.02)
		if w > 0.0:
			eligible.append(corp)
			weights.append(w)
	if eligible.is_empty():
		return null
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for i in eligible.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return eligible[i]
	return eligible[-1]

## Picks a base mission index not yet used in this refresh pass.
func _pick_base_index(used: Array[int]) -> int:
	var pool: Array[int] = []
	for i in BASE_MISSIONS.size():
		if i not in used:
			pool.append(i)
	if pool.is_empty():
		return randi() % BASE_MISSIONS.size()
	return pool[randi() % pool.size()]

## Duplicates a base mission and stamps it with corp identity and elevated difficulty.
func _build_corp_mission(corp: CorpDef, used_base_indices: Array[int]) -> MissionDef:
	var base_idx := _pick_base_index(used_base_indices)
	used_base_indices.append(base_idx)
	var base: MissionDef = BASE_MISSIONS[base_idx]
	var result: MissionDef = base.duplicate(true) as MissionDef
	result.mission_name = "%s: %s" % [corp.corp_name, base.mission_name]
	result.base_difficulty = clampi(base.base_difficulty + 1, 1, 3)
	result.credit_reward = int(float(base.credit_reward) * 1.5)
	result.bonus_wave_reward = int(float(base.bonus_wave_reward) * 1.5)
	result.max_alive_enemies = base.max_alive_enemies + 2
	result.sponsored_by_corp = corp.corp_name
	return result
