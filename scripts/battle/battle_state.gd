class_name BattleState
extends RefCounted

const ACTION_ATTACK = 0
const ACTION_DEFEND = 1
const ACTION_POTION = 2

const MAX_HP = 100
const ATTACK_DAMAGE = 20
const DEFEND_REDUCTION = 0.5
const POTION_HEAL = 20

var player_hp: int
var npc_hp: int
var current_turn: String

var player_defending: bool
var npc_defending: bool


func _init(
	player_hp_value: int = 100,
	npc_hp_value: int = 100,
	turn_value: String = "PLAYER"
):
	player_hp = player_hp_value
	npc_hp = npc_hp_value
	current_turn = turn_value

	player_defending = false
	npc_defending = false


func is_terminal() -> bool:
	return player_hp <= 0 or npc_hp <= 0


func get_available_actions() -> Array:
	if is_terminal():
		return []

	return [
		ACTION_ATTACK,
		ACTION_DEFEND,
		ACTION_POTION
	]


func apply_action_simulation(action) -> BattleState:
	var next_state = BattleState.new(
		player_hp,
		npc_hp,
		current_turn
	)

	next_state.player_defending = player_defending
	next_state.npc_defending = npc_defending

	if current_turn == "PLAYER":
		next_state._apply_player_action(action)
		next_state.current_turn = "NPC"
	else:
		next_state._apply_npc_action(action)
		next_state.current_turn = "PLAYER"

	return next_state


func _apply_player_action(action) -> void:
	match action:
		ACTION_ATTACK:
			var damage = ATTACK_DAMAGE

			if npc_defending:
				damage = int(damage * DEFEND_REDUCTION)
				npc_defending = false

			npc_hp = max(0, npc_hp - damage)

		ACTION_DEFEND:
			player_defending = true

		ACTION_POTION:
			player_hp = min(MAX_HP, player_hp + POTION_HEAL)


func _apply_npc_action(action) -> void:
	match action:
		ACTION_ATTACK:
			var damage = ATTACK_DAMAGE

			if player_defending:
				damage = int(damage * DEFEND_REDUCTION)
				player_defending = false

			player_hp = max(0, player_hp - damage)

		ACTION_DEFEND:
			npc_defending = true

		ACTION_POTION:
			npc_hp = min(MAX_HP, npc_hp + POTION_HEAL)
