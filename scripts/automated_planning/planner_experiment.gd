extends Node

const DOMAIN = preload("res://scripts/automated_planning/planning_domain.gd")
const PLANNER = preload("res://scripts/automated_planning/planner.gd")

const REPETITIONS := 30


func _ready() -> void:
	run_experiment()
	get_tree().quit()


func run_experiment() -> void:
	var scenarios: Array = [
		{"n": 1, "condition": "Semua hidup", "leaders_alive": 1, "followers_alive": 0, "followers_dead": 0},

		{"n": 3, "condition": "Semua hidup", "leaders_alive": 1, "followers_alive": 2, "followers_dead": 0},
		{"n": 3, "condition": "1 Follower mati", "leaders_alive": 1, "followers_alive": 1, "followers_dead": 1},
		{"n": 3, "condition": "Leader mati", "leaders_alive": 0, "followers_alive": 2, "followers_dead": 0},

		{"n": 5, "condition": "Semua hidup", "leaders_alive": 1, "followers_alive": 4, "followers_dead": 0},
		{"n": 5, "condition": "2 Follower mati", "leaders_alive": 1, "followers_alive": 2, "followers_dead": 2},
		{"n": 5, "condition": "Leader mati", "leaders_alive": 0, "followers_alive": 4, "followers_dead": 0},

		{"n": 10, "condition": "Semua hidup", "leaders_alive": 1, "followers_alive": 9, "followers_dead": 0},
		{"n": 10, "condition": "4 Follower mati", "leaders_alive": 1, "followers_alive": 5, "followers_dead": 4},
		{"n": 10, "condition": "Leader mati", "leaders_alive": 0, "followers_alive": 9, "followers_dead": 0}
	]

	print("\nn,condition,algorithm,nodes_expanded,total_cost,average_time_ms,stddev_ms")

	for scenario in scenarios:
		var npcs: Array = create_npcs(scenario)
		var state: Dictionary = DOMAIN.create_initial_state(npcs, true)

		for mode in [PLANNER.MODE_UCS, PLANNER.MODE_ASTAR]:
			var times: Array[float] = []
			var nodes_expanded := 0
			var total_cost := 0

			for trial in range(REPETITIONS):
				var result: Dictionary = PLANNER.find_plan(
					state.duplicate(true),
					mode
				)

				if result["status"] != "plan_found":
					push_error("Planning gagal: " + str(result))
					continue

				times.append(float(result["time_ms"]))
				nodes_expanded = int(result["nodes_expanded"])
				total_cost = int(result["total_cost"])

			if times.is_empty():
				continue

			var avg: float = calculate_mean(times)
			var stddev: float = calculate_stddev(times, avg)

			print(
				scenario["n"], ",",
				scenario["condition"], ",",
				mode, ",",
				nodes_expanded, ",",
				total_cost, ",",
				"%.6f" % avg, ",",
				"%.6f" % stddev
			)

	print("\nEXPERIMENT FINISHED")


func create_npcs(scenario: Dictionary) -> Array:
	var npcs: Array = []
	var id_counter := 1

	for i in range(int(scenario["leaders_alive"])):
		npcs.append({
			"npc_id": "NPC-%02d" % id_counter,
			"hp": 100,
			"role": DOMAIN.ROLE_LEADER
		})
		id_counter += 1

	for i in range(int(scenario["followers_alive"])):
		npcs.append({
			"npc_id": "NPC-%02d" % id_counter,
			"hp": 100,
			"role": DOMAIN.ROLE_FOLLOWER
		})
		id_counter += 1

	for i in range(int(scenario["followers_dead"])):
		npcs.append({
			"npc_id": "NPC-%02d" % id_counter,
			"hp": 0,
			"role": DOMAIN.ROLE_FOLLOWER
		})
		id_counter += 1

	return npcs


func calculate_mean(values: Array[float]) -> float:
	var total := 0.0

	for value in values:
		total += value

	return total / values.size()


func calculate_stddev(values: Array[float], mean: float) -> float:
	var sum_squared := 0.0

	for value in values:
		sum_squared += pow(value - mean, 2)

	return sqrt(sum_squared / values.size())
