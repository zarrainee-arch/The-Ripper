
extends CanvasLayer

var battle_system

@onready var battle_panel = $BattlePanel
@onready var player_hp = $BattlePanel/PlayerInfo/PlayerDetails/PlayerStats/PlayerHP
@onready var npc_hp = $BattlePanel/NPCInfo/NPCDetails/NPCStats/NPCHP
@onready var turn_label = $BattlePanel/TurnLabel
@onready var result_label = $ResultLabel
@onready var attack_button = $BattlePanel/ActionButtons/AttackButton
@onready var defend_button = $BattlePanel/ActionButtons/DefendButton
@onready var potion_button = $BattlePanel/ActionButtons/PotionButton


func _ready() -> void:
	battle_panel.visible = false
	result_label.visible = false

	battle_system = get_parent().get_node_or_null("BattleSystem")

	if battle_system == null:
		push_error("BattleSystem tidak ditemukan!")
		return

	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	potion_button.pressed.connect(_on_potion_pressed)

	print("BATTLE UI READY")


func show_battle() -> void:
	battle_panel.visible = true
	result_label.visible = false
	update_ui()


func hide_battle() -> void:
	battle_panel.visible = false


func update_ui() -> void:
	if battle_system == null or battle_system.state == null:
		return

	var state = battle_system.state
	player_hp.value = state.player_hp

	var enemy_index = battle_system.get_first_living_enemy()

	if enemy_index >= 0:
		npc_hp.value = state.npc_hps[enemy_index]
	else:
		npc_hp.value = 0

	var enemies_left = battle_system.get_living_enemy_count()

	if state.current_turn == "PLAYER":
		turn_label.text = "YOUR TURN | Enemies left: " + str(enemies_left)
	else:
		turn_label.text = "THE RIPPER'S TURN | Enemies left: " + str(enemies_left)

	update_buttons()
	update_potion_display()


func update_buttons() -> void:
	if battle_system == null or battle_system.state == null:
		return

	var state = battle_system.state
	var player_turn = state.current_turn == "PLAYER"
	var battle_over = state.is_terminal() or not battle_system.battle_running

	attack_button.disabled = not player_turn or battle_over
	defend_button.disabled = not player_turn or battle_over
	potion_button.disabled = (
		not player_turn
		or battle_over
		or state.player_potions <= 0
	)


func update_potion_display() -> void:
	if battle_system == null or battle_system.state == null:
		return

	potion_button.text = "POTION (" + str(battle_system.state.player_potions) + ")"


func show_battle_result(result: String) -> void:
	result_label.text = result
	result_label.visible = true

	attack_button.disabled = true
	defend_button.disabled = true
	potion_button.disabled = true


func _on_attack_pressed() -> void:
	if battle_system:
		battle_system.execute_action(battle_system.Action.ATTACK, "PLAYER")


func _on_defend_pressed() -> void:
	if battle_system:
		battle_system.execute_action(battle_system.Action.DEFEND, "PLAYER")

func _on_potion_pressed() -> void:
	if battle_system:
		battle_system.execute_action(battle_system.Action.POTION, "PLAYER")
