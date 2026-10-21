
extends Node2D

const SAFE_HOUSE_CELL = Vector2i(30, 16)
const SAFE_HOUSE_DISTANCE = 20.0
const CATCH_DISTANCE = 30.0
const BATTLE_TRIGGER_DISTANCE = 120.0
const SPAWN_SEARCH_RADIUS = 12
const MIN_SPAWN_DISTANCE = 48.0
const BATTLE_ENEMY_SPACING = 64.0

# Composition: [Street Thug, Knife Thug, Heavy Enforcer]

var player: CharacterBody2D
var npc: CharacterBody2D
var npcs: Array[CharacterBody2D] = []
var npc_templates: Array[CharacterBody2D] = []

var grid
var game_over := false
var game_message
var battle_system
var battle_ui
var battle_started := false

var player_original_position: Vector2
var npc_original_position: Vector2
var used_spawn_cells: Array[Vector2i] = []

# CSP Role Assignment
var csp_solver: CSPRoleAssignment
var csp_result: Dictionary = {}
var npc_roles: Dictionary = {}


func _ready() -> void:
	player = get_node("Player") as CharacterBody2D
	npc = get_node("NPC") as CharacterBody2D
	grid = get_node("Grid")
	battle_system = get_node("BattleSystem")
	battle_ui = get_node("BattleUI")
	game_message = get_node_or_null("CanvasLayer/GameMessage")

	npc_templates = [
		get_node("NPC") as CharacterBody2D,
		get_node("KnifeThug") as CharacterBody2D,
		get_node("Heavy") as CharacterBody2D
	]

	var template_positions: Array[Vector2] = []

	for template in npc_templates:
		template_positions.append(template.global_position)
		template.visible = false
		template.set_physics_process(false)

	npcs.clear()
	csp_solver = CSPRoleAssignment.new()
	
	var tester := CSPRoleAssignment.new()
	tester.run_csp_tests()

	spawn_configured_npcs(template_positions)

	var battle_player = player.get_node_or_null("BattlePlayer")
	if battle_player:
		battle_player.visible = false

	if game_message:
		game_message.text = ""

	print("GAME READY")
	print("NPC count: ", npcs.size())


func get_configuration_composition() -> Array:
	var root = get_tree().root

	# Prioritas 1: konfigurasi hasil optimasi
	if root.has_meta("optimization_result"):
		var result = root.get_meta("optimization_result")
		if result != null and result.best_configuration != null:
			return result.best_configuration.composition.duplicate()

	# Prioritas 2: konfigurasi awal
	if root.has_meta("initial_configuration"):
		var config = root.get_meta("initial_configuration")
		if config != null:
			return config.composition.duplicate()

	# Prioritas 3: konfigurasi battle
	if root.has_meta("battle_configuration"):
		var config = root.get_meta("battle_configuration")
		if config != null:
			return config.composition.duplicate()

	return []


func solve_csp_roles(composition: Array) -> void:
	npc_roles.clear()
	csp_result.clear()

	if csp_solver == null:
		csp_solver = CSPRoleAssignment.new()

	var configuration = LocalSearch.NPCConfiguration.new(
		composition,
		"Knife",
        "Street Clothes"
	)

	csp_result = csp_solver.solve(configuration)

	if not csp_result.get("success", false):
		push_warning(
			"CSP gagal menentukan role NPC: " +
			str(csp_result.get("message", "Unknown error"))
		)
		return

	npc_roles = csp_result.get("assignments", {}).duplicate()

	print("=== CSP ROLE ASSIGNMENT ===")
	print("Assignments: ", npc_roles)


func spawn_configured_npcs(
	template_positions: Array[Vector2]
) -> void:
	var composition: Array = get_configuration_composition()

	if composition.size() < 3:
		push_warning(
			"Konfigurasi NPC tidak ditemukan. " +
            "Pastikan game dibuka melalui alur hasil optimasi."
		)
		return

	# Jalankan CSP sebelum NPC dibuat.
	solve_csp_roles(composition)

	used_spawn_cells.clear()
	npcs.clear()

	var spawned_role_ids: Array[String] = []
	var csp_role_index := 1

	for type_index in range(3):
		var template: CharacterBody2D = npc_templates[type_index]
		var amount := int(composition[type_index])

		for i in range(amount):
			# Urutan ID mengikuti urutan NPC pada CSP.
			var csp_id := "NPC-%02d" % csp_role_index
			csp_role_index += 1

			var origin_cell: Vector2i = grid.world_to_cell(
				template_positions[type_index]
			)

			var spawn_cell := find_spawn_cell(origin_cell)

			if spawn_cell == Vector2i(-999, -999):
				push_warning(
					"Tidak ada sel spawn yang ditemukan untuk " +
					template.name
				)
				continue

			var enemy: CharacterBody2D

			if i == 0:
				enemy = template
			else:
				enemy = template.duplicate() as CharacterBody2D

				if enemy == null:
					push_error("Gagal menduplikasi " + template.name)
					continue

				enemy.name = "%s_%d" % [template.name, i + 1]

			enemy.position = grid.to_local(
				grid.cell_to_world(spawn_cell)
			)

			if i > 0:
				add_child(enemy)

			enemy.visible = true
			enemy.set_physics_process(true)

			if not enemy.is_in_group("battle_enemies"):
				enemy.add_to_group("battle_enemies")

			npcs.append(enemy)
			spawned_role_ids.append(csp_id)
			used_spawn_cells.append(spawn_cell)

	# Hubungkan role hasil CSP ke setiap NPC yang berhasil di-spawn.
	for i in range(npcs.size()):
		var enemy: CharacterBody2D = npcs[i]
		var role_id: String = spawned_role_ids[i]
		var role: String = str(
			npc_roles.get(role_id, "UNASSIGNED")
		)

		add_role_label(enemy, role)

	# Sembunyikan template yang tidak digunakan.
	for template in npc_templates:
		if not npcs.has(template):
			template.visible = false
			template.set_physics_process(false)

	if not npcs.is_empty():
		npc = npcs[0]

	print("=== NPC SPAWNED ===")
	print("Composition: ", composition)
	print("Total NPC: ", npcs.size())
	print("Spawn cells: ", used_spawn_cells)
	print("NPC roles: ", npc_roles)


func add_role_label(
	enemy: CharacterBody2D,
	role: String
) -> void:
	if enemy == null:
		return

	var existing_label = enemy.get_node_or_null("RoleLabel")
	if existing_label != null:
		enemy.remove_child(existing_label)
		existing_label.free()

	var role_label := Label.new()
	role_label.name = "RoleLabel"
	role_label.text = role
	role_label.position = Vector2(-50, -45)
	role_label.custom_minimum_size = Vector2(100, 22)
	role_label.size = Vector2(100, 22)

	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 12)

	if role == "LEADER":
		role_label.add_theme_color_override(
			"font_color",
			Color("#ffcc66")
		)
	else:
		role_label.add_theme_color_override(
			"font_color",
			Color("#ffffff")
		)

	role_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	role_label.add_theme_constant_override("outline_size", 4)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_label.z_index = 10

	enemy.add_child(role_label)


func find_spawn_cell(origin: Vector2i) -> Vector2i:
	var player_cell: Vector2i = grid.world_to_cell(
		player.global_position
	)

	for radius in range(SPAWN_SEARCH_RADIUS + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue

				var candidate: Vector2i = (
					origin + Vector2i(x, y)
				)

				if not grid.is_inside_grid(candidate):
					continue

				if used_spawn_cells.has(candidate):
					continue

				if candidate == player_cell:
					continue

				if not grid.is_walkable(candidate):
					continue

				var candidate_position: Vector2 = (
					grid.cell_to_world(candidate)
				)

				var too_close := false

				for existing_cell in used_spawn_cells:
					var existing_position: Vector2 = (
						grid.cell_to_world(existing_cell)
					)

					if candidate_position.distance_to(
						existing_position
					) < MIN_SPAWN_DISTANCE:
						too_close = true
						break

				if too_close:
					continue

				return candidate

	return Vector2i(-999, -999)


func _process(_delta: float) -> void:
	if game_over or battle_started:
		return

	check_battle_trigger()

	if game_over or battle_started:
		return

	check_lose()

	if game_over:
		return

	check_win()


func check_win() -> void:
	var safe_house_position: Vector2 = (
		grid.cell_to_world(SAFE_HOUSE_CELL)
	)

	if player.global_position.distance_to(
		safe_house_position
	) <= SAFE_HOUSE_DISTANCE:
		end_game("YOU ESCAPED!")


func check_lose() -> void:
	for enemy in npcs:
		if not is_instance_valid(enemy):
			continue

		if player.global_position.distance_to(
			enemy.global_position
		) <= CATCH_DISTANCE:
			end_game("YOU GOT CAUGHT!")
			return


func end_game(message: String) -> void:
	game_over = true

	if game_message:
		game_message.text = message

	if player:
		player.set_physics_process(false)

	for enemy in npcs:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)


func check_battle_trigger() -> void:
	for enemy in npcs:
		if not is_instance_valid(enemy):
			continue

		if player.global_position.distance_to(
			enemy.global_position
		) <= BATTLE_TRIGGER_DISTANCE:

			battle_started = true

			player_original_position = player.global_position
			npc_original_position = enemy.global_position
			npc = enemy

			set_battle_positions()

			player.set_physics_process(false)

			for enemy_to_stop in npcs:
				enemy_to_stop.set_physics_process(false)

			battle_system.start_battle(npcs.size())
			battle_ui.show_battle()

			print("=== BATTLE TRIGGERED ===")
			print("NPC in battle: ", npcs.size())
			return


func set_battle_positions() -> void:
	if npcs.is_empty():
		return

	var direction: Vector2 = (
		npc.global_position - player.global_position
	)

	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	var perpendicular := Vector2(
		-direction.y,
		direction.x
	)

	var center: Vector2 = (
		player.global_position + npc.global_position
	) / 2.0

	player.global_position = center - direction * 55.0

	var enemy_index := 0

	for enemy in npcs:
		if not is_instance_valid(enemy):
			continue

		var row := enemy_index / 3
		var column := enemy_index % 3

		var side_offset: float = (
			(float(column) - 1.0) * BATTLE_ENEMY_SPACING
		)

		var forward_offset: float = (
			float(row) * BATTLE_ENEMY_SPACING
		)

		enemy.global_position = (
			center
			+ direction * (45.0 + forward_offset)
			+ perpendicular * side_offset
		)

		enemy_index += 1
