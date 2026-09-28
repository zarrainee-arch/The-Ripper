extends RefCounted
class_name SearchResult

# Action yang dipilih oleh AI
var best_action
# Nilai evaluasi dari action terbaik
var best_score: float
# Jumlah node yang diperiksa AI
var node_count: int 
# Depth yang digunakan dalam pencarian
var depth: int 
# Algoritma yang digunakan
var algorithm: String
# Menyimpan score setiap action yang tersedia pada root
var action_scores: Dictionary
# Menyimpan lama waktu yang dibutuhkan untuk pencarian
var execution_time_ms: float 

# Konstruktor untuk mengisi hasil pencarian
func _init(action, score: float, nodes: int, search_depth: int, algorithm_name: String, scores_map: Dictionary = {}, time_ms: float = 0.0):
    best_action = action,
    best_score = score,
    node_count = nodes,
    depth = search_depth,
    algorithm = algorithm_name,
    action_scores = scores_map,
    execution_time_ms = time_ms