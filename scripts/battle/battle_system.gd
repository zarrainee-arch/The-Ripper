
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


func _ready() -> void:
	battle_ai = BattleAI.new("minimax", 3)

	var evaluation_script = preload("res://scripts/battle_evaluation.gd")
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


func attack_player() -> void:
	var target := get_first_living_enemy()

	if target < 0:
		return

	# Animasi serangan pemain.
	await play_player_attack_animation()

	if not battle_running or state == null:
		return
	if state.npc_hps[target] <= 0:
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


func _run_npc_turn() -> void:
	if not battle_running or state == null:
		return
	if state.current_turn != "NPC" or ai_thinking:
		return

	ai_thinking = true
	update_battle_ui()

	await get_tree().create_timer(0.5).timeout

	if not battle_running or state == null:
		ai_thinking = false
		return

	# Tetap jalankan evaluasi kedua algoritma untuk eksperimen AI.
	last_minimax_result = BattleAI.new(
		"minimax", 3
	).get_best_action(state, evaluation)

	last_alpha_beta_result = BattleAI.new(
		"alpha_beta", 3
	).get_best_action(state, evaluation)

	var living_count := get_living_enemy_count()
	var attack_limit := mini(
		MAX_ATTACKERS_PER_ROUND,
		living_count
	)

	var attackers := 0
	var checked := 0
	var total_enemies := enemy_nodes.size()

	# Rotasi urutan penyerang agar NPC belakang tidak selalu dilewati.
	while checked < total_enemies and attackers < attack_limit:
		if not battle_running or state == null:
			break
		if state.player_hp <= 0:
			break

		var index := (next_enemy_start + checked) % total_enemies
		checked += 1

		if index >= state.npc_hps.size():
			continue
		if state.npc_hps[index] <= 0:
			continue

		await get_tree().create_timer(NPC_ATTACK_DELAY).timeout

		if not battle_running or state == null:
			break
		if state.player_hp <= 0:
			break
		if state.npc_hps[index] <= 0:
			continue

		await attack_enemy(index)
		attackers += 1
		update_battle_ui()

	next_enemy_start = (next_enemy_start + 1) % max(1, total_enemies)
	ai_thinking = false

	if not battle_running or state == null:
		return

	if state.player_hp <= 0 or get_living_enemy_count() <= 0:
		finish_battle()
		return

	state.current_turn = "PLAYER"
	update_battle_ui()

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
