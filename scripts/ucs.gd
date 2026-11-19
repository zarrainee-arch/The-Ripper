extends RefCounted

# Menyimpan data node dan cost untuk setiap entry pada frontier
class QueueEntry:
	var node: Vector2i
	var cost: int

	func _init(node_position: Vector2i, node_cost: int):
		node = node_position
		cost = node_cost

# Referensi ke grid yang digunakan dalam pencarian
var grid
# Menyimpan node yang menunggu untuk diperiksa
var frontier: Array[QueueEntry] = []
# Menyimpan cost minimum untuk mencapai setiap node
var cost_so_far: Dictionary = {}
# Menyimpan node sebelumnya untuk membentuk kembali path
var came_from: Dictionary = {}

func _init(grid_reference):
	# Menyimpan referensi ke grid
	grid = grid_reference

func push_frontier(node: Vector2i, cost: int):
	# Menambahkan node beserta costnya ke frontier
	frontier.append(QueueEntry.new(node, cost))

func pop_lowest_cost() -> QueueEntry:
	if frontier.is_empty():
		return null

	# Menganggap entry pertama sebagai entry dengan cost terendah
	var lowest_index = 0

	# Mencari entry dengan cost paling kecil
	for i in range(1, frontier.size()):
		if frontier[i].cost < frontier[lowest_index].cost:
			lowest_index = i

	# Menghapus dan mengembalikan entry dengan cost terendah
	return frontier.pop_at(lowest_index)

func find_path(start: Vector2i, goal: Vector2i) -> Dictionary:
	# Mengosongkan data pencarian dari proses sebelumnnya
	frontier.clear()
	cost_so_far.clear()
	came_from.clear()

	var expanded_nodes: Array[Vector2i] = []
	# Memasukkan node awal ke frontier dengan cost 0
	push_frontier(start, 0)
	# Cost untuk mencapai node awal adalah 0
	cost_so_far[start] = 0
	# Node awal menjadi titik awal untuk membentuk path
	came_from[start] = start

	# Pencarian dilakukan selama ada node di frontier
	while not frontier.is_empty():
		var current_entry = pop_lowest_cost()
		var current = current_entry.node
		# Mencatat node yang diexpand
		expanded_nodes.append(current)

		if current == goal:
			break

		# Memeriksa seluruh tetangga dari node saat ini
		for neighbor in grid.get_neighbors(current):
			var new_cost = cost_so_far[current] + 1

			# Memperbarui data jika node belum pernah ditemukan atau ditemukan cost yang lebih kecil
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				came_from[neighbor] = current
				push_frontier(neighbor, new_cost)

	# Membentuk path dari start menuju goal
	var path = reconstruct_path(start, goal)

	var path_cost = 0

	if cost_so_far.has(goal):
		path_cost = cost_so_far[goal]
	
	# Mengembalikan path, cost, dan node yang telah di-expand
	return {
		"path": path,
		"cost": path_cost,
		"expanded_nodes": expanded_nodes
	}

func reconstruct_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# Array untuk menyimpan hasil path
	var path: Array[Vector2i] = []

	if not came_from.has(goal):
		return path

	var current = goal
	
	# Menelusuri parent node sampai kembali ke start
	while current != start:
		path.append(current)
		current = came_from[current]

	# Menambahkan node awal ke path
	path.append(start)
	# Membalik path agar urutannya dari start menuju goal
	path.reverse()

	return path
