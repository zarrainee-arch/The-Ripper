class_name BattleSystem
extends Node

enum Action {
	ATTACK,
	DEFEND,
	POTION
}

const MAX_HP = 100
const ATTACK_DAMAGE = 20
const DEFEND_REDUCTION = 0.5
const POTION_HEAL = 20

var state: BattleState

func start_battle():
	state = BattleState.new(MAX_HP, MAX_HP, "PLAYER")
	
	print("=== BATTLE START ===")
	print("Player HP: ", state.player_hp)
	print("NPC HP: ", state.npc_hp)
	print("Turn: ", state.current_turn)

func execute_action(action: Action, actor: String):
	if state == null:
		return

	if state.is_terminal():
		return

	if actor != state.current_turn:
		return

	match action:
		Action.ATTACK:
			attack(actor)
		Action.DEFEND:
			defend(actor)
		Action.POTION:
			potion(actor)

	if state.is_terminal():
		end_battle()
		return

	change_turn()

	if state.current_turn == "NPC":
		npc_turn()

func attack(actor: String):
	var damage = ATTACK_DAMAGE

	if actor == "PLAYER":
		if state.npc_defending:
			damage = int(damage * DEFEND_REDUCTION)
			state.npc_defending = false

		state.npc_hp = max(0, state.npc_hp - damage)
		print("PLAYER attacks NPC for ", damage, " damage.")

	elif actor == "NPC":
		if state.player_defending:
			damage = int(damage * DEFEND_REDUCTION)
			state.player_defending = false

		state.player_hp = max(0, state.player_hp - damage)
		print("NPC attacks PLAYER for ", damage, " damage.")

func defend(actor: String):
	if actor == "PLAYER":
		state.player_defending = true
		print("PLAYER defends.")
	elif actor == "NPC":
		state.npc_defending = true
		print("NPC defends.")

func potion(actor: String):
	if actor == "PLAYER":
		state.player_hp = min(MAX_HP, state.player_hp + POTION_HEAL)
		print("PLAYER uses potion.")
	elif actor == "NPC":
		state.npc_hp = min(MAX_HP, state.npc_hp + POTION_HEAL)
		print("NPC uses potion.")

func change_turn():
	if state.current_turn == "PLAYER":
		state.current_turn = "NPC"
	else:
		state.current_turn = "PLAYER"

	print("Next turn: ", state.current_turn)
	
func _input(event):
	if state == null:
		return

	if state.is_terminal():
		return

	if state.current_turn != "PLAYER":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				execute_action(Action.ATTACK, "PLAYER")
			KEY_D:
				execute_action(Action.DEFEND, "PLAYER")
			KEY_P:
				execute_action(Action.POTION, "PLAYER")
				
func npc_turn():
	if state == null:
		return

	if state.is_terminal():
		return

	if state.current_turn != "NPC":
		return

	print("=== NPC TURN ===")

	execute_action(Action.ATTACK, "NPC")
	
func end_battle():
	print("=== BATTLE OVER ===")

	if state.player_hp <= 0:
		print("PLAYER DEFEATED")
	elif state.npc_hp <= 0:
		print("NPC DEFEATED")
