extends RefCounted
class_name BattleAI

# Algoritma yang digunakan
var algorithm: String = "minimax"

# Depth maksimum pencarin
var depth: int = 3

# Objek algoritma Minimax dan Aplha-Beta
var minimax
var alpha_beta

# Konstruktor battle ai dengan pilihan algoritma dan depth
func _init( selected_algorithm: String = "minimax", search_depth: int = 3):
	# Menyimpan algoritma yang dipilih
	algorithm = selected_algorithm
	# Menyimpan depth yang digunakan
	depth = search_depth
	# Membuat objek minimax dan alpha-beta dengan depth tersebut
	minimax = Minimax.new(depth)
	alpha_beta = AlphaBeta.new(depth)

# Meneruskan urutan action ke alpha-beta untuk eksperimen action ordering
func set_action_order(order: Array) -> void:
	alpha_beta.set_action_order(order)

# Fungsi untuk memintai ai mencari action terbaik (hanya untuk melakukan pencarian)
func get_best_action(state, evaluation) -> SearchResult:
	# Untuk menampung hasil pencarian
	var result: Dictionary
	# Jika algoritma yang dipilih adalah alpha-beta, gunakan object alpha-beta
	if algorithm == "alpha_beta":
		result = alpha_beta.find_best_action(state, evaluation) 
	# Jika bukan alpha-beta, gunakan minimax
	else :
		result = minimax.find_best_action(state, evaluation)

	# Mengubah dictionary hasil pencarian menjadi SearchResult
	return SearchResult.new(
		result["best_action"],
		result["best_score"],
		result["node_count"],
		result["depth"],
		algorithm,
		result["action_scores"],
		result["execution_time_ms"]
	)
