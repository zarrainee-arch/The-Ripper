extends RefCounted
class_name AlphaBeta

# Jumlah node yang dikunjungi selama pencarian
var node_count: int = 0

# Depth maksimum pencarian
var max_depth: int = 3

# Menyimpan urutan action yang ingin diprioritaskan
var action_order: Array = []


# Konstruktor untuk menentukan depth
func _init(depth: int = 3):
	max_depth = depth


# Mengatur urutan action untuk eksperimen action ordering
func set_action_order(order: Array) -> void:
	action_order = order.duplicate()


# Mengurutkan action berdasarkan action_order
func order_actions(actions: Array) -> Array:
	if action_order.is_empty():
		return actions

	var ordered: Array = []

	# Memasukkan action berdasarkan prioritas
	for preferred_action in action_order:
		for action in actions:
			if action == preferred_action:
				ordered.append(action)

	# Memasukkan action yang belum dimasukkan
	for action in actions:
		if not ordered.has(action):
			ordered.append(action)

	return ordered


# Mencari action terbaik NPC menggunakan Minimax + Alpha-Beta pruning
func find_best_action(state, evaluation) -> Dictionary:
	var start_time = Time.get_ticks_usec()

	# Reset jumlah node untuk pencarian baru
	node_count = 0

	var best_action = null
	var best_score = -INF

	# Menyimpan score masing-masing action pada root
	var action_scores: Dictionary = {}

	# Batas bawah untuk Max/NPC
	var alpha = -INF

	# Batas atas untuk Min/lawan
	var beta = INF

	# Mengambil seluruh action yang tersedia
	var actions = order_actions(state.get_available_actions())

	# Jika tidak ada action atau state sudah terminal
	if actions.is_empty() or state.is_terminal():
		var time_ms = (Time.get_ticks_usec() - start_time) / 1000.0

		return {
			"best_action": null,
			"best_score": evaluation.evaluate(state),
			"node_count": node_count,
			"depth": max_depth,
			"action_scores": {},
			"execution_time_ms": time_ms
		}

	# Memeriksa semua action pada root
	for action in actions:
		# Membuat state simulasi
		var next_state = state.apply_action_simulation(action)

		# Setelah NPC memilih action,
		# pencarian dilanjutkan sebagai Min/lawan
		var score = _min_value(
			next_state,
			1,
			alpha,
			beta,
			evaluation
		)

		# Menyimpan score action
		action_scores[action] = score

		# Jika score lebih besar dari best_score,
		# action tersebut menjadi pilihan terbaik
		if score > best_score:
			best_score = score
			best_action = action

		# Update alpha berdasarkan score terbaik
		alpha = max(alpha, best_score)

	# Menghitung waktu setelah SEMUA action selesai diperiksa
	var time_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	return {
		"best_action": best_action,
		"best_score": best_score,
		"node_count": node_count,
		"depth": max_depth,
		"action_scores": action_scores,
		"execution_time_ms": time_ms
	}


# Max digunakan untuk mensimulasikan NPC
# NPC ingin mendapatkan nilai evaluasi terbesar
func _max_value(
	state,
	depth: int,
	alpha: float,
	beta: float,
	evaluation
) -> float:

	node_count += 1

	# Jika depth sudah mencapai batas atau state terminal
	if depth >= max_depth or state.is_terminal():
		return evaluation.evaluate(state)

	var actions = order_actions(state.get_available_actions())

	# Tidak ada action tersedia
	if actions.is_empty():
		return evaluation.evaluate(state)

	# Nilai awal Max sangat kecil
	var value = -INF

	# Memeriksa seluruh action
	for action in actions:
		var next_state = state.apply_action_simulation(action)

		# Setelah Max memilih action, lanjut ke Min
		var score = _min_value(
			next_state,
			depth + 1,
			alpha,
			beta,
			evaluation
		)

		# Max mengambil score terbesar
		value = max(value, score)

		# Alpha menyimpan nilai terbaik yang diketahui Max
		alpha = max(alpha, value)

		# Alpha-beta pruning
		if alpha >= beta:
			break

	return value


# Min digunakan untuk mensimulasikan lawan
# Lawan dianggap memilih nilai terkecil dari sudut pandang NPC
func _min_value(
	state,
	depth: int,
	alpha: float,
	beta: float,
	evaluation
) -> float:

	node_count += 1

	# Jika depth sudah mencapai batas atau state terminal
	if depth >= max_depth or state.is_terminal():
		return evaluation.evaluate(state)

	var actions = order_actions(state.get_available_actions())

	# Tidak ada action tersedia
	if actions.is_empty():
		return evaluation.evaluate(state)

	# Nilai awal Min sangat besar
	var value = INF

	# Memeriksa seluruh action
	for action in actions:
		var next_state = state.apply_action_simulation(action)

		# Setelah Min memilih action,
		# pencarian kembali ke Max
		var score = _max_value(
			next_state,
			depth + 1,
			alpha,
			beta,
			evaluation
		)

		# Min mengambil score terkecil
		value = min(value, score)

		# Beta menyimpan nilai terbaik yang diketahui Min
		beta = min(beta, value)

		# Alpha-beta pruning
		if alpha >= beta:
			break

	return value
