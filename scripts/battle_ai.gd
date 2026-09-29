extends RefCounted
class_name BattleAI


# Algoritma yang digunakan
var algorithm: String = "minimax"

# Depth maksimum pencarian
var depth: int = 3

# Objek algoritma Minimax dan Alpha-Beta
var minimax
var alpha_beta


# Konstruktor BattleAI dengan pilihan algoritma dan depth
func _init(selected_algorithm: String = "minimax", search_depth: int = 3):
	# Menyimpan algoritma yang dipilih
	algorithm = selected_algorithm
	
	# Menyimpan depth yang digunakan
	depth = search_depth
	
	# Membuat objek Minimax dan Alpha-Beta
	minimax = Minimax.new(depth)
	alpha_beta = AlphaBeta.new(depth)


# Meneruskan urutan action ke Alpha-Beta
# untuk eksperimen action ordering
func set_action_order(order: Array) -> void:
	alpha_beta.set_action_order(order)


# Meminta AI mencari action terbaik
func get_best_action(state, evaluation) -> SearchResult:
	# Menampung hasil pencarian
	var result: Dictionary
	
	# Jika algoritma yang dipilih adalah Alpha-Beta
	if algorithm == "alpha_beta":
		result = alpha_beta.find_best_action(state, evaluation)
	
	# Jika bukan Alpha-Beta, gunakan Minimax
	else:
		result = minimax.find_best_action(state, evaluation)
	
	# Mengubah hasil pencarian menjadi SearchResult
	return SearchResult.new(
		result["best_action"],
		result["best_score"],
		result["node_count"],
		result["depth"],
		algorithm,
		result["action_scores"],
		result["execution_time_ms"]
	)