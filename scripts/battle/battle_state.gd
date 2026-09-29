class_name BattleState
extends RefCounted

var player_hp: int
var npc_hp: int
var current_turn: String

func _init(
	player_hp_value: int = 100,
	npc_hp_value: int = 100,
	turn_value: String = "PLAYER"
):
	player_hp = player_hp_value
	npc_hp = npc_hp_value
	current_turn = turn_value

func is_terminal() -> bool:
	return player_hp <= 0 or npc_hp <= 0