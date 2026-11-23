extends CanvasLayer

var game
var battle_system
var planning_controller

# Overview UI References
var round_label: Label
var player_hp_label: Label
var npc_summary_label: Label
var overview_refresh_elapsed := 0.0
const OVERVIEW_REFRESH_INTERVAL := 0.25

# Planning UI References
var algorithm_label: Label
var plan_status_label: Label
var search_stats_label: Label
var action_plan_label: Label
var no_plan_reason_label: Label

# Nyambungin Hasil Minimax ke Overlay
var minimax_best_action_label: Label
var minimax_search_label: Label
var minimax_best_score_label: Label
var minimax_node_label: Label
var minimax_time_label: Label

# Nyambungin Hasil Alpha Beta ke Overlay
var alpha_beta_best_action_label: Label
var alpha_beta_search_label: Label
var alpha_beta_best_score_label: Label
var alpha_beta_node_label: Label
var alpha_beta_pruned_label: Label
var alpha_beta_time_label: Label

# MDP Value Iteration UI References
var mdp_model_states_label: Label
var mdp_reward_label: Label
var mdp_discount_label: Label
var mdp_values_label: Label
var mdp_q_values_label: Label
var mdp_delta_label: Label
var mdp_iterations_label: Label
var mdp_terminal_value_label: Label

# MEU UI References
var meu_eu_label: Label
var meu_ranking_label: Label
var meu_best_action_label: Label
var meu_tie_label: Label
var meu_outcome_label: Label
const EXPECTED_UTILITY = preload("res://scripts/automated_planning/expected_utility.gd")

# Inference UI References
var inference_facts_label: Label
var inference_rules_label: Label
var inference_subject_label: Label
var inference_matched_label: Label
var inference_conclusion_label: Label
var inference_decision_label: Label
var inference_reasoning_label: Label

## Bayesian UI References
#var distribution_label: Label
#var validation_label: Label
#var marginal_label: Label
#var bayes_update_label: Label
#var evidence_label: Label

func _ready():
	game = get_parent()
	battle_system = game.get_node_or_null("BattleSystem")

	if battle_system:
		planning_controller = battle_system.planning_controller
	else:
		push_warning("BattleSystem tidak ditemukan!")

	# Mengambil node Planning berdasarkan nama node.
	algorithm_label = find_child("AlgorithmLabel", true, false)
	plan_status_label = find_child("PlanLabel", true, false)
	search_stats_label = find_child("SearchStatsLabel", true, false)
	action_plan_label = find_child("Plan Label", true, false)
	no_plan_reason_label = find_child("NoPlanReasonLabel", true, false)
	
	# Minimax UI References
	minimax_best_action_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Minimax/MarginContainer/ScrollContainer/MinimaxVBox/BestActionLabel"
	)
	minimax_search_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Minimax/MarginContainer/ScrollContainer/MinimaxVBox/SearchLabel"
	)
	minimax_best_score_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Minimax/MarginContainer/ScrollContainer/MinimaxVBox/BestScoreLabel"
	)
	minimax_node_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Minimax/MarginContainer/ScrollContainer/MinimaxVBox/NodeExplorerLabel"
	)
	minimax_time_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Minimax/MarginContainer/ScrollContainer/MinimaxVBox/ExecuteTimeLabel"
	)
	
	# Alpha-Beta UI References
	alpha_beta_best_action_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Alpha Beta/MarginContainer/ScrollContainer/AlphaBetaVBox/BestActionLabel"
	)
	alpha_beta_search_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Alpha Beta/MarginContainer/ScrollContainer/AlphaBetaVBox/SearchLabel"
	)
	alpha_beta_best_score_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Alpha Beta/MarginContainer/ScrollContainer/AlphaBetaVBox/BestScoreLabel"
	)
	alpha_beta_node_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Alpha Beta/MarginContainer/ScrollContainer/AlphaBetaVBox/NodeExplorerLabel"
	)
	alpha_beta_pruned_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Alpha Beta/MarginContainer/ScrollContainer/AlphaBetaVBox/PrunedNodeLabel"
	)
	alpha_beta_time_label = get_node_or_null(
	"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/Alpha Beta/MarginContainer/ScrollContainer/AlphaBetaVBox/ExecuteTimeLabel"
	)
	
	# MDP Value Iteration UI References
	mdp_model_states_label = find_child("ModelStateLabel", true, false)
	mdp_reward_label = find_child("RewardLabel", true, false)
	mdp_discount_label = find_child("DiscountLabel", true, false)
	mdp_values_label = find_child("ValuesLabel", true, false)
	mdp_q_values_label = find_child("QValuesLabel", true, false)
	mdp_delta_label = find_child("DeltaLabel", true, false)
	mdp_iterations_label = get_node_or_null(
		"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MDP_VI/MarginContainer/ScrollContainer/MDPVIVBox/IterationLabel"
	)
	mdp_terminal_value_label = get_node_or_null(
		"UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MDP_VI/MarginContainer/ScrollContainer/MDPVIVBox/TerminalValueLabel"
	)
	
	# MEU 
	meu_eu_label = $UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MEU/MarginContainer/ScrollContainer/MEUVBox/EUActionLabel
	meu_ranking_label = $UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MEU/MarginContainer/ScrollContainer/MEUVBox/RankingLabel
	meu_best_action_label = $UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MEU/MarginContainer/ScrollContainer/MEUVBox/BestActionLabel
	meu_tie_label = $UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MEU/MarginContainer/ScrollContainer/MEUVBox/TieLabel
	meu_outcome_label = $UIRoot/PanelContainer/MarginContainer/MainVBox/DebugTabs/MEU/MarginContainer/ScrollContainer/MEUVBox/OutcomeLabel

	# OVERVIEW
	round_label = find_child("RoundLabel", true, false)
	player_hp_label = find_child("PlayerHPLabel", true, false)
	npc_summary_label = find_child("NPCSummaryLabel", true, false)
	print("RoundLabel: ", round_label)
	print("PlayerHPLabel: ", player_hp_label)
	print("NPCSummaryLabel: ", npc_summary_label)
	update_overview_debug()
	
	# Inference UI References
	inference_facts_label = find_child("FactsLabel", true, false)
	inference_rules_label = find_child("RulesLabel", true, false)
	inference_subject_label = find_child("SubjectLabel", true, false)
	inference_matched_label = find_child("MatchedLabel", true, false)
	inference_conclusion_label = find_child("ConclusionLabel", true, false)
	inference_decision_label = find_child("DecisionLabel", true, false)
	inference_reasoning_label = find_child("ReasoningLabel", true, false)
	
	## Bayesian UI References
	#distribution_label = find_child("DistributionLabel", true, false)
	#validation_label = find_child("ValidationLabel", true, false)
	#marginal_label = find_child("MarginalLabel2", true, false)
	#bayes_update_label = find_child("BayesUpdateLabel", true, false)
	#evidence_label = find_child("EvidenceLabel", true, false)
	
	apply_style(self)
	visible = false


func _process(_delta):
	if game == null:
		return

	if not game.battle_started:
		visible = false
		return

	update_planning_debug()
	update_minimax_debug()
	update_alpha_beta_debug()
	update_mdp_debug()
	update_meu_debug()
	update_inference_debug()
	#update_bayesian_debug()

	overview_refresh_elapsed += _delta

	if overview_refresh_elapsed >= OVERVIEW_REFRESH_INTERVAL:
		overview_refresh_elapsed = 0.0
		update_overview_debug()


func _input(event):
	if game == null:
		return

	if not game.battle_started:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			visible = not visible 


func update_planning_debug():
	if planning_controller == null:
		return

	var plan: Dictionary = planning_controller.get_current_plan()

	if plan.is_empty():
		return

	# Algorithm
	var algorithm = plan.get("mode", planning_controller.planner_mode)
	algorithm_label.text = str(algorithm)

	# Plan Status
	var status = plan.get("status", "unknown")
	plan_status_label.text = str(status)

	# Search Statistics
	var nodes_expanded = plan.get("nodes_expanded", 0)
	var total_cost = plan.get("total_cost", 0)
	var execution_time = plan.get("time_ms", 0.0)

	search_stats_label.text = (
		"Nodes Expanded: " + str(nodes_expanded) + "\n"
		+ "Total Cost: " + str(total_cost) + "\n"
		+ "Execution Time: " + str(execution_time) + " ms"
	)

	# Action Plan
	var steps: Array = plan.get("steps", [])
	var plan_text = ""

	if steps.is_empty():
		plan_text = "No action steps available."
	else:
		for i in range(steps.size()):
			var step: Dictionary = steps[i]

			plan_text += (
				str(i + 1) + ". "
				+ str(step.get("action", "Unknown Action"))
				+ " | NPC: "
				+ str(step.get("npc", "Unknown"))
				+ " | Cost: "
				+ str(step.get("cost", 0))
				+ "\n"
			)

	action_plan_label.text = plan_text

	# Failure / Plan Reason
	var reason = plan.get("reason", "")

	if reason == "":
		no_plan_reason_label.text = "No reason reported."
	else:
		no_plan_reason_label.text = str(reason)


func apply_style(node):
	for child in node.get_children():

		if child is Label:
			style_label(child)

		elif child is VBoxContainer:
			child.add_theme_constant_override("separation", 8)

		apply_style(child)


func style_label(label: Label):
	var node_name = label.name

	if node_name.contains("TitleLabel") \
	or node_name == "BattleStatusLabel" \
	or node_name == "NPCStatusLabel":

		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#FFFFFF"))

	else:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#D6D6D6"))


func _on_close_button_pressed():
	visible = false

# Minimax
func update_minimax_debug():
	if battle_system == null:
		return

	var result = battle_system.last_minimax_result

	if result == null:
		if minimax_best_action_label:
			minimax_best_action_label.text = "Waiting for AI..."
		if minimax_search_label:
			minimax_search_label.text = "Waiting for AI..."
		if minimax_best_score_label:
			minimax_best_score_label.text = "Waiting for AI..."
		if minimax_node_label:
			minimax_node_label.text = "Waiting for AI..."
		if minimax_time_label:
			minimax_time_label.text = "Waiting for AI..."
		return

	if minimax_best_action_label:
		minimax_best_action_label.text = str(result.best_action)

	if minimax_search_label:
		minimax_search_label.text = str(result.depth)

	if minimax_best_score_label:
		minimax_best_score_label.text = str(result.best_score)

	if minimax_node_label:
		minimax_node_label.text = str(result.node_count)

	if minimax_time_label:
		minimax_time_label.text = str(result.execution_time_ms) + " ms"

# Alpha Beta
func update_alpha_beta_debug():
	if battle_system == null:
		return

	var result = battle_system.last_alpha_beta_result

	if result == null:
		if alpha_beta_best_action_label:
			alpha_beta_best_action_label.text = "Waiting for AI..."
		if alpha_beta_search_label:
			alpha_beta_search_label.text = "Waiting for AI..."
		if alpha_beta_best_score_label:
			alpha_beta_best_score_label.text = "Waiting for AI..."
		if alpha_beta_node_label:
			alpha_beta_node_label.text = "Waiting for AI..."
		if alpha_beta_pruned_label:
			alpha_beta_pruned_label.text = "Waiting for AI..."
		if alpha_beta_time_label:
			alpha_beta_time_label.text = "Waiting for AI..."
		if alpha_beta_pruned_label:
			alpha_beta_pruned_label.text = "Not verified"
		return

	if alpha_beta_best_action_label:
		alpha_beta_best_action_label.text = str(result.best_action)

	if alpha_beta_search_label:
		alpha_beta_search_label.text = str(result.depth)

	if alpha_beta_best_score_label:
		alpha_beta_best_score_label.text = str(result.best_score)

	if alpha_beta_node_label:
		alpha_beta_node_label.text = str(result.node_count)

	if alpha_beta_time_label:
		alpha_beta_time_label.text = str(result.execution_time_ms) + " ms"

# MDP Value Iteration
func update_mdp_debug():
	if battle_system == null:
		return

	var result: Dictionary = battle_system.last_mdp_result

	if result.is_empty() or not result.get("valid", false):
		var waiting_text = "Waiting for MDP..."

		if mdp_model_states_label:
			mdp_model_states_label.text = waiting_text
		if mdp_reward_label:
			mdp_reward_label.text = waiting_text
		if mdp_discount_label:
			mdp_discount_label.text = waiting_text
		if mdp_values_label:
			mdp_values_label.text = waiting_text
		if mdp_q_values_label:
			mdp_q_values_label.text = waiting_text
		if mdp_delta_label:
			mdp_delta_label.text = waiting_text
		if mdp_iterations_label:
			mdp_iterations_label.text = waiting_text

		return

	var data: Dictionary = result.get("data", {})

	# MODEL STATES
	if mdp_model_states_label:
		var states: Array = data.get("state_ids", [])
		mdp_model_states_label.text = ", ".join(states)

	# REWARD BY STATE
	if mdp_reward_label:
		var rewards: Dictionary = data.get("reward_by_state", {})
		var reward_text = ""

		for state_id in rewards:
			reward_text += str(state_id) + ": " + str(rewards[state_id]) + "\n"

		mdp_reward_label.text = reward_text

	# DISCOUNT FACTOR
	if mdp_discount_label:
		mdp_discount_label.text = str(data.get("discount_factor", 0.0))

	# STATE VALUES
	if mdp_values_label:
		var values: Dictionary = data.get("values", {})
		var value_text = ""

		for state_id in values:
			value_text += str(state_id) + ": " + str(values[state_id]) + "\n"

		mdp_values_label.text = value_text

	# Q VALUES
	if mdp_q_values_label:
		var rankings: Dictionary = data.get("action_rankings", {})
		var q_text = ""

		for state_id in rankings:
			q_text += str(state_id) + ":\n"

			for ranking in rankings[state_id]:
				q_text += (
					"  "
					+ str(ranking.get("action_id", "Unknown"))
					+ " = "
					+ str(ranking.get("q_value", 0.0))
					+ "\n"
				)

		mdp_q_values_label.text = q_text

	# DELTA
	if mdp_delta_label:
		mdp_delta_label.text = str(data.get("delta", 0.0))

	# ITERATIONS & STATUS
	if mdp_iterations_label:
		mdp_iterations_label.text = (
			"Status: " + str(data.get("status", "Unknown")) + "\n"
			+ "Iterations: " + str(data.get("iterations", 0))
		)
	
	# TERMINAL VALUES
	if mdp_terminal_value_label:
		var terminal_text = ""
		var terminal_states = ["WIN", "LOSE"]
		var values: Dictionary = data.get("values", {})

		for terminal_state in terminal_states:
			terminal_text += (
				str(terminal_state)
				+ ": "
				+ str(values.get(terminal_state, 0.0))
				+ "\n"
			)

		mdp_terminal_value_label.text = terminal_text
		

func update_meu_debug():
	if battle_system == null or battle_system.state == null:
		_set_meu_waiting("Battle state unavailable.")
		return

	var state = battle_system.state

	var player_hp: float = float(state.player_hp)
	var max_hp: float = float(battle_system.MAX_HP)
	var living_npcs: int = battle_system.get_living_enemy_count()
	var potions: int = int(state.player_potions)

	if living_npcs <= 0:
		_set_meu_waiting("No living NPC.")
		return

	# Utility berdasarkan kondisi gameplay saat ini.
	var actions: Dictionary = {}

	# ATTACK: estimasi hasil serangan dan peluang menerima damage.
	var attack_damage: float = float(battle_system.ATTACK_DAMAGE)
	var target_index: int = battle_system.get_first_living_enemy()
	var target_hp: float = 0.0

	if target_index >= 0 and target_index < state.npc_hps.size():
		target_hp = float(state.npc_hps[target_index])

	var attack_outcomes: Array = [
		{
			"id": "ATTACK_SUCCESS",
			"probability": 0.7,
			"utility": attack_damage + (10.0 if target_hp <= attack_damage else 0.0)
		},
		{
			"id": "COUNTER",
			"probability": 0.3,
			"utility": -5.0 * living_npcs
		}
	]

	actions["ATTACK"] = attack_outcomes

	# DEFEND: nilai bertahan berdasarkan jumlah NPC hidup.
	actions["DEFEND"] = [
		{
			"id": "DAMAGE_REDUCED",
			"probability": 0.8,
			"utility": 5.0 * living_npcs
		},
		{
			"id": "DEFENSE_FAILURE",
			"probability": 0.2,
			"utility": -2.0
		}
	]

	# POTION: utility berdasarkan HP yang hilang dan potion tersedia.
	if potions > 0 and player_hp < max_hp:
		var heal_amount: float = min(
			float(battle_system.POTION_HEAL),
			max_hp - player_hp
		)

		actions["POTION"] = [
			{
				"id": "HEAL",
				"probability": 1.0,
				"utility": heal_amount * 1.5
			}
		]
	else:
		actions["POTION"] = [
			{
				"id": "UNAVAILABLE",
				"probability": 1.0,
				"utility": -100.0
			}
		]

	# Hitung MEU menggunakan modul Expected Utility asli.
	var result: Dictionary = EXPECTED_UTILITY.choose_meu(actions)

	if not result.get("valid", false):
		_set_meu_waiting("MEU calculation failed.")
		return

	var meu_data: Dictionary = result.get("data", {})
	var ranking: Array = meu_data.get("ranking", [])

	if ranking.is_empty():
		_set_meu_waiting("Ranking unavailable.")
		return

	# Expected Utility maksimum.
	if meu_eu_label:
		meu_eu_label.text = str(
			meu_data.get("maximum_expected_utility", "N/A")
		)

	# Ranking.
	var ranking_text := ""

	for i in range(ranking.size()):
		var item: Dictionary = ranking[i]

		ranking_text += (
			str(i + 1) + ". "
			+ str(item.get("action_id", "Unknown"))
			+ " | EU: "
			+ str(item.get("expected_utility", "N/A"))
			+ "\n"
		)

	if meu_ranking_label:
		meu_ranking_label.text = ranking_text

	# Best action.
	if meu_best_action_label:
		meu_best_action_label.text = str(
			meu_data.get("best_action", "N/A")
		)

	# Tie.
	var tied_actions: Array[String] = []
	var maximum_eu: float = float(
		meu_data.get("maximum_expected_utility", 0.0)
	)

	for item in ranking:
		if float(item.get("expected_utility", -INF)) >= maximum_eu - 0.000000001:
			tied_actions.append(str(item.get("action_id", "Unknown")))

	if meu_tie_label:
		meu_tie_label.text = (
			"Tie: " + ", ".join(tied_actions)
			if tied_actions.size() > 1
			else "No tie"
		)

	# Outcome details dari aksi terbaik.
	var outcome_text := ""
	var best_item: Dictionary = ranking[0]
	var outcome_details: Array = best_item.get("outcome_details", [])

	for outcome in outcome_details:
		outcome_text += (
			str(outcome.get("id", "Unknown"))
			+ " | P: " + str(outcome.get("probability", 0))
			+ " | Utility: " + str(outcome.get("utility", 0))
			+ " | Contribution: " + str(outcome.get("contribution", 0))
			+ "\n"
		)

	if meu_outcome_label:
		meu_outcome_label.text = outcome_text

func _set_meu_waiting(message: String):
	if meu_eu_label:
		meu_eu_label.text = message
	if meu_ranking_label:
		meu_ranking_label.text = message
	if meu_best_action_label:
		meu_best_action_label.text = message
	if meu_tie_label:
		meu_tie_label.text = message
	if meu_outcome_label:
		meu_outcome_label.text = message

# KHUSUS TAB OVERVIEW
func update_overview_debug() -> void:
	if battle_system == null or battle_system.state == null:
		round_label.text = "Round: -"
		player_hp_label.text = "Player HP: -"
		npc_summary_label.text = "Leader: -\nFollower Alive: -\nFollower Dead: -"
		return

	var state = battle_system.state

	round_label.text = "Round: %d" % (battle_system.planning_turn_counter + 1)
	player_hp_label.text = "Player HP: %d / %d" % [state.player_hp, battle_system.MAX_HP]

	var leader_name := "-"
	var follower_alive := 0
	var follower_dead := 0

	for i in range(battle_system.enemy_nodes.size()):
		var enemy = battle_system.enemy_nodes[i]

		if not is_instance_valid(enemy):
			continue

		var role := str(enemy.get_meta("planning_role", "UNASSIGNED"))
		var hp := 0

		if i < state.npc_hps.size():
			hp = state.npc_hps[i]

		if role.to_upper() == "LEADER":
			leader_name = enemy.name
		elif role.to_upper() == "FOLLOWER":
			if hp > 0:
				follower_alive += 1
			else:
				follower_dead += 1

	npc_summary_label.text = "Leader: %s\nFollower Alive: %d\nFollower Dead: %d" % [
		leader_name,
		follower_alive,
		follower_dead
	]

# INFERENCE
func update_inference_debug() -> void:
	if battle_system == null:
		return

	var result: Dictionary = battle_system.last_inference_result

	if result.is_empty():
		return

	# SUBJECT & TURN
	if inference_subject_label:
		inference_subject_label.text = (
			"Subject: " + str(result.get("subject", "-"))
			+ " | Turn: " + str(result.get("turn", "-"))
		)

	# CURRENT FACTS
	if inference_facts_label:
		var facts: Array = result.get("facts_in", [])
		var facts_text := ""

		for fact in facts:
			var line := str(fact.get("predicate", "?"))
			line += " | " + str(fact.get("subject", "?"))

			if fact.has("value"):
				line += " | " + str(fact["value"])

			if fact.has("turn"):
				line += " | Turn " + str(fact["turn"])

			facts_text += line + "\n"

		inference_facts_label.text = facts_text

		# RULE EVALUATION
	if inference_rules_label:
		var rules: Array = result.get("rules_checked", [])

		rules.sort_custom(func(a, b):
			return int(str(a.get("rule_id", "R0")).substr(1)) < int(str(b.get("rule_id", "R0")).substr(1))
		)

		var rules_text := ""

		for rule in rules:
			var rule_id := str(rule.get("rule_id", "?"))
			var matched := bool(rule.get("matched", false))
			var status := "MATCH" if matched else "NO MATCH"
			var explanation := str(rule.get("why", ""))

			rules_text += rule_id + " | " + status + "\n"
			rules_text += explanation + "\n\n"

		inference_rules_label.text = rules_text

	# MATCHED RULES
	if inference_matched_label:
		var matched: Array = result.get("matched_rules", [])
		inference_matched_label.text = (
			", ".join(matched) if not matched.is_empty() else "-"
		)

	# INFERENCE RESULT
	if inference_conclusion_label:
		inference_conclusion_label.text = str(
			result.get("decision", "NONE")
		)

	 #DECISION REASON
	if inference_decision_label:
		inference_decision_label.text = (
			str(result.get("reason", "-"))
			+ "\nFallback: "
			+ str(result.get("fallback_used", false))
		)

	 #REASONING SUMMARY
	 #REASONING TRACE
	if inference_reasoning_label:
		var matched: Array = result.get("rules_checked", [])
		var reasoning_text := ""

		for rule in matched:
			if not rule.get("matched", false):
				continue

			var rule_id := str(rule.get("rule_id", "?"))
			var explanation := str(rule.get("why", ""))

			reasoning_text += (
				rule_id + ": "
				+ explanation + "\n\n"
			)

		if reasoning_text.is_empty():
			reasoning_text = "No rules matched."

		inference_reasoning_label.text = reasoning_text
#
# BAYESIAN
#func update_bayesian_debug() -> void:
	#if battle_system == null:
		#return
#
	#var belief: Dictionary = battle_system.active_bayesian_belief
	#var result: Dictionary = battle_system.last_bayesian_result
	#var evidence: String = battle_system.last_bayesian_evidence
	#var status: String = battle_system.last_bayesian_status
#
	# DISTRIBUTION
	#if distribution_label != null:
		#var distribution_text := ""
#
		#var distribution: Dictionary = belief.get("distribution", {})
#
		#if distribution.is_empty():
			#distribution_text = "Belief belum tersedia."
		#else:
			#for hypothesis in distribution:
				#distribution_text += "%s : %.6f\n" % [
					#hypothesis,
					#float(distribution[hypothesis])
				#]
#
		#distribution_label.text = distribution_text
#
	# VALIDATION
	#if validation_label != null:
		#if belief.is_empty():
			#validation_label.text = "Belief belum diinisialisasi."
		#else:
			#validation_label.text = "Status: %s" % status

	# EVIDENCE
	#if evidence_label != null:
		#evidence_label.text = evidence
#
	# MARGINAL
	#if marginal_label != null:
		#if result.get("valid", false):
			#var data: Dictionary = result.get("data", {})
			#marginal_label.text = str(data.get("marginal", "-"))
		#else:
			#marginal_label.text = "-"
#
	# BAYES UPDATE / POSTERIOR
	#if bayes_update_label != null:
		#if result.get("valid", false):
			#var data: Dictionary = result.get("data", {})
			#var posterior: Dictionary = data.get("posterior", {})
			#var posterior_distribution: Dictionary = posterior.get("distribution", {})
#
			#var posterior_text := ""
#
			#for hypothesis in posterior_distribution:
				#posterior_text += "%s : %.6f\n" % [
					#hypothesis,
					#float(posterior_distribution[hypothesis])
				#]
#
			#bayes_update_label.text = posterior_text
		#else:
			#if result.is_empty():
				#bayes_update_label.text = "Belum ada Bayesian update."
			#else:
				#bayes_update_label.text = str(result.get("errors", []))
