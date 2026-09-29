extends CharacterBody2D


const UCS = preload("res://scripts/ucs.gd")
const ASTAR = preload("res://scripts/astar.gd")
const HEURISTIC = preload("res://scripts/heuristic.gd")


const SPEED = 110.0
const REPLAN_INTERVAL = 0.25


enum PathfindingMode {
	UCS,
	ASTAR_MANHATTAN,
	ASTAR_EUCLIDEAN
}


@export var pathfinding_mode: PathfindingMode = PathfindingMode.UCS


# =========================================================
# PATHFINDING OBJECT
# =========================================================

var grid
var player

var ucs
var astar
var heuristic


# =========================================================
# CURRENT PATH
# =========================================================

var current_path: Array[Vector2i] = []

var expanded_nodes: Array[Vector2i] = []

var path_index: int = 0


# =========================================================
# REPLANNING
# =========================================================

var replan_timer: float = 0.0

var last_player_cell: Vector2i = Vector2i(-999, -999)


# =========================================================
# STATUS
# =========================================================

var path_status: String = "INITIALIZING"


# =========================================================
# CUMULATIVE STATISTICS
#
# INI TIDAK DI-RESET SETIAP REPLAN
# =========================================================

# Total semua node yang diexpand dari awal
# NPC mulai mengejar sampai sekarang.
var total_expanded_nodes: int = 0


# Total node path yang BENAR-BENAR sudah dilewati NPC.
var total_path_nodes: int = 0


# Total biaya gerakan aktual NPC.
# Karena setiap gerakan antar-cell = 1,
# setiap cell yang dilewati menambah 1.
var total_path_cost: float = 0.0


# Berapa kali pathfinding dijalankan.
var total_replans: int = 0


# =========================================================
# STATISTIK SEARCH TERAKHIR
#
# Ini hanya untuk informasi tambahan.
# =========================================================

var last_search_cost: float = INF

var last_search_expanded: int = 0

var last_search_path_nodes: int = 0

var last_start_cell: Vector2i = Vector2i(-1, -1)

var last_goal_cell: Vector2i = Vector2i(-1, -1)


# =========================================================
# READY
# =========================================================

func _ready():

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


	grid = get_parent().get_node("Grid")

	player = get_parent().get_node("Player")


	ucs = UCS.new(grid)

	astar = AStarSearch.new()

	heuristic = Heuristic.new()


	print("")
	print("================================")
	print("          NPC READY")
	print("================================")

	print("NPC position    : ", global_position)

	print("Player position : ", player.global_position)

	print("Algorithm       : ", get_mode_name())

	print("================================")


	# Mulai pengejaran
	update_path()


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta):

	if grid == null or player == null:

		velocity = Vector2.ZERO

		return


	replan_timer -= delta


	var player_cell = grid.world_to_cell(
		player.global_position
	)


	# =====================================================
	# PLAYER PINDAH CELL
	# =====================================================

	if player_cell != last_player_cell:

		last_player_cell = player_cell

		replan_timer = REPLAN_INTERVAL

		update_path()


	# =====================================================
	# KALAU PATH KOSONG
	# =====================================================

	elif (
		replan_timer <= 0.0
		and current_path.is_empty()
	):

		replan_timer = REPLAN_INTERVAL

		update_path()


	# Ikuti path
	follow_path()


# =========================================================
# UPDATE PATH
# =========================================================

func update_path():

	total_replans += 1

	replan_timer = REPLAN_INTERVAL


	var start = grid.world_to_cell(
		global_position
	)

	var goal = grid.world_to_cell(
		player.global_position
	)


	print("")
	print("========== NEW PATH SEARCH ==========")

	print("Algorithm : ", get_mode_name())

	print("Start     : ", start)

	print("Goal      : ", goal)


	# =====================================================
	# CEK START
	# =====================================================

	if not grid.is_inside_grid(start):

		path_status = "START OUTSIDE GRID"

		current_path.clear()

		velocity = Vector2.ZERO

		return


	# =====================================================
	# CEK GOAL
	# =====================================================

	if not grid.is_inside_grid(goal):

		path_status = "GOAL OUTSIDE GRID"

		current_path.clear()

		velocity = Vector2.ZERO

		return


	# =====================================================
	# CARI START YANG WALKABLE
	# =====================================================

	var search_start = start


	if not grid.is_walkable(search_start):

		search_start = find_nearest_walkable(start)


		if search_start == Vector2i(-999, -999):

			path_status = "NO WALKABLE START"

			current_path.clear()

			velocity = Vector2.ZERO

			return


	# =====================================================
	# PLAYER HARUS WALKABLE
	# =====================================================

	if not grid.is_walkable(goal):

		path_status = "PLAYER ON OBSTACLE"

		current_path.clear()

		velocity = Vector2.ZERO

		# JANGAN RESET STATISTIK KUMULATIF

		return


	# =====================================================
	# JALANKAN ALGORITMA
	# =====================================================

	var result: Dictionary = {}


	match pathfinding_mode:

		PathfindingMode.UCS:

			print("RUNNING UCS...")

			result = ucs.find_path(
				search_start,
				goal
			)


		PathfindingMode.ASTAR_MANHATTAN:

			print("RUNNING A* MANHATTAN...")

			heuristic.heuristic_type = "Manhattan"

			result = astar.find_path(
				grid,
				search_start,
				goal,
				heuristic
			)


		PathfindingMode.ASTAR_EUCLIDEAN:

			print("RUNNING A* EUCLIDEAN...")

			heuristic.heuristic_type = "Euclidean"

			result = astar.find_path(
				grid,
				search_start,
				goal,
				heuristic
			)


	# =====================================================
	# HASIL SEARCH
	# =====================================================

	if result.is_empty():

		path_status = "NO RESULT"

		current_path.clear()

		velocity = Vector2.ZERO

		return


	var new_path = result.get(
		"path",
		[]
	)


	var new_cost = result.get(
		"cost",
		INF
	)


	var new_expanded_nodes = result.get(
		"expanded_nodes",
		[]
	)


	var new_expanded_count = result.get(
		"expanded_count",
		new_expanded_nodes.size()
	)


	# =====================================================
	# PATH GAGAL
	# =====================================================

	if new_path.is_empty():

		print("NO PATH FOUND")

		path_status = "NO PATH"

		current_path.clear()

		velocity = Vector2.ZERO

		# Statistik cumulative TIDAK DIUBAH.

		return


	# =====================================================
	# SEARCH BERHASIL
	# =====================================================

	current_path.clear()

	for cell in new_path:

		current_path.append(cell)


	expanded_nodes.clear()

	for cell in new_expanded_nodes:

		expanded_nodes.append(cell)


	# =====================================================
	# SIMPAN STATISTIK SEARCH TERAKHIR
	# =====================================================

	last_search_cost = float(new_cost)

	last_search_expanded = int(new_expanded_count)

	last_search_path_nodes = current_path.size()

	last_start_cell = search_start

	last_goal_cell = goal


	# =====================================================
	# TAMBAHKAN EXPANDED NODE KE TOTAL
	#
	# INI YANG TIDAK BOLEH DI-RESET.
	# =====================================================

	total_expanded_nodes += new_expanded_count


	# =====================================================
	# STATUS
	# =====================================================

	path_status = "CHASING"


	# =====================================================
	# CARI NODE PATH TERDEKAT
	# =====================================================

	path_index = 0

	var closest_distance = INF


	for i in range(current_path.size()):

		var point = grid.cell_to_world(
			current_path[i]
		)


		var distance = global_position.distance_to(
			point
		)


		if distance < closest_distance:

			closest_distance = distance

			path_index = i


	# Jangan kembali ke node yang sudah dilewati
	if path_index < current_path.size() - 1:

		path_index += 1


	print("")
	print("========== PATH FOUND ==========")

	print("Search Cost      : ", last_search_cost)

	print("Search Expanded  : ", last_search_expanded)

	print("TOTAL Expanded   : ", total_expanded_nodes)

	print("Current Path     : ", current_path)

	print("================================")


# =========================================================
# FOLLOW PATH
# =========================================================

func follow_path():

	if current_path.is_empty():

		velocity = Vector2.ZERO

		return


	if path_index >= current_path.size():

		velocity = Vector2.ZERO

		return


	var target_cell = current_path[path_index]


	var target_position = grid.cell_to_world(
		target_cell
	)


	# =====================================================
	# SUDAH MENCAPAI NODE BERIKUTNYA
	# =====================================================

	if global_position.distance_to(
		target_position
	) < 6.0:

		# Node benar-benar sudah dilewati.
		total_path_nodes += 1

		# Setiap perpindahan cell = cost 1.
		total_path_cost += 1.0


		path_index += 1


		# Kalau sudah selesai path
		if path_index >= current_path.size():

			velocity = Vector2.ZERO

		return


	# =====================================================
	# GERAK
	# =====================================================

	var direction = global_position.direction_to(
		target_position
	)


	velocity = direction * SPEED


	var collision = move_and_collide(
		velocity * get_physics_process_delta_time()
	)


	# =====================================================
	# COLLISION
	# =====================================================

	if collision:

		var collider = collision.get_collider()


		print(
			"NPC COLLISION: ",
			collider.name
		)


		# Player tertangkap
		if collider.name == "Player":

			path_status = "CAUGHT PLAYER"

			velocity = Vector2.ZERO

			print("")
			print("================================")
			print("       PLAYER CAUGHT")
			print("================================")
			print("Algorithm          : ", get_mode_name())
			print("Total Path Cost    : ", total_path_cost)
			print("Total Path Nodes   : ", total_path_nodes)
			print("Total Expanded     : ", total_expanded_nodes)
			print("Total Replans      : ", total_replans)
			print("================================")

			return


		# Obstacle
		if collider.name == "Obstacle":

			print(
				"NPC MENABRAK OBSTACLE → REPLAN"
			)


			path_status = "REPLANNING"

			current_path.clear()

			path_index = 0

			replan_timer = 0.0


# =========================================================
# CARI CELL WALKABLE TERDEKAT
# =========================================================

func find_nearest_walkable(
	start: Vector2i
) -> Vector2i:


	if grid.is_walkable(start):

		return start


	for radius in range(1, 5):

		for y in range(
			-radius,
			radius + 1
		):

			for x in range(
				-radius,
				radius + 1
			):

				var candidate = start + Vector2i(
					x,
					y
				)


				if not grid.is_inside_grid(
					candidate
				):

					continue


				if grid.is_walkable(
					candidate
				):

					return candidate


	return Vector2i(-999, -999)


# =========================================================
# NAMA ALGORITMA
# =========================================================

func get_mode_name() -> String:

	match pathfinding_mode:

		PathfindingMode.UCS:

			return "UCS"


		PathfindingMode.ASTAR_MANHATTAN:

			return "A* Manhattan"


		PathfindingMode.ASTAR_EUCLIDEAN:

			return "A* Euclidean"


	return "UNKNOWN"
