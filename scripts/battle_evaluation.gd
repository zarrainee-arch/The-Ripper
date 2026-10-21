
extends RefCounted
class_name BattleEvaluation

func evaluate(state) -> float:
	var total_npc_hp: float = 0.0

	for hp in state.npc_hps:
		total_npc_hp += float(hp)

	# Sudut pandang Ripper:
	# total HP NPC tinggi dan HP pemain rendah = bagus.
	if state.player_hp <= 0:
		return 10000.0

	if total_npc_hp <= 0:
		return -10000.0

	return total_npc_hp - float(state.player_hp)
