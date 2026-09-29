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

func _ready():
	battle_panel.visible = false
	result_label.visible = false

	battle_system = get_parent().get_node_or_null("BattleSystem")

	if battle_system == null:
		print("ERROR: BattleSystem tidak ditemukan!")
		return

	# Tombol UI langsung kita sambungkan ke aksi battle.
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	potion_button.pressed.connect(_on_potion_pressed)
	print("BATTLE UI READY")

func show_battle():
	battle_panel.visible = true
	result_label.visible = false
	update_ui()

func hide_battle():
	battle_panel.visible = false

func update_ui():
	if battle_system == null or battle_system.state == null:
		return

	# HP UI selalu mengikuti kondisi battle yang sebenarnya.
	player_hp.value = battle_system.state.player_hp
	npc_hp.value = battle_system.state.npc_hp

	if battle_system.state.current_turn == "PLAYER":
		turn_label.text = "YOUR TURN"
	else:
		turn_label.text = "THE RIPPER'S TURN"

	update_buttons()
	update_potion_display()

func update_buttons():
	if battle_system == null or battle_system.state == null:
		return

	var player_turn = battle_system.state.current_turn == "PLAYER"
	var battle_over = battle_system.state.is_terminal()

	attack_button.disabled = not player_turn or battle_over
	defend_button.disabled = not player_turn or battle_over
	potion_button.disabled = not player_turn or battle_over or battle_system.state.player_potions <= 0

func update_potion_display():
	if battle_system == null or battle_system.state == null:
		return

	# Angka di tombol menunjukkan sisa Potion Player.
	potion_button.text = "POTION (" + str(battle_system.state.player_potions) + ")"

func show_battle_result(result: String):
	result_label.text = result
	result_label.visible = true

	# Setelah hasil muncul, tombol battle tidak bisa digunakan lagi.
	attack_button.disabled = true
	defend_button.disabled = true
	potion_button.disabled = true

func _on_attack_pressed():
	battle_system.execute_action(battle_system.Action.ATTACK,"PLAYER")
	update_ui()

func _on_defend_pressed():
	battle_system.execute_action(battle_system.Action.DEFEND,"PLAYER")
	update_ui()

func _on_potion_pressed():
	battle_system.execute_action(battle_system.Action.POTION,"PLAYER")
	update_ui()
