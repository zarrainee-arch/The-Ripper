class_name BattleEvaluation
extends RefCounted


func evaluate(state: BattleState) -> float:
	if state.npc_hp <= 0:
		return -1000.0

	if state.player_hp <= 0:
		return 1000.0

	return float(state.npc_hp - state.player_hp)