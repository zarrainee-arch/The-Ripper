extends RefCounted
class_name AlphaBeta

# Jumlah node yang dikunjungi selama pencarian
var node_count: int = 0

# Depth maksimum pencarian
var max_depth: int = 3

# Menyimpan urutan action yang ingin diprioritaskan, digunakan untuk eksperimen action ordering
# Action yang diletakkan lebih awal akan diperiksa terlebih dahulu
var action_order: Array = []

# Konstruktor untuk menentukan depth
func _init(depth: int = 3):
    max_depth = depth

# Mengatur urutan action untuk eksperimen action ordering
func set_action_order(order: Array) -> void:
    action_order = order.duplicate()

# Mengurutkan action berdasarkan action_order
func order_actions(actions: Array) -> Array:
    # Jika action_order kosong, action dikembalikan dalam urutan aslinya
    if action_order.is_empty():
        return actions
    
    var ordered: Array = []
    # Memasukkan action berdasarkan prioritas
    for preferred_action in action_order:
        # Mencari action yang sesuai dalam daftar action
        for action in actions:
            # Jika action sesuai dengan action prioritas, maka masukkan ke daftar ordered
            if action == preferred_action:
                ordered.append(action)
    
    # Memasukkan action yang belum dimasukkan
    for action in actions:
        # Hanya masukkan jika belum ada di ordered
        if not ordered.has(action):
            ordered.append(action)

    # Mengembalikan action yang sudah diurutkan
    return ordered

# Mencari action terbaik NPC menggunakan algoritma Minimax ditambah Alpha-beta pruning
func find_best_action(state, evaluation) -> Dictionary:
    # Menyimpan waktu awal pencarian
    var start_time = Time.get_ticks_usec()
    
    # Reset jummlah node untuk pencarian baru
    node_count = 0
    
    # Action terbaik yang ditemukan
    var best_action = null

    # Score terbaik untuk NPC
    var best_score = -INF

    # Menyimpan score masing-masing action pada root
    var action_scores: Dictionary = {}

    # Menyimpan batas bawah terbaik yang sudah ditemukan oleh max/NPC
    var alpha = -INF

    # Menyimpan batas atas terbaik yang sudah ditemukan oleh min/lawan
    var beta = INF 

    # Mengambil seluruh action yang tersedia
    var actions = order_actions(state.get_available_actions())

    # Jika tidak ada action atau state sudah terminal, pencarian tidak perlu dilakukan
    if actions.is_empty() or state.is_terminal():
        var time_ms = (Time.get_ticks_usec() - start_time) / 1000.0
        # Mengembalikan evaluasi state saat ini
        return{
            "best_action": null,
            "best_score": evaluation.evaluate(state),
            "node_count": node_count,
            "depth": max_depth,
            "action_scores": {},
            "execution_time_ms": time_ms
        }
    
    # Memerika semua action root
    for action in actions:
        # Membuat state simulasi
        var next_state = state.apply_action_simulation(action)

        # Setelah NPC memilih action, pencarian dilanjutkan sebagai min/lawan
        var score = _min_value(next_state, 1, alpha, beta, evaluation)
        # Menyimpan score action
        action_scores[action] = score 
        # Menyimpan score lebih besar dari best_score, action tersebut menjadi pilihan terbaik
        if score > best_score: 
            best_score = score
            best_action = action 
        # Update alpha berdasarkan score terbaik
        alpha = max(alpha, best_score)
    
    var time_ms = (Time.get_ticks_usec() - start_time) / 1000.0
    # Mengembalikann hasil pencarian
    return{
        "best_action": best_action,
        "best_score": best_score,
        "node_count": node_count,
        "depth": max_depth,
        "action_scores": action_scores,
        "execution_time_ms": time_ms
    }

# Max digunakan untuk mensimulasikan NPC
# NPC ingin mendapatkan nilai evaluasi terbesar
func _max_value(state, depth: int, alpha: float, beta: float, evaluation) -> float:
    # Menghitung state sebagai node yang dikunjungi
    node_count += 1

    # Jika depth sudah mencapai batas atau state terminal, langsung lakukan evaluasi
    if depth >= max_depth or state.is_terminal():
        return evaluation.evaluate(state)
    
    var actions = order_actions(state.get_available_actions())
    # Tidak ada action tersedia, evaluasi state apa adanya
    if actions.is_empty():
        return evaluation.evaluate(state)
    
    # Nilai awal max dibuat sangat kecil
    var value = -INF
    # Memeriksa seluruh action
    for action in actions:
        # Membuat state simulasi
        var next_state = state.apply_action_simulation(action)
        # Setelah max memilih action, lanjutkan pencarian ke min
        var score = _min_value(next_state, depth + 1, alpha, beta, evaluation)
        # Max mengambil score terbesar
        value = max(value, score)
        # Alpha menyimpan nilai terbaik yang diketahui max
        alpha = max(alpha, value)
        
        # Jika alpha >= beta, cabang berikutnya tidak perlu diperiksa
        # Min sudah mempunyai alternatif yang membuat cabang ini tidak mungkin menghasilkan keputusan yang lebih baik
        if alpha >= beta:
            break 
    # Mengembalikan nilai terbaik max
    return value 

# Min digunakan untuk mensimulasikan lawan
# Lawan dianggap memilih nilai terkecil dari sudut pandang NPC
func _min_value(state, depth: int, alpha: float, beta: float, evaluation) -> float:
    node_count += 1 
    
    # Jika depth sudah mencapai batas atau state terminal, langsung lakukan evaluasi
    if depth >= max_depth or state.is_terminal():
        return evaluation.evaluate(state)


    var actions = order_actions(state.get_available_actions())
    # Tidak ada action tersedia, evaluasi state apa adanya
    if actions.is_empty():
        return evaluation.evaluate(state)
    
    # Nilai awal min dibuat sangat besar
    var value = INF
    # Memeriksa seluruh action
    for action in actions:
        # Membuat state hasil simulasi
        var next_state = state.apply_action_simulation(action)
        # Setelah min memilih action, pencarian kembali ke max
        var score = _max_value(next_state, depth + 1, alpha, beta, evaluation)
        # Min mengambil score terkecil
        value = min(value, score)
        # Beta menyimpan nilai terbaik yang diketahui min
        beta = min(beta, value)
        
        if alpha >= beta: 
            break
    # Mengembalikan nilai terbaik untuk min
    return value
