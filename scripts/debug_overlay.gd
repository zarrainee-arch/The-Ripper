extends CanvasLayer

var game: Node = null
var battle_system: Node = null

var panel: PanelContainer
var label: Label

# F3: Stage 4 (Local Search + CSP)
# F4: Battle AI (Minimax + Alpha-Beta)
# F5: Pathfinding
var debug_mode: int = 0
var debug_visible: bool = true


func _ready() -> void:
	game = get_tree().root.find_child("Game", true, false)

	if game != null:
		battle_system = game.get_node_or_null("BattleSystem")

	panel = PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(290, 0)
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_F3:
			debug_visible = not debug_visible
			panel.visible = debug_visible
		KEY_F4:
			debug_mode = 1 if debug_mode != 1 else 0
		KEY_F5:
			debug_mode = 2 if debug_mode != 2 else 0


func _process(_delta: float) -> void:
	if not debug_visible:
		return

	if not is_instance_valid(game):
		game = get_tree().root.find_child("Game", true, false)

	if game == null:
		label.text = "STAGE 4 DEBUG\nGame node not found."
		return

	match debug_mode:
		0:
			show_stage4_debug()
		1:
			show_battle_debug()
		2:
			show_pathfinding_debug()


# Membaca properti dari Dictionary atau Object.
func read_value(source: Variant, property_name: String, default_value: Variant = null) -> Variant:
	if source == null:
		return default_value

	if source is Dictionary:
		return source.get(property_name, default_value)

	if source is Object:
		var value = source.get(property_name)
		if value != null:
			return value

	return default_value


func show_stage4_debug() -> void:
	var root := get_tree().root

	# Hasil optimasi disimpan oleh configuration menu.
	var result = root.get_meta("optimization_result", null)
	var initial_config = root.get_meta("initial_configuration", null)

	var best_config = read_value(result, "best_configuration")
	var config = best_config if best_config != null else initial_config

	var weapon := "Unknown"
	var armor := "Unknown"
	var algorithm := "Unknown"
	var difficulty := "Unknown"
	var composition: Array = []
	var npc_count := 0

	# Ambil konfigurasi hasil optimasi atau konfigurasi awal.
	if config != null:
		weapon = str(read_value(config, "weapon", "Unknown"))
		armor = str(read_value(config, "armor", "Unknown"))
		composition = read_value(config, "composition", [])
		npc_count = int(read_value(config, "npc_count", 0))

	if result != null:
		algorithm = str(read_value(result, "algorithm_name", "Unknown"))
		difficulty = str(read_value(result, "best_difficulty_score", "Unknown"))
	else:
		difficulty = str(Global.target_difficulty)

	# Baca role assignment dari Game.
	var roles = game.get("npc_roles")
	if not roles is Dictionary:
		roles = {}

	var leader_count := 0
	for role in roles.values():
		if str(role) == "LEADER":
			leader_count += 1

	var text := "STAGE 4 DEBUG\n"
	text += "────────────────────────\n"
	text += "LOCAL SEARCH\n"
	text += "Weapon          : " + weapon + "\n"
	text += "Armor           : " + armor + "\n"
	text += "Algorithm       : " + algorithm + "\n"
	text += "Difficulty      : " + difficulty + "\n"
	text += "Composition     : " + str(composition) + "\n"
	text += "NPC Count       : " + str(npc_count) + "\n"

	text += "\nOPTIMIZATION RESULT\n"

	if result != null:
		text += "Status          : "
		text += "SUCCESS\n" if bool(read_value(result, "success", false)) else "NOT SUCCESS\n"
		text += "Target          : " + str(read_value(result, "target_difficulty", "Unknown")) + "\n"
		text += "Best Fitness    : " + str(read_value(result, "best_fitness", "Unknown")) + "\n"
		text += "Iterations      : " + str(read_value(result, "iteration_count", "Unknown")) + "\n"
		text += "Evaluations     : " + str(read_value(result, "evaluation_count", "Unknown")) + "\n"
		text += "Restarts        : " + str(read_value(result, "restart_count", "Unknown")) + "\n"
		text += "Execution Time  : " + str(read_value(result, "elapsed_ms", "Unknown")) + " ms\n"
		text += "Termination     : " + str(read_value(result, "termination_reason", "Unknown")) + "\n"
	else:
		text += "Result          : Not available\n"

	text += "\nCSP ROLE ASSIGNMENT\n"

	if roles.is_empty():
		text += "Waiting for CSP assignment.\n"
	else:
		for npc_id in roles:
			text += str(npc_id) + " : " + str(roles[npc_id]) + "\n"

	text += "Total Assigned  : " + str(roles.size()) + "\n"
	text += "Leader Count    : " + str(leader_count) + "\n"

	var valid_assignment: bool = (
	not roles.is_empty()
	and leader_count == 1
	and roles.size() == npc_count
)

	text += "Assignment      : "
	text += "VALID" if valid_assignment else "CHECK"

	label.text = text


func show_pathfinding_debug() -> void:
	if game == null:
		label.text = "PATHFINDING DEBUG\nGame node not found."
		return

	var npc = game.get_node_or_null("NPC")
	if npc == null:
		npc = game.find_child("NPC", true, false)

	if npc == null:
		label.text = "PATHFINDING DEBUG\nNPC node not found."
		return

	label.text = (
		"PATHFINDING DEBUG\n"
		+ "────────────────────────\n"
		+ "Algorithm        : " + str(npc.call("get_mode_name")) + "\n"
		+ "Status           : " + str(npc.get("path_status")) + "\n"
		+ "Total Path Cost  : " + str(npc.get("total_path_cost")) + "\n"
		+ "Total Path Nodes : " + str(npc.get("total_path_nodes")) + "\n"
		+ "Total Expanded   : " + str(npc.get("total_expanded_nodes")) + "\n"
		+ "Total Replans    : " + str(npc.get("total_replans")) + "\n"
		+ "Last Start       : " + str(npc.get("last_start_cell")) + "\n"
		+ "Last Goal        : " + str(npc.get("last_goal_cell"))
	)


func show_battle_debug() -> void:
	if not is_instance_valid(battle_system) and game != null:
		battle_system = game.get_node_or_null("BattleSystem")

	if not is_instance_valid(battle_system):
		label.text = "BATTLE AI DEBUG\nBattleSystem tidak ditemukan."
		return

	var minimax = battle_system.get("last_minimax_result")
	var alpha_beta = battle_system.get("last_alpha_beta_result")

	var text := "BATTLE AI DEBUG\n"
	text += "──────────────────────────\n"

	if minimax != null:
		text += "MINIMAX\n"
		text += "Best Action : " + str(read_value(minimax, "best_action", "Unknown")) + "\n"
		text += "Score       : " + str(read_value(minimax, "best_score", "Unknown")) + "\n"
		text += "Depth       : " + str(read_value(minimax, "depth", "Unknown")) + "\n"
		text += "Nodes       : " + str(read_value(minimax, "node_count", "Unknown")) + "\n"
		text += "Time        : " + str(read_value(minimax, "execution_time_ms", "Unknown")) + " ms\n\n"
	else:
		text += "MINIMAX\nWaiting for AI...\n\n"

	if alpha_beta != null:
		text += "ALPHA-BETA\n"
		text += "Best Action : " + str(read_value(alpha_beta, "best_action", "Unknown")) + "\n"
		text += "Score       : " + str(read_value(alpha_beta, "best_score", "Unknown")) + "\n"
		text += "Depth       : " + str(read_value(alpha_beta, "depth", "Unknown")) + "\n"
		text += "Nodes       : " + str(read_value(alpha_beta, "node_count", "Unknown")) + "\n"
		text += "Time        : " + str(read_value(alpha_beta, "execution_time_ms", "Unknown")) + " ms"
	else:
		text += "ALPHA-BETA\nWaiting for AI..."

	label.text = text
