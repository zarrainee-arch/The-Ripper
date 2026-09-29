extends CanvasLayer

@onready var npc = get_parent().get_node("NPC")
@onready var game = get_parent()
@onready var battle_system = get_parent().get_node_or_null("BattleSystem")

var panel: PanelContainer
var label: Label

func _ready():
	panel = PanelContainer.new()
	panel.position = Vector2(15,15)
	panel.custom_minimum_size = Vector2(350,0)
	add_child(panel)

	# Panel hitam transparan biar teks tetap kebaca.
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0,0.0,0.0,0.72)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)

	label = Label.new()
	label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)

func _process(_delta):
	if npc == null:
		return

	if game != null and game.battle_started:
		show_battle_debug()
	else:
		show_pathfinding_debug()

func show_pathfinding_debug():
	var mode = npc.get_mode_name()
	var status = npc.path_status
	var total_cost = npc.total_path_cost
	var total_path_nodes = npc.total_path_nodes
	var total_expanded = npc.total_expanded_nodes
	var total_replans = npc.total_replans
	var last_start = npc.last_start_cell
	var last_goal = npc.last_goal_cell

	label.text = (
		"PATHFINDING DEBUG\n"
		+ "──────────────────────────\n"
		+ "Algorithm        " + mode + "\n"
		+ "Status           " + status + "\n"
		+ "\n"
		+ "Total Path Cost  " + str(total_cost) + "\n"
		+ "Total Path Nodes " + str(total_path_nodes) + "\n"
		+ "Total Expanded   " + str(total_expanded) + "\n"
		+ "Total Replans    " + str(total_replans) + "\n"
		+ "\n"
		+ "Last Start       " + str(last_start) + "\n"
		+ "Last Goal        " + str(last_goal)
	)

func show_battle_debug():
	if battle_system == null:
		label.text = "BATTLE AI DEBUG\nBattleSystem tidak ditemukan."
		return

	var minimax = battle_system.last_minimax_result
	var alpha_beta = battle_system.last_alpha_beta_result

	var text = (
		"BATTLE AI DEBUG\n"
		+ "──────────────────────────\n"
	)

	if minimax != null:
		text += (
			"MINIMAX\n"
			+ "Best Action      " + str(minimax.best_action) + "\n"
			+ "Score            " + str(minimax.best_score) + "\n"
			+ "Depth            " + str(minimax.depth) + "\n"
			+ "Nodes            " + str(minimax.node_count) + "\n"
			+ "Time             " + str(minimax.execution_time_ms) + " ms\n"
			+ "\n"
		)
	else:
		text += "MINIMAX\nWaiting for AI...\n\n"

	if alpha_beta != null:
		text += (
			"ALPHA-BETA\n"
			+ "Best Action      " + str(alpha_beta.best_action) + "\n"
			+ "Score            " + str(alpha_beta.best_score) + "\n"
			+ "Depth            " + str(alpha_beta.depth) + "\n"
			+ "Nodes            " + str(alpha_beta.node_count) + "\n"
			+ "Time             " + str(alpha_beta.execution_time_ms) + " ms"
		)
	else:
		text += "ALPHA-BETA\nWaiting for AI..."

	label.text = text
