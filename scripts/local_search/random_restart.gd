
extends RefCounted
class_name RandomRestart

const GOAL_REACHED := OptimizationResult.REASON_GOAL_REACHED
const LOCAL_MAXIMUM := OptimizationResult.REASON_LOCAL_MAXIMUM
const MAX_ITERATIONS := OptimizationResult.REASON_MAX_ITERATIONS
const MAX_RESTARTS := OptimizationResult.REASON_MAX_RESTARTS


# Menjalankan Hill Climbing berulang kali dengan konfigurasi awal baru.
func search(
	initial_configuration,
	initial_fitness: float,
	target_difficulty: float,
	params: Dictionary,
	solver,
	rng: RandomNumberGenerator,
	hill_climbing: HillClimbing,
	on_progress: Callable = Callable()
) -> Dictionary:

	var max_restarts: int = maxi(
		0, int(params.get("max_restarts", 10))
	)

	var hc_params: Dictionary = {
		"max_iterations": maxi(
			0, int(params.get("max_iterations", 100))
		),
		"max_sideways_moves": maxi(
			0, int(params.get("max_sideways_moves", 0))
		)
	}

	var best_configuration = solver.copy_configuration(
		initial_configuration
	)
	var best_fitness: float = initial_fitness
	var restart_count: int = 0
	var total_iterations: int = 0

	var current_configuration = solver.copy_configuration(
		initial_configuration
	)
	var current_fitness: float = initial_fitness

	# Mengembalikan hasil jika konfigurasi awal sudah memenuhi target.
	if solver.is_goal(current_configuration, target_difficulty):
		return _make_result(
			best_configuration, best_fitness, 0, 0, GOAL_REACHED
		)

	while true:
		# Menjalankan Hill Climbing dan menghitung total iterasi.
		var hc_result: Dictionary = hill_climbing.search(
			current_configuration,
			current_fitness,
			target_difficulty,
			hc_params,
			solver,
			on_progress,
			total_iterations,
			best_fitness
		)

		total_iterations += int(hc_result["iteration_count"])

		var candidate = hc_result["best_configuration"]
		var candidate_fitness: float = float(
			hc_result["best_fitness"]
		)
		var hc_reason: String = str(
			hc_result["termination_reason"]
		)

		# Menyimpan konfigurasi terbaik.
		if candidate_fitness > best_fitness:
			best_configuration = solver.copy_configuration(candidate)
			best_fitness = candidate_fitness

		# Memeriksa apakah target tercapai.
		if solver.is_goal(candidate, target_difficulty):
			return _make_result(
				best_configuration,
				best_fitness,
				total_iterations,
				restart_count,
				GOAL_REACHED
			)

		# Restart hanya setelah local maximum atau batas iterasi.
		if hc_reason != LOCAL_MAXIMUM and hc_reason != MAX_ITERATIONS:
			push_error("Alasan berhenti HC tidak dikenali: " + hc_reason)
			return _make_result(
				best_configuration, best_fitness,
				total_iterations, restart_count, MAX_RESTARTS
			)

		# Menghentikan pencarian jika jatah restart habis.
		if restart_count >= max_restarts:
			return _make_result(
				best_configuration, best_fitness,
				total_iterations, restart_count, MAX_RESTARTS
			)

		restart_count += 1
		current_configuration = solver.random_configuration(rng)

		# Memastikan konfigurasi acak valid.
		if (
			current_configuration == null
			or not solver.validate_configuration(current_configuration)
		):
			push_error("Random restart menghasilkan konfigurasi tidak valid.")
			return _make_result(
				best_configuration, best_fitness,
				total_iterations, restart_count, MAX_RESTARTS
			)

		# Mengevaluasi fitness konfigurasi baru.
		current_fitness = solver.evaluate_fitness(
			current_configuration, target_difficulty
		)

		# Memeriksa target setelah restart.
		if solver.is_goal(current_configuration, target_difficulty):
			if current_fitness > best_fitness:
				best_configuration = solver.copy_configuration(
					current_configuration
				)
				best_fitness = current_fitness

			return _make_result(
				best_configuration,
				best_fitness,
				total_iterations,
				restart_count,
				GOAL_REACHED
			)

	# Pengaman agar semua jalur fungsi mengembalikan Dictionary.
	return _make_result(
		best_configuration,
		best_fitness,
		total_iterations,
		restart_count,
		MAX_RESTARTS
	)


# Menyusun hasil Random Restart dalam bentuk Dictionary.
func _make_result(
	configuration,
	fitness: float,
	iterations: int,
	restarts: int,
	reason: String
) -> Dictionary:
	return {
		"best_configuration": configuration,
		"best_fitness": fitness,
		"iteration_count": iterations,
		"restart_count": restarts,
		"termination_reason": reason
	}
