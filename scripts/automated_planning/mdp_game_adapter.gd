extends RefCounted
class_name MDPGameAdapter

const DecisionModel = preload("res://scripts/automated_planning/decision_model.gd")
const MDPSolver = preload("res://scripts/automated_planning/mdp_solver.gd")

const STATES := ["NORMAL", "DANGER", "WEAK_NPC", "WIN", "LOSE"]
const ACTIONS := ["ATTACK", "DEFEND"]

const TERMINAL_STATES := ["WIN", "LOSE"]

const ACTIONS_BY_STATE := {
	"NORMAL": ["ATTACK", "DEFEND"],
	"DANGER": ["ATTACK", "DEFEND"],
	"WEAK_NPC": ["ATTACK", "DEFEND"],
	"WIN": [],
	"LOSE": []
}

const REWARDS := {
	"NORMAL": 0.0,
	"DANGER": -10.0,
	"WEAK_NPC": 5.0,
	"WIN": 100.0,
	"LOSE": -100.0
}

const GAMMA := 0.9

# MODEL
func build_model() -> Dictionary:
	var config := {
		"initial_states": ["NORMAL"],
		"state_ids": STATES,
		"actions_by_state": ACTIONS_BY_STATE,
		"terminal_states": TERMINAL_STATES,
		"terminal_classes": {
			"WIN": DecisionModel.TERMINAL_SUCCESS,
			"LOSE": DecisionModel.TERMINAL_FAILURE
		},
		"reward_by_state": REWARDS,
		"discount_factor": GAMMA
	}

	return DecisionModel.create_model(config)


# TRANSITION PROVIDER
func get_provider() -> Dictionary:
	return {
		"get_transitions": Callable(self, "get_transitions"),
		"actions_by_state": ACTIONS_BY_STATE,
		"terminal_states": TERMINAL_STATES,
		"state_ids": STATES,
		"initial_states": ["NORMAL"]
	}


func get_transitions(state: String, action: String) -> Dictionary:
	var transitions: Array = []

	match state:
		"NORMAL":
			if action == "ATTACK":
				transitions = [
					{
						"branch_id": "normal_attack_1",
						"next_state": "WEAK_NPC",
						"probability": 0.7
					},
					{
						"branch_id": "normal_attack_2",
						"next_state": "DANGER",
						"probability": 0.3
					}
				]
			elif action == "DEFEND":
				transitions = [
					{
						"branch_id": "normal_defend_1",
						"next_state": "NORMAL",
						"probability": 0.8
					},
					{
						"branch_id": "normal_defend_2",
						"next_state": "DANGER",
						"probability": 0.2
					}
				]

		"DANGER":
			if action == "ATTACK":
				transitions = [
					{
						"branch_id": "danger_attack_1",
						"next_state": "WEAK_NPC",
						"probability": 0.6
					},
					{
						"branch_id": "danger_attack_2",
						"next_state": "LOSE",
						"probability": 0.4
					}
				]
			elif action == "DEFEND":
				transitions = [
					{
						"branch_id": "danger_defend_1",
						"next_state": "NORMAL",
						"probability": 0.7
					},
					{
						"branch_id": "danger_defend_2",
						"next_state": "LOSE",
						"probability": 0.3
					}
				]

		"WEAK_NPC":
			if action == "ATTACK":
				transitions = [
					{
						"branch_id": "weak_attack_1",
						"next_state": "WIN",
						"probability": 0.8
					},
					{
						"branch_id": "weak_attack_2",
						"next_state": "DANGER",
						"probability": 0.2
					}
				]
			elif action == "DEFEND":
				transitions = [
					{
						"branch_id": "weak_defend_1",
						"next_state": "WEAK_NPC",
						"probability": 0.6
					},
					{
						"branch_id": "weak_defend_2",
						"next_state": "DANGER",
						"probability": 0.4
					}
				]

	if transitions.is_empty():
		return {
			"valid": false,
			"errors": ["INVALID_TRANSITION"],
			"data": {}
		}

	return {
		"valid": true,
		"errors": [],
		"data": {
			"transitions": transitions
		}
	}


# STATE ABSTRACTION FROM REAL BATTLE
func classify_battle_state(battle_state: BattleState) -> String:
	if battle_state == null:
		return "NORMAL"

	var target := battle_state._first_living_npc()

	if target == -1:
		return "WIN"

	var npc_hp: int = battle_state.npc_hps[target]
	var player_hp: int = battle_state.player_hp

	if player_hp <= 30:
		return "DANGER"

	if npc_hp <= 30:
		return "WEAK_NPC"

	return "NORMAL"


# VALUE ITERATION
func run_value_iteration(battle_state: BattleState) -> Dictionary:
	var model_result: Dictionary = build_model()

	if not model_result.get("valid", false):
		return model_result

	var model: Dictionary = model_result["data"]["model"]
	var provider: Dictionary = get_provider()

	var result: Dictionary = MDPSolver.value_iteration(
		model,
		provider
	)

	if not result.get("valid", false):
		return result

	var data: Dictionary = result.get("data", {})
	var current_state: String = classify_battle_state(battle_state)

	var policy: Dictionary = data.get("policy", {})
	var selected_actions: Dictionary = data.get("selected_actions", {})

	var chosen_action: String = str(
		selected_actions.get(
			current_state,
			policy.get(current_state, "ATTACK")
		)
	)

	return {
		"valid": true,
		"errors": [],
		"data": {
			"status": data.get("status", ""),
			"iterations": data.get("iterations", 0),
			"delta": data.get("delta", 0.0),
			"values": data.get("values", {}),
			"policy": policy,
			"selected_actions": selected_actions,
			"action_rankings": data.get("action_rankings", {}),
			"current_state": current_state,
			"chosen_action": chosen_action,
			"reward_by_state": REWARDS,
			"discount_factor": GAMMA,
			"state_ids": STATES
		}
	}
