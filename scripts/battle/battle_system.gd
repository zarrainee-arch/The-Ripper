class_name BattleSystem
extends Node

enum Action {
	ATTACK,
	DEFEND,
	POTION
}

const MAX_HP = 100
const ATTACK_DAMAGE = 5
const DEFEND_REDUCTION = 0.5
const POTION_HEAL = 10
const MAX_POTIONS = 3

var state: BattleState
var battle_ai: BattleAI
var evaluation
var ai_thinking = false
var last_minimax_result
var last_alpha_beta_result

var player_idle
var npc_idle
var battle_player
var battle_npc
var attack_sound

func _ready():
	battle_ai = BattleAI.new("minimax",3)
	var evaluation_script = preload("res://scripts/battle_evaluation.gd")
	evaluation = evaluation_script.new()

	var player = get_parent().get_node_or_null("Player")
	var npc = get_parent().get_node_or_null("NPC")

	if player != null:
		player_idle = player.get_node_or_null("Sprite2D")
		battle_player = player.get_node_or_null("BattlePlayer")

	if npc != null:
		npc_idle = npc.get_node_or_null("Sprite2D")
		battle_npc = npc.get_node_or_null("BattleNPC")

	# Ambil AudioStreamPlayer AttackSFX dari Game.
	attack_sound = get_parent().get_node_or_null("AttackSFX")

	if battle_player != null:
		battle_player.visible = false

	if battle_npc != null:
		battle_npc.visible = false

func start_battle():
	state = BattleState.new(MAX_HP,MAX_HP,"PLAYER")
	state.player_potions = MAX_POTIONS
	state.npc_potions = MAX_POTIONS
	ai_thinking = false

	# Saat battle mulai, pakai sprite idle sebagai posisi normal.
	if player_idle != null:
		player_idle.visible = true
	if npc_idle != null:
		npc_idle.visible = true
	if battle_player != null:
		battle_player.visible = false
	if battle_npc != null:
		battle_npc.visible = false

	update_battle_ui()

func execute_action(action: Action,actor: String):
	if state == null or state.is_terminal() or actor != state.current_turn:
		return

	match action:
		Action.ATTACK:
			await attack(actor)
		Action.DEFEND:
			defend(actor)
		Action.POTION:
			potion(actor)

	if state.is_terminal():
		update_battle_ui()

		var battle_ui = get_parent().get_node_or_null("BattleUI")

		if battle_ui != null:
			if state.player_hp <= 0 and state.npc_hp <= 0:
				battle_ui.show_battle_result("DRAW!")
			elif state.npc_hp <= 0:
				battle_ui.show_battle_result("VICTORY!")
			elif state.player_hp <= 0:
				battle_ui.show_battle_result("DEFEAT!")

		print("=== BATTLE FINISHED ===")
		return

	change_turn()
	update_battle_ui()

	if state.current_turn == "NPC":
		call_deferred("_run_npc_turn")

func attack(actor: String):
	var damage = ATTACK_DAMAGE

	if actor == "PLAYER":
		await play_attack_animation("PLAYER")

		if state.npc_defending:
			damage = int(damage * DEFEND_REDUCTION)
			state.npc_defending = false

		state.npc_hp = max(0,state.npc_hp - damage)
		print("PLAYER attacks NPC for ",damage," damage.")

	elif actor == "NPC":
		await play_attack_animation("NPC")

		if state.player_defending:
			damage = int(damage * DEFEND_REDUCTION)
			state.player_defending = false

		state.player_hp = max(0,state.player_hp - damage)
		print("NPC attacks PLAYER for ",damage," damage.")

func play_attack_animation(actor: String):
	var idle_sprite
	var battle_sprite

	if actor == "PLAYER":
		idle_sprite = player_idle
		battle_sprite = battle_player
	else:
		idle_sprite = npc_idle
		battle_sprite = battle_npc

	if battle_sprite == null:
		return

	# Idle disembunyikan selama serangan supaya tidak ada sprite kembar.
	if idle_sprite != null:
		idle_sprite.visible = false

	battle_sprite.visible = true
	battle_sprite.stop()
	battle_sprite.frame = 0
	battle_sprite.play("Attack")

	# Mainkan suara sword tepat saat animasi attack dimulai.
	if attack_sound != null:
		attack_sound.play()

	await battle_sprite.animation_finished

	battle_sprite.stop()
	battle_sprite.visible = false

	# Setelah serangan selesai, balik ke idle.
	if idle_sprite != null:
		idle_sprite.visible = true

func defend(actor: String):
	if actor == "PLAYER":
		state.player_defending = true
		print("PLAYER defends.")
	elif actor == "NPC":
		state.npc_defending = true
		print("NPC defends.")

func potion(actor: String):
	if actor == "PLAYER":
		if state.player_potions <= 0:
			return
		state.player_hp = min(MAX_HP,state.player_hp + POTION_HEAL)
		state.player_potions -= 1
		print("PLAYER uses potion. Remaining: ",state.player_potions)

	elif actor == "NPC":
		if state.npc_potions <= 0:
			return
		state.npc_hp = min(MAX_HP,state.npc_hp + POTION_HEAL)
		state.npc_potions -= 1
		print("NPC uses potion. Remaining: ",state.npc_potions)

func change_turn():
	if state.current_turn == "PLAYER":
		state.current_turn = "NPC"
	else:
		state.current_turn = "PLAYER"
	print("Next turn: ",state.current_turn)

func _run_npc_turn():
	if state == null or state.is_terminal() or state.current_turn != "NPC":
		return

	if ai_thinking:
		return

	ai_thinking = true
	update_battle_ui()

	await get_tree().create_timer(0.7).timeout

	if state == null or state.is_terminal() or state.current_turn != "NPC":
		ai_thinking = false
		return

	print("=== NPC AI THINKING ===")

	var minimax_ai = BattleAI.new("minimax",3)
	var alpha_beta_ai = BattleAI.new("alpha_beta",3)

	last_minimax_result = minimax_ai.get_best_action(state,evaluation)
	last_alpha_beta_result = alpha_beta_ai.get_best_action(state,evaluation)

	print("=== MINIMAX ===")
	print("Action: ",last_minimax_result.best_action)
	print("Score: ",last_minimax_result.best_score)
	print("Nodes: ",last_minimax_result.node_count)
	print("Time: ",last_minimax_result.execution_time_ms," ms")

	print("=== ALPHA-BETA ===")
	print("Action: ",last_alpha_beta_result.best_action)
	print("Score: ",last_alpha_beta_result.best_score)
	print("Nodes: ",last_alpha_beta_result.node_count)
	print("Time: ",last_alpha_beta_result.execution_time_ms," ms")

	var result = battle_ai.get_best_action(state,evaluation)

	print("=== NPC DECISION ===")
	print("Algorithm: ",result.algorithm)
	print("Action: ",result.best_action)

	if result.best_action != null:
		await execute_action(result.best_action,"NPC")

	ai_thinking = false

func update_battle_ui():
	var battle_ui = get_parent().get_node_or_null("BattleUI")
	if battle_ui != null:
		battle_ui.update_ui()

func _input(event):
	if state == null or state.is_terminal() or state.current_turn != "PLAYER":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				await execute_action(Action.ATTACK,"PLAYER")
			KEY_D:
				execute_action(Action.DEFEND,"PLAYER")
			KEY_P:
				execute_action(Action.POTION,"PLAYER")
