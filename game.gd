extends Node2D


const SAFE_HOUSE_CELL = Vector2i(30, 16)
const SAFE_HOUSE_DISTANCE = 20.0
const CATCH_DISTANCE = 30.0
const BATTLE_TRIGGER_DISTANCE = 120.0

var player
var npc
var game_over = false
var game_message
var battle_system
var battle_started = false


func _ready():
	player = get_node("Player")
	npc = get_node("NPC")
	battle_system = get_node("BattleSystem")
	game_message = get_node("CanvasLayer/GameMessage")

	game_message.text = ""


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
	game_message.text = message

	player.set_physics_process(false)
	npc.set_physics_process(false)
	
func check_battle_trigger():
	if battle_started:
		return

	var distance = player.position.distance_to(npc.position)

	if distance <= BATTLE_TRIGGER_DISTANCE:
		battle_started = true
		battle_system.start_battle()
		
		player.set_physics_process(false)
		npc.set_physics_process(false)
		
		print("=== BATTLE TRIGGERED ===")
