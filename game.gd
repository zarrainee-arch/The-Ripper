extends Node2D

const SAFE_HOUSE_CELL = Vector2i(30,16)
const SAFE_HOUSE_DISTANCE = 20.0
const CATCH_DISTANCE = 30.0
const BATTLE_TRIGGER_DISTANCE = 120.0

var player
var npc
var game_over = false
var game_message
var battle_system
var battle_ui
var battle_started = false
var player_original_position
var npc_original_position

func _ready():
	player = get_node("Player")
	npc = get_node("NPC")
	battle_system = get_node("BattleSystem")
	battle_ui = get_node("BattleUI")
	game_message = get_node_or_null("CanvasLayer/GameMessage")

	# Sprite attack jangan muncul sebelum dipakai.
	var battle_player = player.get_node_or_null("BattlePlayer")
	var battle_npc = npc.get_node_or_null("BattleNPC")
	if battle_player != null:
		battle_player.visible = false
	if battle_npc != null:
		battle_npc.visible = false

	if game_message != null:
		game_message.text = ""

	print("GAME READY")
	print("BattleSystem: ",battle_system)
	print("BattleUI: ",battle_ui)

func _process(_delta):
	if game_over:
		return

	check_battle_trigger()
	if game_over:
		return

	check_lose()
	if game_over:
		return

	check_win()

func check_win():
	var grid = get_node("Grid")
	var safe_house_position = grid.cell_to_world(SAFE_HOUSE_CELL)

	if player.position.distance_to(safe_house_position) <= SAFE_HOUSE_DISTANCE:
		end_game("YOU ESCAPED!")

func check_lose():
	if battle_started:
		return

	if player.position.distance_to(npc.position) <= CATCH_DISTANCE:
		end_game("YOU GOT CAUGHT!")

func end_game(message):
	game_over = true

	if game_message != null:
		game_message.text = message

	player.set_physics_process(false)
	npc.set_physics_process(false)

func check_battle_trigger():
	if battle_started:
		return

	var distance = player.position.distance_to(npc.position)

	if distance <= BATTLE_TRIGGER_DISTANCE:
		battle_started = true

		player_original_position = player.global_position
		npc_original_position = npc.global_position

		# Dekatkan mereka untuk posisi duel.
		set_battle_positions()

		# BattleSystem yang mengatur sprite idle dan attack.
		battle_system.start_battle()
		battle_ui.show_battle()

		player.set_physics_process(false)
		npc.set_physics_process(false)

		print("=== BATTLE TRIGGERED ===")

func set_battle_positions():
	var direction = (npc.global_position - player.global_position).normalized()

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var center = (player.global_position + npc.global_position) / 2.0

	player.global_position = center - direction * 25.0
	npc.global_position = center + direction * 25.0
