extends RefCounted
class_name Optimizer

const FITNESS_EPSILON: float = 0.000000001
const DEFAULT_HC_PARAMS: Dictionary = {
	"max_iterations": 100,
	"max_sideways_moves": 0
}
const DEFAULT_RR_PARAMS: Dictionary = {
	"max_iterations": 100,
	"max_sideways_moves": 0,
	"max_restarts": 10
}
const DEFAULT_SA_PARAMS: Dictionary = {
	"initial_temperature": 20.0,
	"cooling_factor": 0.995,
	"minimum_temperature": 0.01,
	"max_iterations": 2000
}

var _problem
var _hill_climbing: HillClimbing
var _random_restart: RandomRestart
var _simulated_annealing: SimulatedAnnealing
var _evaluation_count: int = 0

# Membuat objek problem dan algoritma pencarian.
func _init() -> void:
	_problem = LocalSearch.new()
	_hill_climbing = HillClimbing.new()
	_random_restart = RandomRestart.new()
	_simulated_annealing = SimulatedAnnealing.new()

# Menjalankan algoritma yang dipilih dan menyusun hasil optimasi.
func run(initial_configuration, target_difficulty: float, algorithm_name: String, params: Dictionary = {}, seed_value = null, on_progress: Callable = Callable()) -> OptimizationResult:
	var start_time: int = Time.get_ticks_usec()
	_evaluation_count = 0

	# Memastikan algoritma yang dipilih didukung.
	if not _is_supported_algorithm(algorithm_name):
		push_error("Optimizer: Unknown algorithm: " + algorithm_name)
		return _invalid_result(initial_configuration, target_difficulty, algorithm_name, params, OptimizationResult.REASON_INVALID_ALGORITHM, start_time)

	# Memvalidasi target difficulty.
	if not is_finite(target_difficulty):
		push_error("Optimizer: Target difficulty must be finite.")
		return _invalid_result(initial_configuration, target_difficulty, algorithm_name, params, OptimizationResult.REASON_INVALID_TARGET, start_time)

	if target_difficulty < 0.0 or target_difficulty > 100.0:
		push_error("Optimizer: Target difficulty must be between 0 and 100.")
		return _invalid_result(initial_configuration, target_difficulty, algorithm_name, params, OptimizationResult.REASON_INVALID_TARGET, start_time)

	# Memvalidasi konfigurasi awal.
	if not _problem.validate_configuration(initial_configuration):
		push_error("Optimizer: Initial configuration is invalid.")
		return _invalid_result(initial_configuration, target_difficulty, algorithm_name, params, OptimizationResult.REASON_INVALID_INITIAL, start_time)

	# Menggunakan seed yang diberikan atau membuat seed acak.
	var actual_seed: int = -1
	if seed_value != null:
		actual_seed = int(seed_value)

	if actual_seed < 0:
		var seed_generator := RandomNumberGenerator.new()
		seed_generator.randomize()
		actual_seed = int(seed_generator.randi())

	# Membuat satu RNG untuk seluruh proses pencarian.
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed

	var initial_copy = _problem.copy_configuration(initial_configuration)
	var effective_params: Dictionary = _get_effective_params(algorithm_name, params)
	var progress_callback: Callable = on_progress

	# Mengambil callback dari params jika callback langsung tidak diberikan.
	if(not progress_callback.is_valid() and params.get("on_progress") is Callable):
		progress_callback = params["on_progress"]

	# Menghitung fitness konfigurasi awal satu kali.
	var initial_fitness: float = evaluate_fitness(initial_copy, target_difficulty)

	# Menghentikan pencarian jika konfigurasi awal sudah memenuhi target.
	if is_goal(initial_copy, target_difficulty):
		return _build_result(initial_copy, initial_fitness, 0, algorithm_name, initial_copy, target_difficulty, 0, start_time, actual_seed, OptimizationResult.REASON_GOAL_REACHED, effective_params)

	# Menjalankan algoritma sesuai pilihan.
	var search_result: Dictionary = {}
	if algorithm_name == LocalSearch.ALGORITHM_HILL_CLIMBING:
		search_result = _hill_climbing.search(initial_copy, initial_fitness, target_difficulty, effective_params, self, progress_callback)
	elif algorithm_name == LocalSearch.ALGORITHM_RANDOM_RESTART:
		search_result = _random_restart.search(initial_copy, initial_fitness, target_difficulty, effective_params, self, rng, _hill_climbing, progress_callback)
	elif algorithm_name == LocalSearch.ALGORITHM_SIMULATED_ANNEALING:
		search_result = _simulated_annealing.search(initial_copy, initial_fitness, target_difficulty, effective_params, self, rng, progress_callback)

	# Mengambil seluruh informasi hasil dari algoritma.
	var best_configuration = search_result.get("best_configuration", initial_copy)
	var best_fitness: float = float(search_result.get("best_fitness", initial_fitness))
	var iteration_count: int = int(search_result.get("iteration_count", 0))
	var restart_count: int = int(search_result.get("restart_count", 0))
	var termination_reason: String = str(search_result.get("termination_reason", "unknown"))

	# Goal memiliki prioritas tertinggi sebagai alasan penghentian.
	if is_goal(best_configuration, target_difficulty):
		termination_reason = OptimizationResult.REASON_GOAL_REACHED

	return _build_result(best_configuration, best_fitness, iteration_count, algorithm_name, initial_copy, target_difficulty, restart_count, start_time, actual_seed, termination_reason, effective_params)

# Menghitung fitness sekaligus memperbarui penghitung evaluasi.
func evaluate_fitness(configuration, target_difficulty: float) -> float:
	_evaluation_count += 1
	return float(_problem.calculate_fitness(configuration, target_difficulty))

# Mengembalikan jumlah evaluasi fitness.
func get_evaluation_count() -> int:
	return _evaluation_count

# Menyediakan fungsi fitness untuk algoritma pencarian.
func calculate_fitness(configuration, target_difficulty: float) -> float:
	return evaluate_fitness(configuration, target_difficulty)

# Menghitung difficulty konfigurasi.
func calculate_difficulty(configuration) -> float: 
	return float(_problem.calculate_difficulty(configuration))

# Mengambil semua tetangga konfigurasi.
func get_neighbours(configuration) -> Array:
	return _problem.get_neighbours(configuration)

# Membuat konfigurasi acak menggunakan RNG yang sama.
func random_configuration(rng: RandomNumberGenerator):
	return _problem.random_configuration(rng)

# Memilih tetangga secara acak menggunakan RNG yang sama.
func random_neighbour(configuration, rng: RandomNumberGenerator):
	return _problem.random_neighbour(configuration, rng)

# Membuat salinan konfigurasi.
func copy_configuration(configuration):
	return _problem.copy_configuration(configuration)

# Memvalidasi konfigurasi.
func validate_configuration(configuration) -> bool:
	return _problem.validate_configuration(configuration)

# Memeriksa apakah difficulty berada dalam toleransi target.
func is_goal(configuration, target_difficulty: float) -> bool:
	if configuration == null:
		return false
	var difficulty: float = calculate_difficulty(configuration)
	if not is_finite(difficulty):
		return false
	return absf(difficulty - target_difficulty) <= (LocalSearch.TOLERANCE + FITNESS_EPSILON)

# Memeriksa apakah nama algoritma didukung.
func _is_supported_algorithm(algorithm_name: String) -> bool:
	return(algorithm_name == LocalSearch.ALGORITHM_HILL_CLIMBING or algorithm_name == LocalSearch.ALGORITHM_RANDOM_RESTART or algorithm_name == LocalSearch.ALGORITHM_SIMULATED_ANNEALING)

# Menggabungkan parameter default dengan parameter dari pemanggil.
func _get_effective_params(algorithm_name: String, params: Dictionary) -> Dictionary:
	var effective_params: Dictionary = {}
	if algorithm_name == LocalSearch.ALGORITHM_HILL_CLIMBING:
		effective_params = DEFAULT_HC_PARAMS.duplicate(true)
	elif algorithm_name == LocalSearch.ALGORITHM_RANDOM_RESTART:
		effective_params = DEFAULT_RR_PARAMS.duplicate(true)
	elif algorithm_name == LocalSearch.ALGORITHM_SIMULATED_ANNEALING:
		effective_params = DEFAULT_SA_PARAMS.duplicate(true)
	effective_params.merge(params, true)
	effective_params.erase("on_progress")
	return effective_params

# Menyusun data pencarian menjadi OptimizationResult.
func _build_result(best_configuration, best_fitness: float, iteration_count: int, algorithm_name: String, initial_configuration, target_difficulty: float, restart_count: int, start_time: int, actual_seed: int, termination_reason: String, effective_params: Dictionary) -> OptimizationResult: 
	var result = OptimizationResult.new()
	result.best_configuration = _problem.copy_configuration(best_configuration)
	result.best_fitness = best_fitness
	result.iteration_count = iteration_count
	result.algorithm_name = algorithm_name
	result.initial_configuration = _problem.copy_configuration(initial_configuration)
	result.target_difficulty = target_difficulty
	result.best_difficulty_score = calculate_difficulty(best_configuration)
	result.evaluation_count = _evaluation_count
	result.restart_count = restart_count
	result.elapsed_ms = float(Time.get_ticks_usec() - start_time) / 1000.0
	result.seed_used = actual_seed
	result.success = is_goal(best_configuration, target_difficulty)

	# Memprioritaskan goal jika konfigurasi terbaik memenuhi target.
	if result.success:
		result.termination_reason = OptimizationResult.REASON_GOAL_REACHED
	else:
		result.termination_reason = termination_reason

	result.params_used = effective_params.duplicate(true)
	return result

# Membuat hasil untuk input yang tidak valid.
func _invalid_result(initial_configuration, target_difficulty: float, algorithm_name: String, params: Dictionary, reason: String, start_time: int) -> OptimizationResult:
	var result = OptimizationResult.new()
	if(initial_configuration != null and _problem.validate_configuration(initial_configuration)):
		result.initial_configuration = _problem.copy_configuration(initial_configuration)
		result.best_configuration = _problem.copy_configuration(initial_configuration)

	result.algorithm_name = algorithm_name
	result.target_difficulty = target_difficulty
	result.best_fitness = -1.0
	result.best_difficulty_score = -1.0
	result.evaluation_count = _evaluation_count
	result.restart_count = 0
	result.iteration_count = 0
	result.seed_used = 0
	result.success = false
	result.termination_reason = reason
	result.params_used = params.duplicate(true)

	# Menyimpan durasi proses jika waktu mulai tersedia.
	if start_time > 0:
		result.elapsed_ms = float(Time.get_ticks_usec() - start_time) / 1000.0
	return result