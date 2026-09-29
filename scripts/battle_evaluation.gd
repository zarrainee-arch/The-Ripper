extends RefCounted
class_name BattleEvaluation

func evaluate(state) -> float:
	# Dari sudut pandang Ripper: HP Ripper tinggi dan HP Player rendah = bagus.
	return float(state.npc_hp - state.player_hp)
