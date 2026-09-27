extends Node
class_name Heuristic 

# Heuristic type used by A*
@export_enum("Manhattan", "Euclidean")
var heuristic_type: String = "Manhattan"

# menerima posisi saat ini dan posisi tujuan, lalu menghitung jarak h
func calculate(pos: Vector2i, goal: Vector2i) -> float:
	if heuristic_type == "Manhattan":
		return manhattan(pos, goal)
	if heuristic_type == "Euclidean":
		return euclidean(pos, goal)

	return 0.0

# Manhattan Distance Functions
func manhattan(pos: Vector2i, goal: Vector2i) -> float:
	return abs(pos.x - goal.x) + abs(pos.y - goal.y)

# Euclidean Distance Functions
func euclidean(pos: Vector2i, goal: Vector2i) -> float:
	var dx: float = pos.x - goal.x
	var dy: float = pos.y - goal.y
	return sqrt(dx * dx + dy * dy)

# Get heuristic name
func get_heuristic_name() -> String:
	return heuristic_type
