extends Node2D


# ============================================================
# KONFIGURASI GRID
# ============================================================

const CELL_SIZE: int = 40
const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 18


# ============================================================
# MODE DEBUG
# ============================================================

# Menampilkan garis grid.
var show_grid_debug: bool = true

# Menampilkan cell yang ditandai sebagai obstacle visual.
var show_obstacle_debug: bool = true


# ============================================================
# WARNA
# ============================================================

# Warna garis grid.
var grid_color := Color(1.0, 1.0, 1.0, 0.35)

# Warna nomor koordinat.
var coordinate_color := Color(1.0, 1.0, 1.0, 0.75)

# Warna expanded node.
var expanded_color := Color(1.0, 0.78, 0.20, 0.70)
var expanded_outline_color := Color(1.0, 0.88, 0.35, 0.90)

# Warna final path.
var path_color := Color(0.45, 1.0, 0.35, 0.95)
var path_outline_color := Color(0.65, 1.0, 0.50, 1.0)

# Warna obstacle.
var obstacle_color := Color(1.0, 0.05, 0.05, 0.45)
var obstacle_outline_color := Color(1.0, 0.30, 0.20, 1.0)
var obstacle_x_color := Color(1.0, 0.85, 0.85, 0.95)

# Warna panel informasi.
var panel_color := Color(0.03, 0.03, 0.04, 0.88)
var panel_border_color := Color(0.75, 0.65, 0.45, 0.75)

var text_color := Color(0.95, 0.92, 0.84, 1.0)
var secondary_text_color := Color(0.72, 0.70, 0.65, 1.0)


# ============================================================
# DATA HASIL SEARCH
# ============================================================

# Daftar cell yang di-expand oleh UCS / A*.
var expanded_nodes: Array[Vector2i] = []

# Daftar cell yang membentuk jalur akhir.
var final_path: Array[Vector2i] = []

# Nama algoritma.
var algorithm_name: String = "Belum ada"

# Nama heuristic.
var heuristic_name: String = "Belum ada"

# Jumlah node yang di-expand.
var expanded_count: int = 0

# Cost dari path.
var path_cost: float = 0.0

# Waktu pencarian dalam microsecond.
var search_time_usec: int = 0


# ============================================================
# OBSTACLE VISUAL
# ============================================================

# Cell obstacle yang digunakan untuk DEBUG VISUAL.
#
# CATATAN:
# Ini hanya penanda visual posisi pohon pada map.
# Ini bukan obstacle yang digunakan oleh UCS / A*.
#
# Obstacle asli untuk pathfinding tetap berasal dari grid.gd.
var visual_obstacles: Array[Vector2i] = []


# ============================================================
# FONT
# ============================================================

var debug_font: Font


# ============================================================
# READY
# ============================================================

func _ready():

	# Menggunakan font bawaan Godot.
	debug_font = ThemeDB.fallback_font

	# Menentukan cell obstacle berdasarkan posisi pohon.
	setup_visual_obstacles()


	# ========================================================
	# DATA DUMMY
	# ========================================================
	# Data sementara agar visualisasi bisa langsung dilihat.
	#
	# Nanti data ini akan diganti dengan hasil UCS / A* asli.
	# ========================================================

	expanded_nodes = [
		Vector2i(4, 5),
		Vector2i(5, 5),
		Vector2i(6, 5),
		Vector2i(6, 6),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(8, 7),
		Vector2i(9, 7),
		Vector2i(10, 7),
		Vector2i(10, 8)
	]


	final_path = [
		Vector2i(4, 5),
		Vector2i(5, 5),
		Vector2i(6, 5),
		Vector2i(6, 6),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(8, 7),
		Vector2i(9, 7),
		Vector2i(10, 7),
		Vector2i(10, 8)
	]


	algorithm_name = "A*"
	heuristic_name = "Manhattan"

	expanded_count = expanded_nodes.size()

	path_cost = max(final_path.size() - 1, 0)

	# Dummy search time.
	search_time_usec = 125


	# Meminta Godot menggambar ulang.
	queue_redraw()


# ============================================================
# SETUP OBSTACLE VISUAL
# ============================================================

func setup_visual_obstacles():

	visual_obstacles.clear()


	# ========================================================
	# POHON 1
	# Posisi atas-tengah.
	#
	# X = 12 sampai 14
	# Y = 0 sampai 3
	# ========================================================

	for y in range(0, 4):

		for x in range(12, 15):

			visual_obstacles.append(
				Vector2i(x, y)
			)


	# ========================================================
	# POHON 2
	# Posisi atas-kanan.
	#
	# X = 23 sampai 25
	# Y = 0 sampai 3
	# ========================================================

	for y in range(0, 4):

		for x in range(23, 26):

			visual_obstacles.append(
				Vector2i(x, y)
			)


	# ========================================================
	# POHON 3
	# Pohon besar sebelah kiri-tengah.
	#
	# X = 4 sampai 8
	# Y = 8 sampai 12
	# ========================================================

	for y in range(8, 13):

		for x in range(4, 9):

			visual_obstacles.append(
				Vector2i(x, y)
			)


	# ========================================================
	# POHON 4
	# Pohon tengah-kanan.
	#
	# X = 17 sampai 19
	# Y = 8 sampai 11
	# ========================================================

	for y in range(8, 12):

		for x in range(17, 20):

			visual_obstacles.append(
				Vector2i(x, y)
			)


	# ========================================================
	# POHON 5
	# Pohon bagian bawah-tengah.
	#
	# X = 9 sampai 11
	# Y = 14 sampai 17
	# ========================================================

	for y in range(14, 18):

		for x in range(9, 12):

			visual_obstacles.append(
				Vector2i(x, y)
			)


# ============================================================
# MENERIMA HASIL UCS / A*
# ============================================================

func set_search_result(result: Dictionary):


	# ========================================================
	# FINAL PATH
	# ========================================================

	if result.has("path"):

		final_path = result["path"].duplicate()

	else:

		final_path.clear()


	# ========================================================
	# EXPANDED NODES
	# ========================================================

	if result.has("expanded_nodes"):

		expanded_nodes = result["expanded_nodes"].duplicate()

	else:

		expanded_nodes.clear()


	# ========================================================
	# ALGORITHM
	# ========================================================

	if result.has("algorithm"):

		algorithm_name = str(
			result["algorithm"]
		)


	# ========================================================
	# HEURISTIC
	# ========================================================

	if result.has("heuristic"):

		heuristic_name = str(
			result["heuristic"]
		)


	# ========================================================
	# PATH COST
	# ========================================================

	if result.has("path_cost"):

		path_cost = float(
			result["path_cost"]
		)

	elif result.has("cost"):

		path_cost = float(
			result["cost"]
		)

	else:

		path_cost = max(
			final_path.size() - 1,
			0
		)


	# ========================================================
	# EXPANDED COUNT
	# ========================================================

	if result.has("expanded_count"):

		expanded_count = int(
			result["expanded_count"]
		)

	else:

		expanded_count = expanded_nodes.size()


	# ========================================================
	# SEARCH TIME
	# ========================================================

	if result.has("search_time_usec"):

		search_time_usec = int(
			result["search_time_usec"]
		)

	else:

		search_time_usec = 0


	# Gambar ulang.
	queue_redraw()


# ============================================================
# MEMBERSIHKAN VISUALISASI
# ============================================================

func clear_visualization():

	expanded_nodes.clear()

	final_path.clear()

	algorithm_name = "Belum ada"

	heuristic_name = "Belum ada"

	expanded_count = 0

	path_cost = 0.0

	search_time_usec = 0

	queue_redraw()


# ============================================================
# KONVERSI CELL KE POSISI PIXEL
# ============================================================

func cell_to_visual_position(cell: Vector2i) -> Vector2:

	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)


# ============================================================
# DRAW UTAMA
# ============================================================

func _draw():

	# Tampilkan grid jika mode debug aktif.
	if show_grid_debug:

		_draw_grid_debug()


	# Tampilkan obstacle jika mode debug aktif.
	if show_obstacle_debug:

		_draw_obstacles_debug()


	# Tampilkan expanded nodes.
	_draw_expanded_nodes()


	# Tampilkan final path.
	_draw_final_path()


	# Tampilkan informasi algoritma.
	_draw_debug_panel()


# ============================================================
# DRAW GRID
# ============================================================

func _draw_grid_debug():


	# ========================================================
	# GARIS VERTIKAL
	# ========================================================

	for x in range(GRID_WIDTH + 1):

		var start := Vector2(
			x * CELL_SIZE,
			0
		)

		var end := Vector2(
			x * CELL_SIZE,
			GRID_HEIGHT * CELL_SIZE
		)

		draw_line(
			start,
			end,
			grid_color,
			1.0
		)


	# ========================================================
	# GARIS HORIZONTAL
	# ========================================================

	for y in range(GRID_HEIGHT + 1):

		var start := Vector2(
			0,
			y * CELL_SIZE
		)

		var end := Vector2(
			GRID_WIDTH * CELL_SIZE,
			y * CELL_SIZE
		)

		draw_line(
			start,
			end,
			grid_color,
			1.0
		)


	# ========================================================
	# NOMOR KOORDINAT X
	# ========================================================

	for x in range(GRID_WIDTH):

		var coordinate_text := str(x)

		var position := Vector2(
			x * CELL_SIZE + 3,
			14
		)

		draw_string(
			debug_font,
			position,
			coordinate_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			coordinate_color
		)


	# ========================================================
	# NOMOR KOORDINAT Y
	# ========================================================

	for y in range(GRID_HEIGHT):

		var coordinate_text := str(y)

		var position := Vector2(
			3,
			y * CELL_SIZE + 25
		)

		draw_string(
			debug_font,
			position,
			coordinate_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			coordinate_color
		)


# ============================================================
# DRAW OBSTACLE
# ============================================================

func _draw_obstacles_debug():

	for cell: Vector2i in visual_obstacles:

		# Posisi kiri atas cell.
		var position := Vector2(
			cell.x * CELL_SIZE,
			cell.y * CELL_SIZE
		)

		var rect := Rect2(
			position,
			Vector2(
				CELL_SIZE,
				CELL_SIZE
			)
		)


		# ====================================================
		# WARNA MERAH TRANSPARAN
		# ====================================================

		draw_rect(
			rect,
			obstacle_color
		)


		# ====================================================
		# BORDER CELL
		# ====================================================

		draw_rect(
			rect,
			obstacle_outline_color,
			false,
			2.0
		)


		# ====================================================
		# TANDA X
		# ====================================================

		draw_line(
			rect.position,
			rect.position + rect.size,
			obstacle_x_color,
			2.0
		)

		draw_line(
			Vector2(
				rect.position.x + rect.size.x,
				rect.position.y
			),
			Vector2(
				rect.position.x,
				rect.position.y + rect.size.y
			),
			obstacle_x_color,
			2.0
		)


		# ====================================================
		# LABEL KOORDINAT
		# ====================================================

		var coordinate_text := (
			str(cell.x)
			+ ","
			+ str(cell.y)
		)

		draw_string(
			debug_font,
			position + Vector2(4, 35),
			coordinate_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(1.0, 1.0, 1.0, 1.0)
		)


# ============================================================
# DRAW EXPANDED NODE
# ============================================================

func _draw_expanded_nodes():

	for cell: Vector2i in expanded_nodes:

		var position := cell_to_visual_position(
			cell
		)


		# Lingkaran expanded node.
		draw_circle(
			position,
			7.0,
			expanded_color
		)


		# Outline expanded node.
		draw_arc(
			position,
			7.0,
			0.0,
			TAU,
			16,
			expanded_outline_color,
			1.5
		)


# ============================================================
# DRAW FINAL PATH
# ============================================================

func _draw_final_path():

	# Kalau tidak ada path, berhenti.
	if final_path.is_empty():

		return


	# ========================================================
	# GARIS PATH
	# ========================================================

	if final_path.size() >= 2:

		for i in range(
			final_path.size() - 1
		):

			var start_position := cell_to_visual_position(
				final_path[i]
			)

			var end_position := cell_to_visual_position(
				final_path[i + 1]
			)


			# Shadow / outline path.
			draw_line(
				start_position,
				end_position,
				Color(
					0.05,
					0.15,
					0.04,
					0.65
				),
				6.0,
				true
			)


			# Path utama.
			draw_line(
				start_position,
				end_position,
				path_color,
				3.0,
				true
			)


	# ========================================================
	# TITIK PATH
	# ========================================================

	for cell: Vector2i in final_path:

		var position := cell_to_visual_position(
			cell
		)

		draw_circle(
			position,
			5.0,
			path_color
		)

		draw_arc(
			position,
			5.0,
			0.0,
			TAU,
			16,
			path_outline_color,
			1.0
		)


# ============================================================
# DEBUG PANEL
# ============================================================

func _draw_debug_panel():

	# Posisi panel.
	var panel_position := Vector2(
		930,
		115
	)

	# Ukuran panel.
	var panel_size := Vector2(
		210,
		220
	)

	var panel_rect := Rect2(
		panel_position,
		panel_size
	)


	# ========================================================
	# BACKGROUND PANEL
	# ========================================================

	draw_rect(
		panel_rect,
		panel_color
	)


	# ========================================================
	# BORDER PANEL
	# ========================================================

	draw_rect(
		panel_rect,
		panel_border_color,
		false,
		1.5
	)


	# ========================================================
	# ALGORITHM
	# ========================================================

	draw_string(
		debug_font,
		panel_position + Vector2(15, 35),
		"Algorithm : " + algorithm_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		text_color
	)


	# ========================================================
	# HEURISTIC
	# ========================================================

	draw_string(
		debug_font,
		panel_position + Vector2(15, 65),
		"Heuristic : " + heuristic_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		text_color
	)


	# ========================================================
	# EXPANDED
	# ========================================================

	draw_string(
		debug_font,
		panel_position + Vector2(15, 100),
		"Expanded  : " + str(expanded_count),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		text_color
	)


	# ========================================================
	# PATH COST
	# ========================================================

	draw_string(
		debug_font,
		panel_position + Vector2(15, 130),
		"Path Cost : " + str(path_cost),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		text_color
	)


	# ========================================================
	# SEARCH TIME
	# ========================================================

	var time_text := "Search   : "


	if search_time_usec > 0:

		time_text += str(
			search_time_usec
		) + " us"

	else:

		time_text += "-"


	draw_string(
		debug_font,
		panel_position + Vector2(15, 160),
		time_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		secondary_text_color
	)


	# ========================================================
	# LEGEND EXPANDED NODE
	# ========================================================

	draw_circle(
		panel_position + Vector2(22, 190),
		5.0,
		expanded_color
	)

	draw_string(
		debug_font,
		panel_position + Vector2(35, 195),
		"Expanded Node",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		secondary_text_color
	)


	# ========================================================
	# LEGEND FINAL PATH
	# ========================================================

	draw_circle(
		panel_position + Vector2(22, 215),
		5.0,
		path_color
	)

	draw_string(
		debug_font,
		panel_position + Vector2(35, 220),
		"Final Path",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		secondary_text_color
	)
