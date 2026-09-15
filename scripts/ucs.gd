extends RefCounted


class QueueEntry:
	var node: Vector2i
	var cost: int

	func _init(node_position: Vector2i, node_cost: int):
		node = node_position
		cost = node_cost


var grid
var frontier: Array[QueueEntry] = []
var cost_so_far: Dictionary = {}
var came_from: Dictionary = {}


func _init(grid_reference):
	grid = grid_reference


func push_frontier(node: Vector2i, cost: int):
	frontier.append(QueueEntry.new(node, cost))


func pop_lowest_cost() -> QueueEntry:
	if frontier.is_empty():
		return null

	var lowest_index = 0

	for i in range(1, frontier.size()):
		if frontier[i].cost < frontier[lowest_index].cost:
			lowest_index = i

	return frontier.pop_at(lowest_index)


func find_path(start: Vector2i, goal: Vector2i) -> Dictionary:
	frontier.clear()
	cost_so_far.clear()
	came_from.clear()

	var expanded_nodes: Array[Vector2i] = []

	push_frontier(start, 0)

	cost_so_far[start] = 0
	came_from[start] = start

	while not frontier.is_empty():
		var current_entry = pop_lowest_cost()
		var current = current_entry.node

		expanded_nodes.append(current)

		if current == goal:
			break

		for neighbor in grid.get_neighbors(current):
			var new_cost = cost_so_far[current] + 1

			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				came_from[neighbor] = current
				push_frontier(neighbor, new_cost)

	var path = reconstruct_path(start, goal)

	var path_cost = 0

	if cost_so_far.has(goal):
		path_cost = cost_so_far[goal]

	return {
		"path": path,
		"cost": path_cost,
		"expanded_nodes": expanded_nodes
	}


func reconstruct_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	if not came_from.has(goal):
		return path

	var current = goal

	while current != start:
		path.append(current)
		current = came_from[current]

	path.append(start)
	path.reverse()

	return path