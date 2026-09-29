extends CanvasLayer


@onready var npc = get_parent().get_node("NPC")


var panel: PanelContainer
var label: Label


func _ready():

	# ==========================================
	# PANEL
	# ==========================================

	panel = PanelContainer.new()

	panel.position = Vector2(15, 15)

	panel.custom_minimum_size = Vector2(350, 0)

	add_child(panel)


	# ==========================================
	# BACKGROUND HITAM TRANSPARAN
	# ==========================================

	var style = StyleBoxFlat.new()

	style.bg_color = Color(
		0.0,
		0.0,
		0.0,
		0.72
	)

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12

	panel.add_theme_stylebox_override(
		"panel",
		style
	)


	# ==========================================
	# LABEL
	# ==========================================

	label = Label.new()

	label.add_theme_font_size_override(
		"font_size",
		17
	)

	label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	label.autowrap_mode = TextServer.AUTOWRAP_OFF

	panel.add_child(label)


func _process(_delta):

	if npc == null:
		return


	# ==========================================
	# DATA NPC
	# ==========================================

	var mode = npc.get_mode_name()

	var status = npc.path_status


	# STATISTIK CUMULATIVE
	var total_cost = npc.total_path_cost

	var total_path_nodes = npc.total_path_nodes

	var total_expanded = npc.total_expanded_nodes

	var total_replans = npc.total_replans


	# SEARCH TERAKHIR
	var last_start = npc.last_start_cell

	var last_goal = npc.last_goal_cell


	# ==========================================
	# FORMAT COST
	# ==========================================

	var cost_text = str(total_cost)


	# ==========================================
	# TEXT
	# ==========================================

	label.text = (
		"PATHFINDING DEBUG\n"
		+ "──────────────────────────\n"
		+ "\n"
		+ "Algorithm        " + mode + "\n"
		+ "Status           " + status + "\n"
		+ "\n"
		+ "Total Path Cost  " + cost_text + "\n"
		+ "Total Path Nodes " + str(total_path_nodes) + "\n"
		+ "Total Expanded   " + str(total_expanded) + "\n"
		+ "Total Replans    " + str(total_replans) + "\n"
		+ "\n"
		+ "Last Start       " + str(last_start) + "\n"
		+ "Last Goal        " + str(last_goal)
	)
