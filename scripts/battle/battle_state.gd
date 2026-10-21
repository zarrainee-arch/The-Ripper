
extends RefCounted
class_name BattleState

enum Action {
	ATTACK,
	DEFEND,
	POTION
}

const PLAYER_MAX_HP := 150
const NPC_MAX_HP := 100
const PLAYER_DAMAGE := 10
const NPC_DAMAGE := 5
const HEAL_AMOUNT := 10

var player_hp: int
var npc_hps: Array[int] = []

var current_turn: String = "PLAYER"
var player_defending: bool = false
var npc_defendings: Array[bool] = []
var player_potions: int = 3
var npc_potions: Array[int] = []
var target_index: int = 0


func _init(
	player_hp_value: int = PLAYER_MAX_HP,
	npc_hp_value: int = NPC_MAX_HP,
	turn_value: String = "PLAYER",
	player_potions_value: int = 3,
	npc_potions_value: int = 3
) -> void:
	player_hp = player_hp_value
	current_turn = turn_value
	player_potions = player_potions_value

	if npc_hp_value > 0:
		npc_hps.append(npc_hp_value)
		npc_defendings.append(false)
		npc_potions.append(npc_potions_value)


func setup_npcs(count: int, hp_per_npc: int = NPC_MAX_HP) -> void:
	npc_hps.clear()
	npc_defendings.clear()
	npc_potions.clear()

	for i in range(count):
		npc_hps.append(hp_per_npc)
		npc_defendings.append(false)
		npc_potions.append(3)

	target_index = 0


func is_terminal() -> bool:
	if player_hp <= 0:
		return true

	for hp in npc_hps:
		if hp > 0:
			return false

	return true


func get_available_actions() -> Array:
	if is_terminal():
		return []

	var actions: Array = [Action.ATTACK, Action.DEFEND]

	if current_turn == "PLAYER":
		if player_potions > 0 and player_hp < PLAYER_MAX_HP:
			actions.append(Action.POTION)
	else:
		var target := _first_living_npc()
		if target != -1:
			if (
				npc_potions[target] > 0
				and npc_hps[target] <= NPC_MAX_HP - HEAL_AMOUNT
			):
				actions.append(Action.POTION)

	return actions


func apply_action_simulation(action: int) -> BattleState:
	var next_state := BattleState.new(
		player_hp, 0, current_turn, player_potions, 0
	)

	next_state.npc_hps = npc_hps.duplicate()
	next_state.npc_defendings = npc_defendings.duplicate()
	next_state.npc_potions = npc_potions.duplicate()
	next_state.player_defending = player_defending
	next_state.target_index = target_index

	while next_state.npc_defendings.size() < next_state.npc_hps.size():
		next_state.npc_defendings.append(false)

	while next_state.npc_potions.size() < next_state.npc_hps.size():
		next_state.npc_potions.append(3)

	while next_state.npc_defendings.size() > next_state.npc_hps.size():
		next_state.npc_defendings.pop_back()

	while next_state.npc_potions.size() > next_state.npc_hps.size():
		next_state.npc_potions.pop_back()

	var target := next_state._first_living_npc()

	if target == -1:
		return next_state

	if current_turn == "NPC":
		match action:
			Action.ATTACK:
				var damage := PLAYER_DAMAGE
				if next_state.player_defending:
					damage = int(ceil(damage / 2.0))
					next_state.player_defending = false
				next_state.npc_hps[target] = max(
					0, next_state.npc_hps[target] - damage
				)

			Action.DEFEND:
				next_state.npc_defendings[target] = true

			Action.POTION:
				if next_state.npc_potions[target] > 0:
					next_state.npc_hps[target] = min(
						NPC_MAX_HP,
						next_state.npc_hps[target] + HEAL_AMOUNT
					)
					next_state.npc_potions[target] -= 1

		next_state.current_turn = "PLAYER"

	else:
		match action:
			Action.ATTACK:
				var damage := NPC_DAMAGE
				if next_state.npc_defendings[target]:
					damage = int(ceil(damage / 2.0))
					next_state.npc_defendings[target] = false
				next_state.player_hp = max(
					0, next_state.player_hp - damage
				)

			Action.DEFEND:
				next_state.player_defending = true

			Action.POTION:
				if next_state.player_potions > 0:
					next_state.player_hp = min(
						PLAYER_MAX_HP,
						next_state.player_hp + HEAL_AMOUNT
					)
					next_state.player_potions -= 1

		next_state.current_turn = "NPC"

	return next_state


func _first_living_npc() -> int:
	for i in range(npc_hps.size()):
		if npc_hps[i] > 0:
			return i

	return -1
