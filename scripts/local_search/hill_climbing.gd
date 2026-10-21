extends RefCounted
class_name HillClimbing

const GOAL_REACHED := OptimizationResult.REASON_GOAL_REACHED
const LOCAL_MAXIMUM := OptimizationResult.REASON_LOCAL_MAXIMUM
const MAX_ITERATIONS := OptimizationResult.REASON_MAX_ITERATIONS
const FITNESS_EPSILON: float = 1.0e-9

# Menjalankan Hill Climbing dari konfigurasi awal.
func search(initial_configuration, initial_fitness: float, target_difficulty: float, params: Dictionary, solver, on_progress: Callable = Callable(), iteration_offset: int = 0, best_fitness_offset: float = -INF) -> Dictionary:
	var max_iterations: int = maxi(0, int(params.get("max_iterations", 100)))
	var max_sideways_moves: int = maxi(0, int(params.get("max_sideways_moves", 0)))

	var current = solver.copy_configuration(initial_configuration)
	var current_fitness: float = initial_fitness
	var best_fitness: float = maxf(initial_fitness, best_fitness_offset)
	var iteration_count: int = 0
	var sideways_count: int = 0

	# Mengembalikan hasil jika konfigurasi awal sudah memenuhi target.
	if solver.is_goal(current, target_difficulty):
		return _make_result(current, current_fitness, iteration_count, GOAL_REACHED)

	while iteration_count < max_iterations:
		var neighbours: Array = solver.get_neighbours(current)
		var best_neighbour = null
		var best_neighbour_fitness: float = -INF

		# Mengevaluasi semua tetangga untuk mencari fitness tertinggi.
		for neighbour in neighbours:
			var neighbour_fitness: float = solver.evaluate_fitness(neighbour, target_difficulty)
			if(best_neighbour == null or neighbour_fitness > best_neighbour_fitness + FITNESS_EPSILON):
				best_neighbour = neighbour
				best_neighbour_fitness = neighbour_fitness
		iteration_count += 1

		# Berhenti jika tidak ada tetangga yang tersedia.
		if best_neighbour == null:
			_emit_progress(on_progress, iteration_offset + iteration_count, current_fitness, best_fitness)
			return _make_result(current, current_fitness, iteration_count, LOCAL_MAXIMUM)

		# Memperbarui catatan fitness terbaik.
		if best_neighbour_fitness > best_fitness:
			best_fitness = best_neighbour_fitness

		# Mengembalikan hasil jika tetangga terbaik memenuhi target.
		if solver.is_goal(best_neighbour, target_difficulty):
			_emit_progress(on_progress, iteration_offset + iteration_count, best_neighbour_fitness, maxf(best_fitness, best_neighbour_fitness))
			return _make_result(best_neighbour, best_neighbour_fitness, iteration_count, GOAL_REACHED)

		# Berpindah jika fitness meningkat.
		if(best_neighbour_fitness > current_fitness + FITNESS_EPSILON):
			current = solver.copy_configuration(best_neighbour)
			current_fitness = best_neighbour_fitness
			sideways_count = 0
		# Mengizinkan perpindahan dengan fitness sama sesuai batas sideways.
		elif(absf(best_neighbour_fitness - current_fitness) <= FITNESS_EPSILON and sideways_count < max_sideways_moves):
			current = solver.copy_configuration(best_neighbour)
			current_fitness = best_neighbour_fitness
			sideways_count += 1
		else:
			_emit_progress(on_progress, iteration_count + iteration_offset, current_fitness, best_fitness)
			return _make_result(current, current_fitness, iteration_count, LOCAL_MAXIMUM)

		_emit_progress(on_progress, iteration_offset + iteration_count, current_fitness, best_fitness)

	# Memeriksa target sebelum mengembalikan alasan batas iterasi.
	if solver.is_goal(current, target_difficulty):
		return _make_result(current, current_fitness, iteration_count, GOAL_REACHED)
	return _make_result(current, current_fitness, iteration_count, MAX_ITERATIONS)

# Mengirim perkembangan pencarian jika callback tersedia.
func _emit_progress(callback: Callable, iteration: int, current_fitness: float, best_fitness: float) -> void:
	if callback.is_valid():
		callback.call(iteration, current_fitness, best_fitness)

# Menyusun hasil pencarian dalam bentuk Dictionary.
func _make_result(configuration, fitness:float, iterations: int, reason: String) -> Dictionary:
	return {
		"best_configuration": configuration,
		"best_fitness": fitness,
		"iteration_count": iterations,
		"restart_count": 0,
		"termination_reason": reason
	}
