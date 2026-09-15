extends Node
class_name AStarSearch

# Menyimpan node yang sudah di-expand
var expanded_nodes: Array[Vector2i] = []
# Menyimpan hasil path terakhir
var final_path: Array[Vector2i] = []
# Menyimpan total cost dari path terakhir
var final_path_cost: int = 0
# Jumlah node yang di-expadn
var expanded_count: int = 0
# Nama heuristic yang sedang digunakan
var heuristic_name: String = "Manhattan"
# Menandai apakah path berhasil ditemukan atau tidak
var is_path_found: bool = false
# Waktu pencarian dalam
var search_time_usec: int = 0

func find_path(grid, start: Vector2i, goal: Vector2i, heuristic) -> Dictionary:
	# Mencatat waktu awal eksekusi
	var start_time: int = Time.get_ticks_usec()
	
	# Reset hasil pencarian sebelumnnya (mencegah data nyangkut saat re-planning)
	expanded_nodes.clear()
	final_path.clear()
	final_path_cost = 0
	expanded_count = 0
	is_path_found = false
	search_time_usec = 0

	# Menentukan heuristic yang dipakai
	# Jika heurstic tidak tersedia, A* akan menggunakan h(n) = 0
	if heuristic:
		if heuristic.has_method("get_heuristic_name"):
			heuristic_name = heuristic.get_heuristic_name()
		elif "name" in heuristic:
			heuristic_name = heuristic.name
		else:
			heuristic_name = "Custom Heuristic"
	else:
		heuristic_name = "None (UCS Fallback)"
		
	# Start dan goal harus di dalam grid
	if not grid.is_inside_grid(start) or not grid.is_inside_grid(goal):
		search_time_usec = Time.get_ticks_usec() - start_time
		return create_result()

	# Start dan goal harus walkable (bukan obstacle)
	if not grid.is_walkable(start) or not grid.is_walkable(goal):
		search_time_usec = Time.get_ticks_usec() - start_time
		return create_result()

	# Jika NPC sudah berada di posisi player, maka tidak perlu melakukan pencarian
	if start == goal:
		final_path.append(start)
		final_path_cost = 0
		is_path_found = true
		search_time_usec = Time.get_ticks_usec() - start_time
		return create_result()

	# Struktur data pencarian A*
	var open_list: Array = [] # Menyimpan node yang akan diperiksa
	var g_score: Dictionary = {} # Menyimpan cost dari start menuju setiap node
	var parent: Dictionary = {} # Menyimpan node sebelumnya untuk membentuk path

	# Inisialisasi start node
	g_score[start] = 0 # Cost dari start menuju dirinya sendiri adalah -
	
	# Hitung heuristic dari start menuju goal
	# Jika heuristic tidak tersedia, h(n) = 0
	var start_h: float = heuristic.calculate(start, goal) if heuristic else 0.0
	
	# f(n) = g(n) + h(n)
	var start_f: float = start_h

	# Masukkan start node ke dalam open list
	open_list.append({
		"position": start,
		"g": 0,
		"h": start_h,
		"f": start_f
	})

	# Loop utama A*
	# Berjalan selama masih ada node yang harus diperiksa
	while not open_list.is_empty():
		# Ambil node dengan f terkecil 
		# Jika f sama, gunakan tie-breaker berdasarkan nilai g
		var current_index: int = get_lowest_f_index(open_list)
		var current = open_list[current_index]
			
		# Hapus node yang dipilih dari open list
		open_list.remove_at(current_index)
		var current_position: Vector2i = current["position"]

		# Goal diperiksa ketika node diambil dari open list
		if current_position == goal:
			final_path = reconstruct_path(parent, start, goal)
			final_path_cost = g_score[goal]
			is_path_found = true
			search_time_usec = Time.get_ticks_usec() - start_time
			return create_result()

		# Tandai node sebagai expanded / closed
		# Node hanya dicatar satu kali
		if not expanded_nodes.has(current_position):
			expanded_nodes.append(current_position)
			expanded_count += 1
		
		# Ambil tetangga (atas, bawah, kiri, kanan) yang walkable
		var neighbors: Array[Vector2i] = grid.get_neighbors(current_position)
			
		for neighbor in neighbors:
			# Node yang sudah closed tidak diproses ulang
			if expanded_nodes.has(neighbor):
				continue
			
			# Cost perpindahan antar grid = 1
			var movement_cost: int = 1

			# Menghitung g(n) sementara
			# g(n) = cost dari start sampai current + cost perpindahan
			var tentative_g: int = g_score[current_position] + movement_cost

			# Jika neighbor belum pernah ditemukan atau ditemukan jalur baru dengan cost yang lebih kecil, maka informasi neighbor diperbaharui
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				# Menyimpan current sebagai parent dari neighbor
				parent[neighbor] = current_position
				# Menyiimpan cost terbaik sementara menuju neighbor
				g_score[neighbor] = tentative_g

				# Mengambil heuristic, lalu hitung f(n)
				var h_cost: float = heuristic.calculate(neighbor, goal) if heuristic else 0.0
				var f_cost: float = tentative_g + h_cost
				
				# Mengecek apakah neighbor sudah ada di open list 
				var existing_index: int = find_in_open_list(open_list, neighbor)

				# Jika belum ada di open list maka tambahkan
				if existing_index == -1:
					open_list.append({
						"position": neighbor,
						"g": tentative_g,
						"h": h_cost,
						"f": f_cost
					})
				else:
				# Jika sudah ada di open list, perbarui nilai g, h, f 
				# Menggunakan jalur yang memiliki cost lebih kecil
					open_list[existing_index]["g"] = tentative_g
					open_list[existing_index]["h"] = h_cost
					open_list[existing_index]["f"] = f_cost
	
	# Open list habis dan goal tidak ditemukan (is_path_found false)
	# Berarti tidak terdapat jalur dari start menuju goal
	search_time_usec = Time.get_ticks_usec() - start_time
	return create_result()

# Untuk mencari index node dengan f terkecil di open list
# Tie-breaker: Kalau f sama, pilih node dengan g lebih besar
func get_lowest_f_index(open_list: Array) -> int:
	var lowest_index: int = 0

	for i in range(1, open_list.size()):
		var current_f: float = open_list[i]["f"]
		var lowest_f: float = open_list[lowest_index]["f"]
		# Jika f node saat ini lebih kecil, gunakan sebagai path terbaik
		if current_f < lowest_f:
			lowest_index = i
		# Jika f sama gunakan tie-breaker
		elif current_f == lowest_f:
			# Memilih node dengan g lebih besar
			if open_list[i]["g"] > open_list[lowest_index]["g"]:
				lowest_index = i 
	return lowest_index

# Mengecek apakah posisi sudah ada di open list, jika ada kembalikan indexnya
# Kembalikan -1 jika tidak ditemukan
func find_in_open_list(open_list: Array, pos: Vector2i) -> int:
	for i in range(open_list.size()):
		if open_list[i]["position"] == pos:
			return i
	return -1

# Menelusuri parent dari goal ke start, lalu reverse
func reconstruct_path(parent: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = goal

	# Menelusrri goal terlebih dahulu
	path.append(current)

	# Menelusuri parent sampai kembali ke start
	while current != start:
		# Tidak ada jalur ke start maka path invalid
		if not parent.has(current):
			path.clear()
			return path 
		# Pindah ke parent dari node saat ini
		current = parent[current]
		# Masukkan node ke dalam path
		path.append(current)
	path.reverse()
	return path

# Hasil akhir dari perhitungan algoritma A*
func create_result() -> Dictionary:
	return{
		"algorithm": "A*",
		"found": is_path_found,
		"path": final_path.duplicate(),
		"path_cost": final_path_cost,
		"expanded_nodes": expanded_nodes.duplicate(),
		"expanded_count": expanded_count,
		"heuristic": heuristic_name,
		"search_time_usec": search_time_usec
	}

