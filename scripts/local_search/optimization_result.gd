extends RefCounted
class_name OptimizationResult

# Alasan penghentian ketika target berhasil dicapai.
const REASON_GOAL_REACHED := "goal_reached"
# Alasan penghentian ketika tidak ada tetangga yang lebih baik.
const REASON_LOCAL_MAXIMUM := "local_maximum"
# Alasan penghentian ketika batas iterasi tercapai.
const REASON_MAX_ITERATIONS := "max_iterations"
# Alasan penghentian ketika batas restart tercapai.
const REASON_MAX_RESTARTS := "max_restarts"
# Alasan penghentian ketika suhu mencapai batas minimum.
const REASON_MIN_TEMPERATURE := "min_temperature"

# Alasan penghentian karena nama algoritma tidak valid.
const REASON_INVALID_ALGORITHM := "invalid_algorithm"
# Alasan penghentian karena target difficulty tidak valid.
const REASON_INVALID_TARGET := "invalid_target_difficulty"
# Alasan penghentian karena konfigurasi awal tidak valid.
const REASON_INVALID_INITIAL := "invalid_initial_configuration"
# Alasan penghentian karena parameter algoritma tidak valid.
const REASON_INVALID_PARAMETERS := "invalid_parameters"

# Menyimpan konfigurasi terbaik yang ditemukan.
var best_configuration = null
# Menyimpan fitness konfigurasi terbaik.
var best_fitness: float = -1.0
# Menyimpan jumlah iterasi pencarian.
var iteration_count: int = 0
# Menyimpan nama algoritma yang digunakan.
var algorithm_name: String = ""
# Menyimpan konfigurasi sebelum optimasi dimulai.
var initial_configuration = null
# Menyimpan target difficulty.
var target_difficulty: float = 50.0
# Menyimpan difficulty konfigurasi terbaik.
var best_difficulty_score: float = -1.0
# Menyimpan jumlah evaluasi fitness.
var evaluation_count: int = 0
# Menyimpan jumlah restart yang dilakukan.
var restart_count: int = 0
# Menyimpan durasi pencarian dalam milidetik.
var elapsed_ms: float = 0.0
# Menyimpan seed yang digunakan.
var seed_used: int = 0
# Menandakan apakah target berhasil dicapai.
var success: bool = false
# Menyimpan alasan penghentian algoritma.
var termination_reason: String = ""
# Menyimpan parameter yang digunakan saat pencarian.
var params_used: Dictionary = {}
