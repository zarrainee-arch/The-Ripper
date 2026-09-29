extends RefCounted
class_name Minimax

# Menyimpan jumlah node yang dikunjungi selama proses pencarian minimax
var node_count: int = 0

# Depth maksimum yang digunakan oleh Minimax
# Angka 3 hanya merupakan nilai default, bukan batas maksimum
var max_depth: int = 3

# Konstruktor untuk menentukan depth maksimum ketika objek Minimax dibuat
func _init(depth: int = 3):
    max_depth = depth

# Mencari action terbaik yang dapat dipilih oleh NPC
# Fungsi ini hanya melakukan pencarian keputusan
func find_best_action(state, evaluation) -> Dictionary:
    # Menyimpan waktu ketika pencarian dimulai, untuk menghitung lama proses Minimax
    var start_time = Time.get_ticks_usec()

    # Reset jumlah node setiap kali pencarian dimulai
    node_count = 0

    # Action terbaik yang ditemukan
    var best_action = null

    # Score terbaik untuk NPC
    # Karena NPC adalah Max player, nilai awal dibuat -INF
    var best_score = -INF

    # Dictionary untuk menyimpan score dari setiap action pada root
    var action_scores: Dictionary = {}

    # Mengambil semua action yang tersedia untuk NPC
    var actions = state.get_available_actions()

    # Jika tidak ada action atau battle sudah berada pada kondisi terminal
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

    # Memeriksa setiap action yang tersedia untuk NPC
    for action in actions:
        # Membuat state hasil simulasi
        var next_state = state.apply_action_simulation(action)

        # Setelah NPC melakukan action, giliran berikutnya dianggap MIN/lawan
        var score = _min_value(next_state, 1, evaluation)
        action_scores[action] = score

        # Jika score action saat ini lebih besar dari score terbaik sebelumnya
        if score > best_score:
            best_score = score
            best_action = action

    # Menghitung total waktu pencarian
    var time_ms = (Time.get_ticks_usec() - start_time) / 1000.0
    return {
        "best_action": best_action,
        "best_score": best_score,
        "node_count": node_count,
        "depth": max_depth,
        "action_scores": action_scores,
        "execution_time_ms": time_ms
    }

# Fungsi Max digunakan untuk memilih keuntungan terbaik bagi NPC
func _max_value(state, depth: int, evaluation) -> float:
    node_count += 1

    # Berhenti jika sudah mencapai depth maksimum atau state sudah selesai
    if depth >= max_depth or state.is_terminal():
        return evaluation.evaluate(state)

    # Mengambil action yang tersedia
    var actions = state.get_available_actions()

    # Jika tidak ada action, state langsung dievaluasi
    if actions.is_empty():
        return evaluation.evaluate(state)

    # Nilai awal Max dibuat sangat kecil
    var value = -INF

    # Memeriksa action yang ada
    for action in actions:
        # Membuat state simulasi dari action
        var next_state = state.apply_action_simulation(action)
        
        # Setelah Max/NPC memilih action, giliran berikutnya dianggap Min/lawan
        var score = _min_value(next_state, depth + 1, evaluation)
        # Mengambil score terbesar
        value = max(value, score)

    return value


# Fungsi Min digunakan untuk menganggap lawan memilih kondisi
# yang paling merugikan NPC
func _min_value(state, depth: int, evaluation) -> float:
    node_count += 1

    # Berhenti jika sudah mencapai depth maksimum atau state sudah selesai
    if depth >= max_depth or state.is_terminal():
        return evaluation.evaluate(state)

    # Mengambil action yang tersedia
    var actions = state.get_available_actions()

    # Jika tidak ada action, state langsung dievaluasi
    if actions.is_empty():
        return evaluation.evaluate(state)

    # Nilai awal Min dibuat sangat besar
    var value = INF

    # Memeriksa seluruh action yang tersedia
    for action in actions:
        # Membuat state simulasi dari action
        var next_state = state.apply_action_simulation(action)

        # Setelah Min/lawan memilih action, giliran kembali dianggap milik Max/NPC
        var score = _max_value(next_state, depth + 1, evaluation)
        # Memilih score terkecil
        value = min(value, score)

    return value
