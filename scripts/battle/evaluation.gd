class_name BattleEvaluation
extends RefCounted


const WIN_SCORE = 1000.0
const HP_WEIGHT = 1.0
const DEFEND_BONUS = 5.0


func evaluate(state: BattleState) -> float:
	# Kondisi terminal
	if state.npc_hp <= 0:
		return -WIN_SCORE

	if state.player_hp <= 0:
		return WIN_SCORE

	# Perbedaan HP
	var score = float(state.npc_hp - state.player_hp) * HP_WEIGHT

	# NPC mendapatkan sedikit keuntungan jika sedang defend
	if state.npc_defending:
		score += DEFEND_BONUS

	# Player yang sedang defend membuat posisi NPC sedikit kurang menguntungkan
	if state.player_defending:
		score -= DEFEND_BONUS

	return score