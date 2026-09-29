class_name BattleState
extends RefCounted

enum Action {
	ATTACK,
	DEFEND,
	POTION
}

var player_hp: int
var npc_hp: int
var current_turn: String
var player_defending: bool = false
var npc_defending: bool = false
var player_potions: int
var npc_potions: int

func _init(player_hp_value: int = 100,npc_hp_value: int = 100,turn_value: String = "PLAYER",player_potions_value: int = 3,npc_potions_value: int = 3):
	player_hp = player_hp_value
	npc_hp = npc_hp_value
	current_turn = turn_value
	player_potions = player_potions_value
	npc_potions = npc_potions_value

func is_terminal() -> bool:
	return player_hp <= 0 or npc_hp <= 0

func get_available_actions() -> Array:
	if is_terminal():
		return []

	var actions = [Action.ATTACK,Action.DEFEND]

	# Player boleh memakai Potion selama masih punya stok.
	if current_turn == "PLAYER" and player_potions > 0:
		actions.append(Action.POTION)

	# Ripper mulai mempertimbangkan Potion kalau HP sudah 70 atau kurang.
	if current_turn == "NPC" and npc_potions > 0 and npc_hp <= 70:
		actions.append(Action.POTION)

	return actions

func apply_action_simulation(action) -> BattleState:
	var next_state = BattleState.new(player_hp,npc_hp,current_turn,player_potions,npc_potions)
	next_state.player_defending = player_defending
	next_state.npc_defending = npc_defending

	const DAMAGE = 5
	const HEAL = 10

	if current_turn == "NPC":
		match action:
			Action.ATTACK:
				var damage = DAMAGE
				if next_state.player_defending:
					damage = int(damage * 0.5)
					next_state.player_defending = false
				next_state.player_hp = max(0,next_state.player_hp - damage)
			Action.DEFEND:
				next_state.npc_defending = true
			Action.POTION:
				if next_state.npc_potions > 0:
					next_state.npc_hp = min(100,next_state.npc_hp + HEAL)
					next_state.npc_potions -= 1
		next_state.current_turn = "PLAYER"
	else:
		match action:
			Action.ATTACK:
				var damage = DAMAGE
				if next_state.npc_defending:
					damage = int(damage * 0.5)
					next_state.npc_defending = false
				next_state.npc_hp = max(0,next_state.npc_hp - damage)
			Action.DEFEND:
				next_state.player_defending = true
			Action.POTION:
				if next_state.player_potions > 0:
					next_state.player_hp = min(100,next_state.player_hp + HEAL)
					next_state.player_potions -= 1
		next_state.current_turn = "NPC"

	return next_state
