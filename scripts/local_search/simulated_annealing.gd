extends RefCounted
class_name SimulatedAnnealing

const GOAL_REACHED := OptimizationResult.REASON_GOAL_REACHED
const MAX_ITERATIONS := OptimizationResult.REASON_MAX_ITERATIONS
const MIN_TEMPERATURE := OptimizationResult.REASON_MIN_TEMPERATURE
const LOCAL_MAXIMUM := OptimizationResult.REASON_LOCAL_MAXIMUM
const INVALID_PARAMETERS := OptimizationResult.REASON_INVALID_PARAMETERS

# Menjalankan Simulated Annealing untuk mencari konfigurasi terbaik.
func search(initial_configuration, initial_fitness: float, target_difficulty: float, params: Dictionary, solver, rng: RandomNumberGenerator, on_progress: Callable = Callable()) -> Dictionary:
	var temperature: float = float(params.get("initial_temperature", 20.0))
	var cooling_factor: float = float(params.get("cooling_factor", 0.995))
	var minimum_temperature: float = float(params.get("minimum_temperature", 0.01))
	var max_iterations: int = maxi(0, int(params.get("max_iterations", 2000)))

	# Memastikan parameter suhu dan pendinginan valid.
	if(not is_finite(temperature) or not is_finite(cooling_factor) or not is_finite(minimum_temperature) or temperature <= 0.0 or cooling_factor <= 0.0 or cooling_factor >= 1.0 or minimum_temperature < 0.0):
		push_error("Parameter Simulated Annealing tidak valid.")
		return _make_result(initial_configuration, initial_fitness, 0, INVALID_PARAMETERS)

	var current = solver.copy_configuration(initial_configuration)
	var current_fitness: float = initial_fitness
	var best = solver.copy_configuration(initial_configuration)
	var best_fitness: float = initial_fitness
	var iteration_count: int = 0

	# Mengembalikan hasil jika konfigurasi awal sudah memenuhi target.
	if solver.is_goal(best, target_difficulty):
		return _make_result(best, best_fitness, 0, GOAL_REACHED)

	while(temperature > minimum_temperature and iteration_count < max_iterations):
		var neighbours: Array = solver.get_neighbours(current)

		# Menghentikan pencarian jika tidak ada tetangga.
		if neighbours.is_empty():
			return _make_result(best, best_fitness, iteration_count, LOCAL_MAXIMUM)

		# Memilih satu tetangga secara acak seragam.
		var next_index: int = rng.randi_range(0, neighbours.size() - 1)
		var next_configuration = neighbours[next_index]
		var next_fitness: float = solver.evaluate_fitness(next_configuration, target_difficulty)
		var delta_e: float = next_fitness - current_fitness
		var accepted: bool = delta_e > 0.0

		# Menerima langkah yang lebih buruk berdasarkan probabilitas suhu.
		if not accepted: 
			accepted = rng.randf() < exp(delta_e / temperature)

		# Memperbarui konfigurasi saat ini jika langkah diterima.
		if accepted:
			current = solver.copy_configuration(next_configuration)
			current_fitness = next_fitness

		# Memperbarui konfigurasi terbaik jika fitness meningkat.
		if current_fitness > best_fitness:
			best = solver.copy_configuration(current)
			best_fitness = current_fitness
		iteration_count += 1

		# Mengirim perkembangan pencarian jika callback tersedia.
		if on_progress.is_valid():
			on_progress.call(iteration_count, current_fitness, best_fitness)

		# Memeriksa target pada konfigurasi terbaik.
		if solver.is_goal(best, target_difficulty):
			return _make_result(best, best_fitness, iteration_count, GOAL_REACHED)

		# Menurunkan suhu setelah satu iterasi selesai.
		temperature *= cooling_factor

	# Memprioritaskan keberhasilan jika target sudah tercapai.
	if solver.is_goal(best, target_difficulty):
		return _make_result(best, best_fitness, iteration_count, GOAL_REACHED)

	# Mengembalikan alasan penghentian sesuai kondisi terakhir.
	if temperature <= minimum_temperature:
		return _make_result(best, best_fitness, iteration_count, MIN_TEMPERATURE)
	return _make_result(best, best_fitness, iteration_count, MAX_ITERATIONS)

# Menyusun hasil Simulated Annealing dalam bentuk Dictionary.
func _make_result(configuration, fitness, iterations: int, reason: String) -> Dictionary:
	return {
		"best_configuration": configuration,
		"best_fitness": fitness,
		"iteration_count": iterations,
		"restart_count": 0,
		"termination_reason": reason
	}