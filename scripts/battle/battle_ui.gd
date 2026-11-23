
extends CanvasLayer

var battle_system

# HP Player yang tampil di atas karakter
@onready var player_world_hp = $"../Player/HealthBar"

# UI lama
@onready var battle_panel = $BattlePanel
@onready var result_label = $ResultLabel

# Tombol baru berbentuk PNG
@onready var action_buttons = $ActionButtons
@onready var attack_button: TextureButton = $ActionButtons/TextureButton
@onready var defend_button: TextureButton = $ActionButtons/TextureButton2
@onready var potion_button: TextureButton = $ActionButtons/TextureButton3


func _ready() -> void:
	# Sembunyikan UI saat eksplorasi
	battle_panel.visible = false
	action_buttons.visible = false
	result_label.visible = false

	# Hubungkan BattleSystem
	battle_system = get_parent().get_node_or_null("BattleSystem")

	if battle_system == null:
		push_error("BattleSystem tidak ditemukan!")
		return

	# Hubungkan tombol baru ke action battle
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	potion_button.pressed.connect(_on_potion_pressed)

	print("BATTLE UI READY")


# ==========================================
# BATTLE VISIBILITY
# ==========================================

func show_battle() -> void:
	battle_panel.visible = false
	action_buttons.visible = true
	result_label.visible = false

	update_ui()


func hide_battle() -> void:
	battle_panel.visible = false
	action_buttons.visible = false


# ==========================================
# UPDATE UI
# ==========================================

func update_ui() -> void:
	if battle_system == null or battle_system.state == null:
		return

	var state = battle_system.state

	# Update HP Player
	if player_world_hp != null:
		player_world_hp.value = state.player_hp

	# Update HP setiap NPC
	var enemies = get_parent().npcs

	for i in range(enemies.size()):
		if i >= state.npc_hps.size():
			break

		var enemy = enemies[i]
		var enemy_hp_bar = enemy.get_node_or_null("HealthBar") as ProgressBar

		if enemy_hp_bar != null:
			enemy_hp_bar.value = state.npc_hps[i]

	update_buttons()
	update_potion_display()


# ==========================================
# BUTTON STATE
# ==========================================

func update_buttons() -> void:
	if battle_system == null or battle_system.state == null:
		return

	var state = battle_system.state

	var player_turn = state.current_turn == "PLAYER"
	var battle_over = (
		state.is_terminal()
		or not battle_system.battle_running
	)

	var can_act = player_turn and not battle_over and not battle_system.ai_thinking

	attack_button.disabled = not can_act
	defend_button.disabled = not can_act

	potion_button.disabled = (
		not can_act
		or state.player_potions <= 0
	)


func update_potion_display() -> void:
	if battle_system == null or battle_system.state == null:
		return

	var potion_count = battle_system.state.player_potions

	potion_button.tooltip_text = "Potion (" + str(potion_count) + ")"


# ==========================================
# BATTLE RESULT
# ==========================================

func show_battle_result(result: String) -> void:
	result_label.text = result
	result_label.visible = true

	# Battle selesai, sembunyikan tombol aksi
	action_buttons.visible = false


# ==========================================
# PLAYER ACTIONS
# ==========================================

func _on_attack_pressed() -> void:
	if battle_system == null:
		return

	if not battle_system.battle_running:
		return

	battle_system.execute_action(
		battle_system.Action.ATTACK,
		"PLAYER"
	)


func _on_defend_pressed() -> void:
	if battle_system == null:
		return

	if not battle_system.battle_running:
		return

	battle_system.execute_action(
		battle_system.Action.DEFEND,
		"PLAYER"
	)


func _on_potion_pressed() -> void:
	if battle_system == null:
		return

	if not battle_system.battle_running:
		return

	battle_system.execute_action(
		battle_system.Action.POTION,
		"PLAYER"
	)
