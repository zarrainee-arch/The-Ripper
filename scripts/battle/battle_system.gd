class_name BattleSystem
extends Node

enum Action { ATTACK, DEFEND, POTION }

const MAX_HP := 100
const ATTACK_DAMAGE := 5
const DEFEND_REDUCTION := 0.5
const POTION_HEAL := 10
const MAX_POTIONS := 3
const MAX_ATTACKERS_PER_ROUND := 2
const NPC_ATTACK_DELAY := 0.35

var state: BattleState
var battle_ai: BattleAI
var evaluation
var ai_thinking := false
var last_minimax_result
var last_alpha_beta_result

var player_idle: Node2D
var player_battle: AnimatedSprite2D
var attack_sound

var enemy_nodes: Array = []
var battle_running := false
var next_enemy_start := 0

# NPC yang sedang dipilih Player
var selected_target_index := -1

# Menyambungkan Automated Planning
const PLANNING_CONTROLLER = preload("res://scripts/automated_planning/planning_controller.gd")
var planning_controller
var planning_turn_counter := 0

# Menyambungkan MDP
const MDPAdapter = preload("res://scripts/automated_planning/mdp_game_adapter.gd")
var last_mdp_result: Dictionary = {}

# Mode AI NPC: PLANNING atau MDP
var npc_ai_mode: String = "PLANNING"
#var npc_ai_mode: String = "MDP"

# Inference Engine / KB / Log
const INFERENCE_ENGINE = preload("res://scripts/kb_ie/inference_engine.gd")
const KNOWLEDGE_BASE = preload("res://scripts/kb_ie/knowledge_base.gd")
const INFERENCE_LOG = preload("res://scripts/kb_ie/inference_log.gd")
var knowledge_base
var inference_log
var inference_engine
var last_inference_result: Dictionary = {}


#const BAYES_UPDATER = preload("res://scripts/bayes_belief/bayesian_updater1.gd")
#const TRANSITION_MODEL = preload("res://scripts/bayes_belief/transition_model1.gd")
#const UNCERTAINTY_BELIEF = preload("res://scripts/bayes_belief/uncertainty_belief1.gd")
#
#var bayes_updater = BAYES_UPDATER.new()
#var transition_model = TRANSITION_MODEL.new()
#var uncertainty_belief = UNCERTAINTY_BELIEF.new()
#var active_bayesian_belief: Dictionary = {}
#var last_bayesian_result: Dictionary = {}
#var last_bayesian_evidence: String = "-"
#var last_bayesian_status: String = "WAITING"

func _ready() -> void:
#	automated planning
	planning_controller = PLANNING_CONTROLLER.new()
	
	knowledge_base = KNOWLEDGE_BASE.new()
	inference_log = INFERENCE_LOG.new()
	inference_engine = INFERENCE_ENGINE.new(
	knowledge_base,
	inference_log
	)
	get_viewport().physics_object_picking = true

	battle_ai = BattleAI.new("minimax", 3)
	
	var evaluation_script = preload("res://scripts/battle/battle_evaluation.gd")
	evaluation = evaluation_script.new()

	var root = get_parent()
	var player = root.get_node_or_null("Player")

	if player:
		player_idle = player.get_node_or_null("Sprite2D")
		player_battle = player.get_node_or_null("BattlePlayer")

	attack_sound = root.get_node_or_null("AttackSFX")

	if player_battle:
		player_battle.visible = false


func start_battle(_enemy_count: int = -1) -> void:
	var root = get_parent()
	enemy_nodes.clear()

	# Kumpulkan setiap NPC aktif tepat satu kali.
	for child in root.get_children():
		if child is CharacterBody2D:
			if child.is_in_group("battle_enemies") and child.visible:
				enemy_nodes.append(child)

	# Fallback untuk scene yang belum menggunakan grup.
	if enemy_nodes.is_empty():
		for node_name in ["NPC", "KnifeThug", "Heavy"]:
			var enemy = root.get_node_or_null(node_name)
			if enemy and enemy.visible:
				enemy_nodes.append(enemy)

	if enemy_nodes.is_empty():
		push_warning("Battle tidak dimulai: tidak ada NPC aktif.")
		return

	state = BattleState.new(MAX_HP, 0, "PLAYER")
	state.setup_npcs(enemy_nodes.size(), MAX_HP)
	state.player_potions = MAX_POTIONS

	battle_running = true
	ai_thinking = false
	next_enemy_start = 0

	# Automated planning: memastikan controller siap ketika battle dimulai
	planning_turn_counter = 0
	planning_controller.reset_for_new_battle()
	#initialize_bayesian_belief()
	planning_controller.set_planner_mode(Global.selected_pathfinding)

	# Pilih NPC hidup pertama sebagai target awal.
	selected_target_index = get_first_living_enemy()

	# Aktifkan deteksi klik melalui TargetArea.
	for enemy in enemy_nodes:
		var target_area = enemy.get_node_or_null("TargetArea") as Area2D

		if target_area == null:
			push_warning("TargetArea tidak ditemukan pada " + enemy.name)
			continue

		target_area.collision_layer = 1
		target_area.input_pickable = true

		if not target_area.has_meta("battle_click_connected"):
			target_area.input_event.connect(
				_on_target_area_input_event.bind(enemy)
			)
			target_area.set_meta("battle_click_connected", true)

	if player_idle:
		player_idle.visible = true

	if player_battle:
		player_battle.visible = false

	for enemy in enemy_nodes:
		var idle = enemy.get_node_or_null("Sprite2D")
		var battle = enemy.get_node_or_null("BattleNPC")

		if idle:
			idle.visible = true

		if battle:
			battle.visible = false

	var ui = get_parent().get_node_or_null("BattleUI")

	if ui:
		ui.show_battle()

	update_battle_ui()

	print("=== BATTLE STARTED ===")
	print("NPC in battle: ", enemy_nodes.size())
	print("Maximum attackers per round: ", MAX_ATTACKERS_PER_ROUND)


func get_first_living_enemy() -> int:
	if state == null:
		return -1

	for i in range(state.npc_hps.size()):
		if state.npc_hps[i] > 0:
			return i

	return -1


func get_living_enemy_count() -> int:
	if state == null:
		return 0

	var count := 0

	for hp in state.npc_hps:
		if hp > 0:
			count += 1

	return count

# Automated Planning: adaptor untuk membaca kondisi game
func get_planning_snapshot() -> Dictionary:
	var planning_npcs: Array[Dictionary] = []

	for i in range(enemy_nodes.size()):
		var enemy = enemy_nodes[i]

		if not is_instance_valid(enemy):
			continue

		var hp := 0

		if i < state.npc_hps.size():
			hp = state.npc_hps[i]

		planning_npcs.append({
			"npc_id": str(enemy.get_meta("planning_id", "NPC-%02d" % (i + 1))),
			"hp": hp,
			"role": str(enemy.get_meta("planning_role", "UNASSIGNED"))
		})

	return {
		"npcs": planning_npcs,
		"target_alive": state.player_hp > 0
	}

# mencari npc dari planning id
func get_enemy_index_by_planning_id(npc_id: String) -> int:
	for i in range(enemy_nodes.size()):
		var enemy = enemy_nodes[i]

		if not is_instance_valid(enemy):
			continue

		var enemy_planning_id := str(
			enemy.get_meta("planning_id", "")
		)

		if enemy_planning_id == npc_id:
			return i

	return -1

# membuat callback eksekusi planning
func execute_planning_action(action: Dictionary) -> Dictionary:
	print("EXECUTE ACTION REQUEST: ", action)
	var npc_id := str(action.get("npc", ""))
	var action_type := str(action.get("type", ""))

	if action_type not in ["NORMAL_ATTACK", "COORDINATED_ATTACK"]:
		return {
			"status": "rejected",
			"slot_completed": false,
			"battle_over": false,
			"reason": "unsupported_action_type"
		}

	if not battle_running or state == null:
		return {
			"status": "error",
			"slot_completed": false,
			"battle_over": true,
			"reason": "battle_not_running"
		}

	var index := get_enemy_index_by_planning_id(npc_id)

	if index == -1:
		return {
			"status": "rejected",
			"slot_completed": false,
			"battle_over": false,
			"reason": "npc_not_found"
		}

	if index >= state.npc_hps.size() or state.npc_hps[index] <= 0:
		return {
			"status": "rejected",
			"slot_completed": false,
			"battle_over": false,
			"reason": "npc_not_alive"
		}
		
	print("NPC EXECUTING ATTACK: ", npc_id, " | INDEX: ", index)
	
	await attack_enemy(index)
	
	#run_bayesian_update("ATTACK")
	update_battle_ui()

	return {
		"status": "executed",
		"slot_completed": true,
		"battle_over": state.player_hp <= 0 or get_living_enemy_count() <= 0,
		"reason": ""
	}
	
# Mendeteksi klik pada TargetArea NPC.
func _on_target_area_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int,
	enemy: CharacterBody2D
) -> void:

	if not battle_running or state == null:
		return

	if state.current_turn != "PLAYER" or ai_thinking:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			var index = enemy_nodes.find(enemy)

			if index < 0:
				return

			if index >= state.npc_hps.size():
				return

			if state.npc_hps[index] <= 0:
				return

			selected_target_index = index

			print("TARGET SELECTED: ", enemy.name)


func execute_action(action: Action, actor: String) -> void:
	if not battle_running or state == null or state.is_terminal():
		return

	if actor != state.current_turn or actor != "PLAYER":
		return

	match action:
		Action.ATTACK:
			await attack_player()

		Action.DEFEND:
			state.player_defending = true
			print("PLAYER defends.")

		Action.POTION:
			if state.player_potions <= 0:
				return

			if state.player_hp >= MAX_HP:
				return

			state.player_hp = min(
				MAX_HP,
				state.player_hp + POTION_HEAL
			)

			state.player_potions -= 1
			print("PLAYER uses potion. HP: ", state.player_hp)

	if not battle_running or state == null:
		return

	update_battle_ui()

	if state.player_hp <= 0 or get_living_enemy_count() <= 0:
		finish_battle()
		return

	state.current_turn = "NPC"
	update_battle_ui()
	call_deferred("_run_npc_turn")


# Player menyerang NPC yang dipilih.
func attack_player() -> void:
	var target := selected_target_index

	if target < 0 or target >= state.npc_hps.size():
		target = get_first_living_enemy()

	if target < 0:
		return

	if state.npc_hps[target] <= 0:
		target = get_first_living_enemy()

	if target < 0:
		return

	await play_player_attack_animation()

	if not battle_running or state == null:
		return

	if state.npc_hps[target] <= 0:
		selected_target_index = get_first_living_enemy()
		return

	var damage := ATTACK_DAMAGE

	if state.npc_defendings[target]:
		damage = int(damage * DEFEND_REDUCTION)
		state.npc_defendings[target] = false

	state.npc_hps[target] = max(
		0,
		state.npc_hps[target] - damage
	)

	print(
		"PLAYER attacks enemy ",
		target + 1,
		" for ",
		damage,
		" damage. HP left: ",
		state.npc_hps[target]
	)

	# Jika target mati, pindah ke NPC hidup berikutnya.
	if state.npc_hps[target] <= 0:
		selected_target_index = get_first_living_enemy()

		print(
			"TARGET DEFEATED. NEW TARGET: ",
			selected_target_index
		)


func _run_npc_turn() -> void:
	if not battle_running or state == null:
		return

	if state.current_turn != "NPC" or ai_thinking:
		return

	ai_thinking = true
	update_battle_ui()

	print("=== NPC TURN: AI EVALUATION ===")

	# 1. MDP: ADVISORY / DIAGNOSTIC
	var mdp_adapter = MDPAdapter.new()
	last_mdp_result = mdp_adapter.run_value_iteration(state)

	print("=== MDP VALUE ITERATION ===")
	print("MDP RESULT: ", last_mdp_result)

	# 2. MINIMAX
	last_minimax_result = BattleAI.new(
		"minimax", 3
	).get_best_action(state, evaluation)

	print("=== MINIMAX RESULT ===")
	print(last_minimax_result)

	# 3. ALPHA-BETA
	last_alpha_beta_result = BattleAI.new(
		"alpha_beta", 3
	).get_best_action(state, evaluation)

	print("=== ALPHA-BETA RESULT ===")
	print(last_alpha_beta_result)

	if not battle_running or state == null:
		ai_thinking = false
		return

	# 4. AUTOMATED PLANNING
	#    GAMEPLAY EXECUTOR
	print("=== PLANNING AI MODE ===")

	planning_turn_counter += 1

	var snapshot_debug = get_planning_snapshot()

	print("=== SNAPSHOT DEBUG ===")
	print(snapshot_debug)
	print("NPC SNAPSHOT COUNT: ", snapshot_debug.get("npcs", []).size())
	print("TARGET ALIVE: ", snapshot_debug.get("target_alive", false))

	var planning_result: Dictionary = await planning_controller.run_npc_phase(
		planning_turn_counter,
		Callable(self, "get_planning_snapshot"),
		Callable(self, "_run_inference_for_action"),
		Callable(self, "execute_planning_action"),
		false,
		[],
		-1
	)

	print("PLANNING EXECUTION RESULT: ", planning_result)
	
	# Refresh MEU after NPC phase has completed.
	#if planning_controller != null:
		#var meu_refresh_result: Dictionary = planning_controller.refresh_uncertainty_advisory()
		#print("MEU REFRESH RESULT: ", meu_refresh_result)

	ai_thinking = false

	if not battle_running or state == null:
		return

	if state.player_hp <= 0 or get_living_enemy_count() <= 0:
		finish_battle()
		return

	# 5. RETURN TO PLAYER TURN
	state.current_turn = "PLAYER"
	update_battle_ui()

	print("=== NPC PLANNING DEBUG ===")
	print("TURN COUNTER: ", planning_turn_counter)
	print("CURRENT TURN: ", state.current_turn)
	print("PLANNING RESULT: ", planning_result)

	print("=== PLAYER TURN ===")


func attack_enemy(index: int) -> void:
	if index < 0 or index >= enemy_nodes.size():
		return

	if index >= state.npc_hps.size() or state.npc_hps[index] <= 0:
		return

	var enemy = enemy_nodes[index]

	if not is_instance_valid(enemy):
		return

	await play_enemy_attack_animation(enemy)

	if not battle_running or state == null:
		return

	var damage := ATTACK_DAMAGE

	if state.player_defending:
		damage = int(damage * DEFEND_REDUCTION)
		state.player_defending = false

	state.player_hp = max(
		0,
		state.player_hp - damage
	)

	print(
		"Enemy ",
		index + 1,
		" attacks PLAYER for ",
		damage,
		" damage. Player HP: ",
		state.player_hp
	)


func play_enemy_attack_animation(enemy: Node) -> void:
	var idle = enemy.get_node_or_null("Sprite2D")
	var battle = enemy.get_node_or_null("BattleNPC")

	if battle == null:
		if attack_sound:
			attack_sound.play()
		return

	if idle:
		idle.visible = false

	battle.visible = true
	battle.stop()
	battle.frame = 0
	battle.play("Attack")

	if attack_sound:
		attack_sound.play()

	await battle.animation_finished

	battle.stop()
	battle.visible = false

	if idle:
		idle.visible = true


func play_player_attack_animation() -> void:
	if player_battle == null:
		if attack_sound:
			attack_sound.play()
		return

	if player_idle:
		player_idle.visible = false

	player_battle.visible = true
	player_battle.stop()
	player_battle.frame = 0
	player_battle.play("Attack")

	if attack_sound:
		attack_sound.play()

	await player_battle.animation_finished

	player_battle.stop()
	player_battle.visible = false

	if player_idle:
		player_idle.visible = true


func finish_battle() -> void:
	if state == null:
		return

	battle_running = false
	ai_thinking = false
	update_battle_ui()

	var ui = get_parent().get_node_or_null("BattleUI")

	if ui:
		if state.player_hp <= 0 and get_living_enemy_count() <= 0:
			ui.show_battle_result("DRAW!")
		elif get_living_enemy_count() <= 0:
			ui.show_battle_result("VICTORY!")
		else:
			ui.show_battle_result("DEFEAT!")

	print("=== BATTLE FINISHED ===")


func update_battle_ui() -> void:
	var ui = get_parent().get_node_or_null("BattleUI")

	if ui:
		ui.update_ui()


func _input(event: InputEvent) -> void:
	if not battle_running or state == null:
		return

	if state.current_turn != "PLAYER" or state.is_terminal():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				execute_action(Action.ATTACK, "PLAYER")

			KEY_D:
				execute_action(Action.DEFEND, "PLAYER")

			KEY_P:
				execute_action(Action.POTION, "PLAYER")

func execute_mdp_action(action: String) -> void:
	if not battle_running or state == null:
		return

	match action:
		"ATTACK":
			var target_index := -1

			# Cari NPC hidup pertama
			for i in range(state.npc_hps.size()):
				if state.npc_hps[i] > 0:
					target_index = i
					break

			if target_index != -1:
				print("MDP DECISION: ATTACK")
				await attack_enemy(target_index)

		"DEFEND":
			print("MDP DECISION: DEFEND")

			# Semua NPC hidup memasuki kondisi defend
			for i in range(state.npc_hps.size()):
				if state.npc_hps[i] > 0:
					state.npc_defendings[i] = true

	update_battle_ui()

# INFERENCE
func _run_inference_for_action(action: Dictionary) -> Dictionary:
	if inference_engine == null or planning_controller == null:
		return {}

	var planning_state: Dictionary = planning_controller.get_current_state()

	var npc_id := str(action.get("npc", ""))
	var turn := planning_turn_counter
	var facts: Array[Dictionary] = []

	var roles: Dictionary = planning_state.get("roles", {})
	var alive_npcs: Array = planning_state.get("alive", [])
	var resolved_npcs: Array = planning_state.get("resolved", [])
	var coord_used: Array = planning_state.get("coord_used", [])

	var leader_id := ""

	for id in roles:
		if str(roles[id]) == "LEADER":
			leader_id = str(id)
			break

	# Fakta NPC
	for i in range(enemy_nodes.size()):
		var enemy = enemy_nodes[i]

		if not is_instance_valid(enemy):
			continue

		var id := str(enemy.get_meta(
			"planning_id",
			"NPC-%02d" % (i + 1)
		))

		var hp := 0

		if i < state.npc_hps.size():
			hp = state.npc_hps[i]

		facts.append({
			"predicate": "alive",
			"subject": id
		} if hp > 0 else {
			"predicate": "dead",
			"subject": id
		})

		facts.append({
			"predicate": "role",
			"subject": id,
			"value": str(roles.get(id, "UNASSIGNED"))
		})

		facts.append({
			"predicate": "hp",
			"subject": id,
			"value": hp
		})

		facts.append({
			"predicate": "max_hp",
			"subject": id,
			"value": MAX_HP
		})

		if id == npc_id:
			facts.append({
				"predicate": "has_turn",
				"subject": id,
				"turn": turn
			})

		if resolved_npcs.has(id):
			facts.append({
				"predicate": "acted",
				"subject": id,
				"turn": turn
			})

		if coord_used.has(id):
			facts.append({
				"predicate": "coordination_used",
				"subject": id,
				"turn": turn
			})

	# Fakta target
	if state.player_hp > 0:
		facts.append({
			"predicate": "target_alive",
			"subject": "player"
		})

	# Fakta serangan Leader
	if leader_id != "" and planning_state.get("leader_attacked", false):
		facts.append({
			"predicate": "ally_attacked",
			"subject": leader_id,
			"turn": turn
		})

	# WAIT belum diaktifkan dalam konfigurasi planning saat ini.
	var wait_supported := false

	var result: Dictionary = inference_engine.infer(
		facts,
		npc_id,
		turn,
		wait_supported
	)

	last_inference_result = result

	print("=== INFERENCE RESULT ===")
	print(result)

	return result

# SET PLANNER MODE
func set_planner_mode(mode: String) -> void:
	if mode == Planner.MODE_UCS or mode == Planner.MODE_ASTAR:
		planning_controller.planner_mode = mode
		print("PLANNER MODE SET TO: ", mode)
	else:
		push_warning("Invalid planner mode: " + mode)


#const BAYES_PRIOR := {
	#"AGGRESSIVE": 0.5,
	#"CAUTIOUS": 0.5
#}
#
#const BAYES_LIKELIHOOD := {
	#"AGGRESSIVE": {
		#"ATTACK": 0.8,
		#"DEFEND": 0.2
	#},
	#"CAUTIOUS": {
		#"ATTACK": 0.3,
		#"DEFEND": 0.7
	#}
#}

#func initialize_bayesian_belief() -> void:
	#var prior_result: Dictionary = uncertainty_belief.create_belief(
		#BAYES_PRIOR,
		#0.000001,
		#"INITIAL_PRIOR",
		#0
	#)
#
	#if prior_result.get("valid", false):
		#active_bayesian_belief = prior_result.get("data", {}).get("belief", {})
		#last_bayesian_status = "INITIALIZED"
	#else:
		#last_bayesian_status = "INIT_FAILED"
		#print("Bayesian prior init failed: ", prior_result)
#
#
#func run_bayesian_update(evidence: String) -> void:
	#if active_bayesian_belief.is_empty():
		#initialize_bayesian_belief()
#
	#var result: Dictionary = bayes_updater.update_belief(
		#active_bayesian_belief,
		#BAYES_LIKELIHOOD,
		#evidence,
		#planning_turn_counter,
		#0.000001
	#)
#
	#last_bayesian_result = result
	#last_bayesian_evidence = evidence
#
	#if result.get("valid", false):
		#active_bayesian_belief = result.get(
			#"data", {}
		#).get("posterior", {}).duplicate(true)
		#last_bayesian_status = "UPDATED"
	#else:
		#last_bayesian_status = "FAILED"
#
	#print("=== BAYESIAN UPDATE ===")
	#print(result)
